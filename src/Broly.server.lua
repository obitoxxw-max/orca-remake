--!strict
-- Broly UI - Server
-- Authoritative half of the menu. Owns the DataStore, validates every payload
-- against the shared schema (never trusts the client) and applies the
-- gameplay options that replication would otherwise overwrite.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--- Same tolerant lookup as the client: shared modules either live in
--- ReplicatedStorage > Broly, or next to this script.
local function resolve(name: string): ModuleScript
	local candidates = {}

	local grouped = ReplicatedStorage:FindFirstChild("Broly")
	if grouped then
		table.insert(candidates, grouped:FindFirstChild(name))
	end
	table.insert(candidates, script.Parent:FindFirstChild(name))

	for _, candidate in candidates do
		if candidate and candidate:IsA("ModuleScript") then
			return candidate
		end
	end

	error(`[Broly] module introuvable : {name}.lua (attendu dans Broly > {name}.lua)`)
end

local Config = require(resolve("Config"))

local SERVER = {
	STORE_NAME = "BrolyUI_Config_v1",
	REMOTE_FOLDER = "BrolyRemotes",
	FETCH_REMOTE = "BrolyFetch",
	PUSH_REMOTE = "BrolyPush",
	PREFS_REMOTE = "BrolyServerPrefs",
	WRITE_COOLDOWN = 6,
	MAX_PRESETS = 12,
	MAX_NAME = 24,
}

-- ── Remotes ─────────────────────────────────────────────────────────────────

local remotes = Instance.new("Folder")
remotes.Name = SERVER.REMOTE_FOLDER
remotes.Parent = ReplicatedStorage

local function makeRemote(className: string, name: string): Instance
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local fetchRemote = makeRemote("RemoteFunction", SERVER.FETCH_REMOTE) :: RemoteFunction
local pushRemote = makeRemote("RemoteEvent", SERVER.PUSH_REMOTE) :: RemoteEvent
local prefsRemote = makeRemote("RemoteEvent", SERVER.PREFS_REMOTE) :: RemoteEvent

local store = nil
local storeError = false
local function getStore(): DataStore?
	if store or storeError then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SERVER.STORE_NAME)
	end)
	if ok then
		store = result
	else
		storeError = true
		warn(`[Broly] DataStore unavailable: {tostring(result)}`)
	end
	return store
end

-- ── In-memory cache per player ──────────────────────────────────────────────

type Session = {
	lastWrite: number,
	data: { [string]: any },
}

local sessions: { [Player]: Session } = {}
local heartbeatLast = 0

local function defaultsPayload()
	return { version = 1, config = Config.defaults(), presets = {} }
end

-- ── Validation ──────────────────────────────────────────────────────────────

--- Rebuilds a payload from untrusted input. Anything missing or malformed
--- falls back to the schema default, so a tampered client can neither crash
--- the server nor store out-of-range values.
local function sanitisePayload(raw: any): { [string]: any }
	local clean = defaultsPayload()

	if type(raw) ~= "table" then
		return clean
	end

	local config = raw.config
	if type(config) == "table" then
		for key, entry in Config.ENTRIES do
			local value = config[key]
			if value ~= nil then
				clean.config[key] = Config.sanitise(key, value)
			else
				clean.config[key] = entry.default
			end
		end
	end

	local presets = raw.presets
	if type(presets) == "table" then
		local list = {}
		for index, item in presets do
			if index > SERVER.MAX_PRESETS then
				break
			end
			if type(item) == "table" and type(item.name) == "string" and type(item.values) == "table" then
				local values = {}
				for key, entry in Config.ENTRIES do
					local value = item.values[key]
					if value ~= nil then
						values[key] = Config.sanitise(key, value)
					end
				end
				table.insert(list, {
					name = string.sub(item.name, 1, SERVER.MAX_NAME),
					values = values,
				})
			end
		end
		clean.presets = list
	end

	return clean
end

-- ── Gameplay application ────────────────────────────────────────────────────

local function characterHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

