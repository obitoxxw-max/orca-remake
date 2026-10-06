--!strict
-- Broly UI - Store
-- Holds the live config, applies changes instantly, persists to a local cache
-- and syncs with a DataStore through the server script. Everything degrades
-- gracefully: if the server script is missing the menu still works, it just
-- only remembers settings for the current session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Store = {}

Store.REMOTE_FOLDER = "BrolyRemotes"
Store.FETCH_REMOTE = "BrolyFetch"
Store.PUSH_REMOTE = "BrolyPush"
Store.PREFS_REMOTE = "BrolyServerPrefs"

local AUTOSAVE_DELAY = 2.5
local MAX_PRESETS = 12

local state = Config.defaults()
local presets: { { name: string, values: { [string]: any } } } = {}
local presetsDirty = false

local configDirty = false
local saveScheduled = false
local listeners: { (config: { [string]: any }, key: string) -> () } = {}
local statusListeners: { (status: string) -> () } = {}
local statusText = "idle"

local remotes: {
	fetch: RemoteFunction?,
	push: RemoteEvent?,
	prefs: RemoteEvent?,
} =
	{ fetch = nil, push = nil, prefs = nil }

local function resolveRemotes()
	local folder = ReplicatedStorage:FindFirstChild(Store.REMOTE_FOLDER)
	if not folder then
		return
	end
	remotes.fetch = folder:FindFirstChild(Store.FETCH_REMOTE)
	remotes.push = folder:FindFirstChild(Store.PUSH_REMOTE)
	remotes.prefs = folder:FindFirstChild(Store.PREFS_REMOTE)
end

-- ── Status ──────────────────────────────────────────────────────────────────

function Store.setStatus(text: string)
	if statusText == text then
		return
	end
	statusText = text
	for _, listener in statusListeners do
		local ok, err = pcall(listener, text)
		if not ok then
			warn(`[Broly] status listener failed: {tostring(err)}`)
		end
	end
end

function Store.getStatus(): string
	return statusText
end

--- Subscribes to status changes. Returns a function that unsubscribes, so a
--- rebuilt UI does not keep listeners pointing at destroyed instances.
function Store.onStatus(listener: (string) -> ()): () -> ()
	table.insert(statusListeners, listener)
	return function()
		local index = table.find(statusListeners, listener)
		if index then
			table.remove(statusListeners, index)
		end
	end
end

-- ── Change notification ─────────────────────────────────────────────────────

