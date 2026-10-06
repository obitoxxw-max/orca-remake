--!strict
-- Broly UI - Configuration
-- Single source of truth for every option: its type, default, range and the
-- engine property it actually drives. Everything here is client-settable
-- unless flagged `server = true`, in which case Broly.server.lua applies it
-- with authority so the value is not reverted by replication.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Config = {}

export type Kind = "bool" | "number" | "choice" | "key"

export type Choice = {
	id: string,
	label: string,
	value: any,
}

export type Entry = {
	key: string,
	label: string,
	help: string?,
	kind: Kind,
	default: any,
	min: number?,
	max: number?,
	step: number?,
	choices: { Choice }?,
	server: boolean?,
	page: string,
	group: string,
	format: ("percent" | "decimal" | "none")?,
}

local function e(entry: Entry): Entry
	return entry
end

-- ── Graphics ────────────────────────────────────────────────────────────────

local GRAPHICS: { Entry } = {
	e({
		key = "shadows",
		label = "Ombres",
		help = "Désactive toutes les ombres pour gagner des images par seconde.",
		kind = "bool",
		default = true,
		page = "home",
		group = "Shadows",
	}),
	e({
		key = "shadowMapSize",
		label = "Résolution des ombres",
		help = "Plus la résolution est haute, plus l'ombre est nette et coûteuse.",
		kind = "choice",
		default = "2048",
		choices = {
			{ id = "512", label = "512", value = Enum.ShadowMapSize.S512 },
			{ id = "1024", label = "1024", value = Enum.ShadowMapSize.S1024 },
			{ id = "2048", label = "2048", value = Enum.ShadowMapSize.S2048 },
			{ id = "4096", label = "4096", value = Enum.ShadowMapSize.S4096 },
		},
		page = "home",
		group = "Shadows",
	}),
	e({
		key = "lightingTech",
		label = "Technologie d'éclairage",
		help = "Future active les ombres dynamiques. Ignoré si la place force Compatibility.",
		kind = "choice",
		default = "future",
		choices = {
			{ id = "compatibility", label = "Compat", value = Enum.Technology.Compatibility },
			{ id = "soft", label = "Doux", value = Enum.Technology.SoftShadow },
			{ id = "future", label = "Future", value = Enum.Technology.Future },
		},
		page = "home",
		group = "Shadows",
	}),
	e({
		key = "brightness",
		label = "Luminosité",
		kind = "number",
		default = 2,
		min = 0,
		max = 3,
		step = 0.05,
		format = "decimal",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "exposure",
		label = "Exposition",
		kind = "number",
		default = 0,
		min = -2,
		max = 2,
		step = 0.05,
		format = "decimal",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "ambient",
		label = "Lumière ambiante",
		kind = "number",
		default = 1,
		min = 0,
		max = 3,
		step = 0.05,
		format = "decimal",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "outdoorAmbient",
		label = "Ambiance extérieure",
		kind = "number",
		default = 1,
		min = 0,
		max = 3,
		step = 0.05,
		format = "decimal",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "envDiffuse",
		label = "Diffusion environnement",
		kind = "number",
		default = 1,
		min = 0,
		max = 1,
		step = 0.01,
		format = "percent",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "envSpecular",
		label = "Spéculaire environnement",
		kind = "number",
		default = 1,
		min = 0,
		max = 1,
		step = 0.01,
		format = "percent",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "clockTime",
		label = "Heure",
		help = "Fixe l'heure de la journée.",
		kind = "number",
		default = 14,
		min = 0,
		max = 24,
		step = 0.5,
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "atmosphereDensity",
		label = "Densité atmosphère",
		help = "Disponible seulement si votre place contient un objet Atmosphere.",
		kind = "number",
		default = 0.3,
		min = 0,
		max = 1,
		step = 0.01,
		format = "percent",
		page = "home",
		group = "Lighting",
	}),
	e({
		key = "fog",
		label = "Brouillard",
		kind = "bool",
		default = false,
		page = "home",
		group = "Fog",
	}),
	e({
		key = "fogStart",
		label = "Début",
		kind = "number",
		default = 80,
		min = 0,
		max = 1000,
		step = 5,
		page = "home",
		group = "Fog",
	}),
	e({
		key = "fogEnd",
		label = "Fin",
		kind = "number",
		default = 600,
		min = 50,
		max = 20000,
		step = 25,
		page = "home",
		group = "Fog",
	}),
	e({
		key = "fogMode",
		label = "Courbe",
		kind = "choice",
		default = "linear",
		choices = {
			{ id = "linear", label = "Linéaire", value = Enum.FogMode.Linear },
			{ id = "exponential", label = "Exponentielle", value = Enum.FogMode.Exponential },
			{ id = "exponential2", label = "Exponentielle²", value = Enum.FogMode.ExponentialSquared },
		},
		page = "home",
		group = "Fog",
	}),
	e({
		key = "cameraMaxZoom",
		label = "Zoom caméra max",
		kind = "number",
		default = 400,
		min = 10,
		max = 1200,
		step = 5,
		page = "home",
		group = "Camera",
	}),
}

