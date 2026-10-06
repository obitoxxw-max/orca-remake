--!strict
-- Broly UI - Client entry point
-- Drop this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Order of operations: load saved settings, apply them, then mount the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--- Finds a shared module wherever it ended up. Two supported layouts:
---  - modules grouped in ReplicatedStorage > Broly (the documented one)
---  - modules sitting next to this script
--- Anything else raises a message that says exactly what is missing.
local function resolve(name: string, folderName: string?): ModuleScript
	local candidates = {}

	local function collect(root: Instance?)
		if not root then
			return
		end
		if folderName then
			local folder = root:FindFirstChild(folderName)
			if folder then
				table.insert(candidates, folder:FindFirstChild(name))
			end
		else
			table.insert(candidates, root:FindFirstChild(name))
		end
	end

	collect(ReplicatedStorage:FindFirstChild("Broly"))
	collect(script.Parent)

	for _, candidate in candidates do
		if candidate and candidate:IsA("ModuleScript") then
			return candidate
		end
	end

	local path = if folderName then `Broly > UI > {name}.lua` else `Broly > {name}.lua`
	error(`[Broly] module introuvable : {name}.lua (attendu dans {path})`)
end

local Config = require(resolve("Config"))
local Store = require(resolve("Store"))
local UI = require(resolve("UI", "UI"))

local player = Players.LocalPlayer
if not player then
	warn("[Broly] no LocalPlayer, aborting.")
	return
end

-- ── ScreenGui ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "BrolyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 500
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- ── Startup ─────────────────────────────────────────────────────────────────

Store.init()

local ui = UI.new(gui)

-- Apply once immediately so the world already respects the settings while the
-- DataStore round-trip is in flight.
Store.apply()

task.spawn(function()
	Store.load()
end)

Store.onStatus(function(status)
	if status == "ready" then
		ui.notify("Réglages chargés depuis ton profil.", "ok")
	elseif status == "no-server" then
		ui.notify("Broly.server.lua absent : réglages non conservés.", "warn")
	end
end)

-- ── Field of view ───────────────────────────────────────────────────────────
-- Camera.FieldOfView is re-synced by the server and by camera scripts, so the
-- preference has to be re-asserted while it drifts.

local fovTarget = tonumber(Store.get().fov) or 70

Store.onChange(function(_, key)
	if key == "fov" then
		fovTarget = tonumber(Store.get().fov) or 70
	end
end)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if math.abs(camera.FieldOfView - fovTarget) > 0.25 then
		camera.FieldOfView = fovTarget
	end
end)

-- ── Nametags ────────────────────────────────────────────────────────────────
-- A comfort option, not an ESP: only the display name, only for players this
-- instance already knows about.

local TAG_NAME = "BrolyNameTag"
local tags = {}

local function clearTag(playerToClear: Player)
	local entry = tags[playerToClear]
	if entry then
		entry.billboard:Destroy()
		tags[playerToClear] = nil
	end
end

local function clearAllTags()
	for target, _ in tags do
		clearTag(target)
	end
end

local function buildTag(target: Player)
	if target == player or tags[target] then
		return
	end
	local character = target.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2.1, 0)
	billboard.Size = UDim2.fromOffset(140, 20)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = target.DisplayName
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	billboard.Parent = head
	tags[target] = { billboard = billboard }
end

local function syncTags()
	if Store.get().characterNames ~= true then
		clearAllTags()
		return
	end
	for _, target in Players:GetPlayers() do
		buildTag(target)
	end
end

Store.onChange(function(_, key)
	if key == "characterNames" then
		syncTags()
	end
end)

Players.PlayerAdded:Connect(buildTag)
Players.PlayerRemoving:Connect(clearTag)

player.CharacterAdded:Connect(function()
	clearAllTags()
	task.delay(1, syncTags)
end)

task.spawn(syncTags)

-- Re-apply everything when the character respawns so server-driven values and
-- camera settings come back after a death.
player.CharacterAdded:Connect(function()
	task.wait(0.4)
	Store.apply()
	Store.pushServerPrefs()
end)

-- ── Console ─────────────────────────────────────────────────────────────────

print("[Broly] by psych0pat3 — menu de qualité chargé.")
print(`[Broly] touche du menu : {tostring(Store.get().menuKey)}`)

-- Keep a handle around so other LocalScripts can reach the menu.
_G.Broly = {
	store = Store,
	ui = ui,
	config = Config,
}