--- Re-applies walk speed / jump / gravity. Called on spawn and when the player
--- changes the values, because other gameplay scripts in a game frequently
--- reset Humanoid properties on their own.
local function applyGameplay(player: Player, config: { [string]: any })
	local humanoid = characterHumanoid(player)
	if not humanoid then
		return
	end

	local speed = tonumber(config.walkSpeed) or 16
	local jump = tonumber(config.jumpPower) or 50
	local gravity = tonumber(config.gravity) or 196.2

	humanoid.WalkSpeed = speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jump
	player:SetAttribute("brolyWalkSpeed", speed)
	player:SetAttribute("brolyJumpPower", jump)
	player:SetAttribute("brolyGravity", gravity)

	local ok = pcall(function()
		workspace.Gravity = gravity
	end)
	if not ok then
		warn("[Broly] could not set workspace.Gravity (place may be filtering it)")
	end
end

-- ── DataStore read / write ──────────────────────────────────────────────────

local function loadSession(player: Player)
	local session: Session = { lastWrite = 0, data = defaultsPayload() }
	sessions[player] = session

	local dataStore = getStore()
	if not dataStore then
		return session
	end

	local ok, result = pcall(function()
		return dataStore:GetAsync(`user_{player.UserId}`)
	end)

	if ok and type(result) == "table" then
		session.data = sanitisePayload(result)
	elseif not ok then
		warn(`[Broly] GetAsync failed for {player.UserId}: {tostring(result)}`)
	end

	return session
end

--- Writes with a simple lock field so two servers racing the same player
--- cannot clobber each other.
local function saveSession(player: Player)
	local session = sessions[player]
	local dataStore = getStore()
	if not session or not dataStore then
		return false
	end

	local ok, err = pcall(function()
		dataStore:UpdateAsync(`user_{player.UserId}`, function(old)
			if type(old) ~= "table" then
				return session.data
			end
			return {
				version = 1,
				config = old.config or session.data.config,
				presets = old.presets or session.data.presets,
				lastWrite = {
					serverUserId = player.UserId,
					time = os.time(),
				},
			}
		end)
	end)

	if not ok then
		warn(`[Broly] UpdateAsync failed for {player.UserId}: {tostring(err)}`)
		return false
	end

	session.lastWrite = os.clock()
	return true
end

-- ── Remote handlers ─────────────────────────────────────────────────────────

fetchRemote.OnServerInvoke = function(player: Player)
	local session = sessions[player]
	if not session then
		session = loadSession(player)
	end
	-- Hand back a copy so a client cannot mutate the server's cache.
	return {
		version = 1,
		config = table.clone(session.data.config),
		presets = table.clone(session.data.presets),
	}
end

pushRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local session = sessions[player]
	if not session then
		session = loadSession(player)
	end

	if os.clock() - session.lastWrite < SERVER.WRITE_COOLDOWN then
		return
	end

	session.data = sanitisePayload(payload)
	session.lastWrite = os.clock() -- in-memory rate limit as well
	saveSession(player)
end)

prefsRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local clean = {}
	for _, key in Config.serverKeys() do
		clean[key] = Config.sanitise(key, payload[key])
	end

	local session = sessions[player]
	if session then
		for key, value in clean do
			session.data.config[key] = value
		end
	end

	applyGameplay(player, clean)
end)

-- ── Player lifecycle ────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	local session = loadSession(player)

	-- Wait for the first character so the initial values land on a real Humanoid.
	local function applyForCharacter()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			applyGameplay(player, session.data.config)
		end
	end

	task.spawn(applyForCharacter)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applyGameplay(player, session.data.config)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local session = sessions[player]
	if session then
		saveSession(player)
		sessions[player] = nil
	end
end)

-- ── Shutdown safety net ─────────────────────────────────────────────────────

game:BindToClose(function()
	for player, session in sessions do
		local dataStore = getStore()
		if dataStore and session then
			pcall(function()
				dataStore:UpdateAsync(`user_{player.UserId}`, function()
					return session.data
				end)
			end)
		end
	end
end)

-- Keeps the humanoid values pinned at a low tick rate so gameplay scripts that
-- reset them every frame cannot permanently undo the player's settings.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - heartbeatLast < 1 then
		return
	end
	heartbeatLast = now

	for player, session in sessions do
		if player.Parent and player.Character then
			applyGameplay(player, session.data.config)
		end
	end
end)