-- ── Gameplay ────────────────────────────────────────────────────────────────

local GAMEPLAY: { Entry } = {
	e({
		key = "mouseSensitivity",
		label = "Sensibilité souris",
		kind = "number",
		default = 1,
		min = 0.1,
		max = 5,
		step = 0.05,
		format = "decimal",
		page = "apps",
		group = "Camera",
	}),
	e({
		key = "fov",
		label = "Champ de vision",
		kind = "number",
		default = 70,
		min = 30,
		max = 110,
		step = 1,
		page = "apps",
		group = "Camera",
	}),
	e({
		key = "cameraMode",
		label = "Mode caméra",
		kind = "choice",
		default = "classic",
		choices = {
			{ id = "classic", label = "Classique", value = Enum.CameraMode.Classic },
			{ id = "lock", label = "1ʳᵉ personne", value = Enum.CameraMode.LockFirstPerson },
		},
		page = "apps",
		group = "Camera",
	}),
	e({
		key = "cameraOffset",
		label = "Hauteur caméra",
		kind = "number",
		default = 0,
		min = -8,
		max = 12,
		step = 0.25,
		format = "decimal",
		page = "apps",
		group = "Camera",
	}),
	e({
		key = "walkSpeed",
		label = "Vitesse de marche",
		help = "Appliqué par le serveur, sinon la valeur est réécrite à la réplication.",
		kind = "number",
		default = 16,
		min = 0,
		max = 150,
		step = 1,
		server = true,
		page = "apps",
		group = "Movement",
	}),
	e({
		key = "jumpPower",
		label = "Puissance de saut",
		kind = "number",
		default = 50,
		min = 0,
		max = 250,
		step = 1,
		server = true,
		page = "apps",
		group = "Movement",
	}),
	e({
		key = "gravity",
		label = "Gravité",
		kind = "number",
		default = 196.2,
		min = 0,
		max = 2000,
		step = 0.2,
		format = "decimal",
		server = true,
		page = "apps",
		group = "Movement",
	}),
	e({
		key = "autoJump",
		label = "Saut automatique",
		kind = "bool",
		default = false,
		page = "apps",
		group = "Movement",
	}),
	e({
		key = "characterNames",
		label = "Noms au-dessus des joueurs",
		kind = "bool",
		default = false,
		page = "apps",
		group = "Comfort",
	}),
}

-- ── Interface / accessibility ───────────────────────────────────────────────

local INTERFACE: { Entry } = {
	e({
		key = "palette",
		label = "Thème",
		kind = "choice",
		default = "midnight",
		choices = {
			{ id = "midnight", label = "Midnight", value = "midnight" },
			{ id = "obsidian", label = "Obsidian", value = "obsidian" },
			{ id = "carbon", label = "Carbon", value = "carbon" },
			{ id = "contrast", label = "Contraste", value = "contrast" },
		},
		page = "options",
		group = "Look",
	}),
	e({
		key = "accent",
		label = "Accent",
		kind = "choice",
		default = "golden",
		choices = {
			{ id = "lime", label = "Lime", value = "lime" },
			{ id = "golden", label = "Golden", value = "golden" },
			{ id = "crimson", label = "Crimson", value = "crimson" },
			{ id = "vast", label = "Vast", value = "vast" },
			{ id = "legendary", label = "Legendary", value = "legendary" },
		},
		page = "options",
		group = "Look",
	}),
	e({
		key = "logoAssetId",
		label = "ID du logo (asset)",
		help = "Renseigne l'asset id de votre image Roblox. 0 = monogramme généré.",
		kind = "number",
		default = 0,
		min = 0,
		max = 10000000000,
		step = 1,
		page = "options",
		group = "Look",
	}),
	e({
		key = "uiScale",
		label = "Taille de l'interface",
		kind = "number",
		default = 1,
		min = 0.75,
		max = 1.4,
		step = 0.05,
		format = "percent",
		page = "options",
		group = "Look",
	}),
	e({
		key = "reduceMotion",
		label = "Réduire les animations",
		help = "Remplace toutes les transitions par des changements instantanés.",
		kind = "bool",
		default = false,
		page = "options",
		group = "Accessibility",
	}),
	e({
		key = "highContrastText",
		label = "Texte contrasté",
		kind = "bool",
		default = false,
		page = "options",
		group = "Accessibility",
	}),
	e({
		key = "showFps",
		label = "Compteur FPS",
		kind = "bool",
		default = false,
		page = "options",
		group = "Accessibility",
	}),
}