--- Subscribes to config changes. Returns an unsubscribe function.
function Store.onChange(listener: (config: { [string]: any }, key: string) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

local function emit(key: string)
	for _, listener in listeners do
		local ok, err = pcall(listener, state, key)
		if not ok then
			warn(`[Broly] change listener failed: {tostring(err)}`)
		end
	end
end

-- ── Engine application ──────────────────────────────────────────────────────

function Store.apply()
	Config.applyClient(state)
end

--- Server-authoritative options (walk speed, jump, gravity) have to be applied
--- by the server, otherwise replication writes its own value over ours.
function Store.pushServerPrefs()
	if not remotes.prefs then
		return
	end
	local payload = {}
	for _, key in Config.serverKeys() do
		payload[key] = state[key]
	end
	local ok, err = pcall(function()
		remotes.prefs.FireServer(payload)
	end)
	if not ok then
		warn(`[Broly] could not send server prefs: {tostring(err)}`)
	end
end

-- ── Mutating the config ─────────────────────────────────────────────────────

function Store.get(): { [string]: any }
	return state
end

function Store.set(key: string, value: any): boolean
	local entry = Config.ENTRIES[key]
	if not entry then
		return false
	end

	if not Config.set(state, key, value) then
		return false
	end

	if entry.server then
		Store.pushServerPrefs()
	else
		Store.apply()
	end

	emit(key)
	markDirty()
	return true
end

function Store.setMany(values: { [string]: any }): boolean
	local changed = false
	local touchedServer = false

	for key, value in values do
		if Config.set(state, key, value) then
			changed = true
			local entry = Config.ENTRIES[key]
			if entry and entry.server then
				touchedServer = true
			end
			emit(key)
		end
	end

	if changed then
		if touchedServer then
			Store.pushServerPrefs()
		else
			Store.apply()
		end
		markDirty()
	end

	return changed
end

function Store.reset()
	local defaults = Config.defaults()
	for key in defaults do
		state[key] = defaults[key]
	end
	Store.apply()
	Store.pushServerPrefs()
	emit("*")
	markDirty()
end

-- ── Persistence ─────────────────────────────────────────────────────────────

function Store.markDirty()
	configDirty = true
	Store.scheduleSave()
end

function Store.scheduleSave()
	if saveScheduled then
		return
	end
	saveScheduled = true
	task.delay(AUTOSAVE_DELAY, function()
		saveScheduled = false
		Store.save()
	end)
end

--- Snapshot sent to the DataStore.
function Store.serialise(): { [string]: any }
	local payload = {}
	for key, entry in Config.ENTRIES do
		payload[key] = state[key]
	end
	return {
		version = 1,
		config = payload,
		presets = Store.serialisePresets(),
	}
end

function Store.save()
	if not remotes.push then
		Store.setStatus("no-server")
		return
	end
	if not (configDirty or presetsDirty) then
		return
	end

	local payload = Store.serialise()
	local ok = pcall(function()
		remotes.push.FireServer(payload)
	end)

	configDirty = false
	presetsDirty = false
	Store.setStatus(if ok then "saving" else "error")
end

--- Loads the saved payload. Returns true when a server payload was applied.
function Store.load(): boolean
	if not remotes.fetch then
		Store.setStatus("no-server")
		return false
	end

	local ok, result = pcall(function()
		return remotes.fetch.InvokeServer()
	end)

	if not ok or type(result) ~= "table" then
		Store.setStatus("load-failed")
		return false
	end

	local incoming = result.config
	if type(incoming) == "table" then
		local sanitised = Config.sanitiseAll(incoming)
		-- Only overwrite keys the player actually had saved, otherwise a fresh
		-- account would overwrite new defaults shipped with a game update.
		for key, value in sanitised do
			if result.config[key] ~= nil then
				state[key] = value
			end
		end
	end

	Store.loadPresets(result.presets)
	Store.apply()
	Store.pushServerPrefs()
	emit("*")
	Store.setStatus("ready")
	return true
end

-- ── Presets ─────────────────────────────────────────────────────────────────

function Store.getPresets(): { { name: string, values: { [string]: any } } }
	return presets
end

function Store.serialisePresets()
	local result = {}
	for index, preset in presets do
		result[index] = { name = preset.name, values = preset.values }
	end
	return result
end

function Store.loadPresets(raw: any)
	presets = {}
	if type(raw) ~= "table" then
		return
	end
	for index, item in raw do
		if index > MAX_PRESETS then
			break
		end
		if type(item) == "table" and type(item.name) == "string" and type(item.values) == "table" then
			local values = {}
			for key in Config.ENTRIES do
				if item.values[key] ~= nil then
					values[key] = Config.sanitise(key, item.values[key])
				end
			end
			table.insert(presets, { name = string.sub(item.name, 1, 24), values = values })
		end
	end
end

function Store.savePreset(name: string): boolean
	local clean = string.gsub(name, "%s", "")
	if clean == "" then
		return false
	end
	if #presets >= MAX_PRESETS then
		return false
	end
	local values = {}
	for key in Config.ENTRIES do
		if Config.ENTRIES[key].page ~= "options" then
			values[key] = state[key]
		end
	end
	table.insert(presets, { name = string.sub(clean, 1, 24), values = values })
	presetsDirty = true
	Store.scheduleSave()
	emit("presets")
	return true
end

function Store.deletePreset(index: number)
	if presets[index] == nil then
		return
	end
	table.remove(presets, index)
	presetsDirty = true
	Store.scheduleSave()
	emit("presets")
end

function Store.applyPreset(index: number)
	local preset = presets[index]
	if not preset then
		return
	end
	Store.setMany(preset.values)
end

function Store.renamePreset(index: number, name: string)
	local preset = presets[index]
	if not preset then
		return
	end
	local clean = string.gsub(name, "%s", "")
	if clean == "" then
		return
	end
	preset.name = string.sub(clean, 1, 24)
	presetsDirty = true
	Store.scheduleSave()
	emit("presets")
end

-- ── Import / export ─────────────────────────────────────────────────────────

function Store.exportJson(): string
	local ok, text = pcall(function()
		return game:GetService("HttpService"):JSONEncode(Store.serialise())
	end)
	if not ok then
		return ""
	end
	return text
end

--- Returns true on success, or an error string.
function Store.importJson(text: string): (boolean, string?)
	local HttpService = game:GetService("HttpService")

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(text)
	end)

	if not ok or type(decoded) ~= "table" then
		return false, "JSON invalide"
	end

	local incoming = decoded.config
	if type(incoming) ~= "table" then
		return false, "Aucune section config"
	end

	Store.setMany(Config.sanitiseAll(incoming))
	Store.loadPresets(decoded.presets)
	emit("presets")
	Store.scheduleSave()
	return true
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function Store.init()
	resolveRemotes()

	local player = Players.LocalPlayer
	if player then
		player.CharacterAdded:Connect(function()
			task.wait(0.35)
			Store.apply()
			Store.pushServerPrefs()
		end)
	end
end

return Store