-- ── Non-engine settings ─────────────────────────────────────────────────────

local META: { Entry } = {
	e({
		key = "menuKey",
		label = "Touche du menu",
		help = "Clique ce champ puis appuie sur la touche que tu veux utiliser.",
		kind = "key",
		default = "F6",
		page = "options",
		group = "Keys",
	}),
}

Config.GROUPS = {
	home = { "Shadows", "Lighting", "Fog", "Camera" },
	apps = { "Camera", "Movement", "Comfort" },
	options = { "Look", "Accessibility", "Keys" },
	presets = {},
}

Config.ENTRIES = {}
for _, list in { GRAPHICS, GAMEPLAY, INTERFACE, META } do
	for _, entry in list do
		Config.ENTRIES[entry.key] = entry
	end
end

function Config.page(pageId: string): { Entry }
	local order = Config.GROUPS[pageId]
	local result: { Entry } = {}
	for _, group in order do
		for _, entry in Config.ENTRIES do
			if entry.page == pageId and entry.group == group then
				table.insert(result, entry)
			end
		end
	end
	return result
end

function Config.groupTitles(pageId: string): { string }
	return Config.GROUPS[pageId] or {}
end

-- ── Defaults / validation ───────────────────────────────────────────────────

function Config.defaults(): { [string]: any }
	local result = {}
	for key, entry in Config.ENTRIES do
		result[key] = entry.default
	end
	return result
end

--- Coerces a single value against its schema entry.
function Config.sanitise(key: string, value: any): any
	local entry = Config.ENTRIES[key]
	if not entry then
		return nil
	end

	if entry.kind == "bool" then
		return value == true
	end

	if entry.kind == "number" then
		local number = tonumber(value)
		if not number then
			return entry.default
		end
		number = math.clamp(number, entry.min or -math.huge, entry.max or math.huge)
		local step = entry.step or 1
		if step >= 1 then
			return math.round(number)
		end
		local inversed = 1 / step
		return math.floor(number * inversed + 0.5) / inversed
	end

	if entry.kind == "choice" then
		local text = tostring(value)
		for _, choice in entry.choices do
			if choice.id == text then
				return choice.id
			end
		end
		return entry.default
	end

	if entry.kind == "key" then
		local name = tostring(value)
		-- Only accept real key codes, and never Unknown / modifier-only keys
		-- which would make the menu impossible to reopen.
		local code = Enum.KeyCode:FindFirstChild(name)
		if code and code ~= Enum.KeyCode.Unknown then
			return name
		end
		return entry.default
	end

	return entry.default
end

--- Builds a full, validated config from an arbitrary table (DataStore payload).
function Config.sanitiseAll(raw: any): { [string]: any }
	local result = Config.defaults()
	if type(raw) ~= "table" then
		return result
	end
	for key, entry in Config.ENTRIES do
		local value = raw[key]
		if value ~= nil then
			result[key] = Config.sanitise(key, value)
		end
	end
	return result
end

function Config.get(config: { [string]: any }, key: string): any
	local value = config[key]
	if value == nil then
		local entry = Config.ENTRIES[key]
		return entry and entry.default or nil
	end
	return value
end

function Config.set(config: { [string]: any }, key: string, value: any): boolean
	local clean = Config.sanitise(key, value)
	if clean == nil or config[key] == clean then
		return false
	end
	config[key] = clean
	return true
end

function Config.serverKeys(): { string }
	local result = {}
	for key, entry in Config.ENTRIES do
		if entry.server then
			table.insert(result, key)
		end
	end
	return result
end

function Config.formatValue(entry: Entry, value: any): string
	if entry.kind == "bool" then
		return value and "Activé" or "Désactivé"
	end

	if entry.kind == "key" then
		return tostring(value)
	end

	if entry.kind == "choice" then
		for _, choice in entry.choices do
			if choice.id == value then
				return choice.label
			end
		end
		return tostring(value)
	end

	local number = tonumber(value) or 0
	if entry.format == "percent" then
		return string.format("%d%%", math.round(number * 100))
	end
	if entry.format == "decimal" then
		local text = string.format("%.2f", number)
		return (text:gsub("%.?0+$", ""))
	end
	return string.format("%d", math.round(number))
end

-- ── Quality presets ─────────────────────────────────────────────────────────

Config.PRESETS = {
	{
		id = "quality",
		label = "Qualité",
		values = {
			shadows = true,
			shadowMapSize = "4096",
			lightingTech = "future",
			ambient = 1,
			outdoorAmbient = 1,
			envDiffuse = 1,
			envSpecular = 1,
			exposure = 0.2,
		},
	},
	{
		id = "balanced",
		label = "Équilibré",
		values = {
			shadows = true,
			shadowMapSize = "2048",
			lightingTech = "future",
			ambient = 1,
			outdoorAmbient = 1,
			envDiffuse = 0.9,
			envSpecular = 0.9,
			exposure = 0,
		},
	},
	{
		id = "performance",
		label = "Performance",
		values = {
			shadows = false,
			shadowMapSize = "512",
			lightingTech = "soft",
			ambient = 1,
			outdoorAmbient = 1,
			envDiffuse = 0.6,
			envSpecular = 0.5,
			exposure = -0.1,
		},
	},
	{
		id = "cinematic",
		label = "Cinématique",
		values = {
			shadows = true,
			shadowMapSize = "4096",
			lightingTech = "future",
			ambient = 0.6,
			outdoorAmbient = 0.7,
			envDiffuse = 1,
			envSpecular = 1,
			exposure = 0.35,
			clockTime = 19,
			fog = true,
			fogStart = 120,
			fogEnd = 900,
		},
	},
}

-- ── Applying to the engine ──────────────────────────────────────────────────

local BASE_AMBIENT = Lighting.Ambient
local BASE_OUTDOOR = Lighting.OutdoorAmbient

function Config.choiceValue(key: string, id: any): any
	local entry = Config.ENTRIES[key]
	if not entry then
		return nil
	end
	for _, choice in entry.choices do
		if choice.id == id then
			return choice.value
		end
	end
	return nil
end

--- Resolves a stored key name to an Enum.KeyCode, for the global hotkey listener.
function Config.keyValue(key: string, name: any): Enum.KeyCode?
	if Config.ENTRIES[key] == nil or Config.ENTRIES[key].kind ~= "key" then
		return nil
	end
	local code = Enum.KeyCode:FindFirstChild(tostring(name))
	if code then
		return code
	end
	return nil
end

--- Applies every client-settable option. Returns the list of keys that could
--- not be applied, so the UI can grey them out instead of lying to the player.
function Config.applyClient(config: { [string]: any }): { string }
	local skipped = {}

	local function try(key: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn(`[Broly] could not apply "{key}": {tostring(err)}`)
			table.insert(skipped, key)
		end
	end

	try("shadows", function()
		Lighting.GlobalShadows = config.shadows == true
	end)

	try("shadowMapSize", function()
		Lighting.ShadowMapSize = Config.choiceValue("shadowMapSize", config.shadowMapSize)
	end)

	try("lightingTech", function()
		Lighting.Technology = Config.choiceValue("lightingTech", config.lightingTech)
	end)

	try("brightness", function()
		Lighting.Brightness = config.brightness
	end)

	try("exposure", function()
		Lighting.ExposureCompensation = config.exposure
	end)

	try("ambient", function()
		Lighting.Ambient = BASE_AMBIENT * math.clamp(config.ambient, 0, 3)
	end)

	try("outdoorAmbient", function()
		Lighting.OutdoorAmbient = BASE_OUTDOOR * math.clamp(config.outdoorAmbient, 0, 3)
	end)

	try("envDiffuse", function()
		Lighting.EnvironmentDiffuseScale = config.envDiffuse
	end)

	try("envSpecular", function()
		Lighting.EnvironmentSpecularScale = config.envSpecular
	end)

	try("clockTime", function()
		Lighting.ClockTime = math.clamp(config.clockTime, 0, 24)
	end)

	try("atmosphereDensity", function()
		local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
		if atmosphere then
			atmosphere.Density = math.clamp(config.atmosphereDensity, 0, 1)
		end
	end)

	try("fog", function()
		Lighting.FogStart = config.fogStart
		Lighting.FogEnd = math.max(config.fogEnd, config.fogStart + 50)
		if config.fog then
			Lighting.FogMode = Config.choiceValue("fogMode", config.fogMode)
		else
			Lighting.FogMode = Enum.FogMode.Off
		end
	end)

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		try("cameraMaxZoom", function()
			localPlayer.CameraMaxZoomDistance = config.cameraMaxZoom
		end)

		try("cameraMode", function()
			localPlayer.CameraMode = Config.choiceValue("cameraMode", config.cameraMode)
		end)

		try("autoJump", function()
			localPlayer.AutoJumpEnabled = config.autoJump == true
		end)

		try("cameraOffset", function()
			local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.CameraOffset = Vector3.new(0, config.cameraOffset, 0)
			end
		end)
	end

	try("mouseSensitivity", function()
		UserInputService.MouseDeltaSensitivity = config.mouseSensitivity
	end)

	return skipped
end

return Config
