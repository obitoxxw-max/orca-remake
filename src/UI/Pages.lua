--!strict
-- Broly UI - Pages
-- Builds the content of each tab from the Config schema. Every widget registers
-- a controller so external changes (preset applied, reset, import) can refresh
-- the interface without rebuilding it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Anim = require(script.Parent.Parent.Anim)
local Config = require(script.Parent.Parent.Config)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.Theme)

local Pages = {}

type Tone = "info" | "warn" | "ok"
type StatusInfo = { text: string, tone: Tone }

export type Context = {
	skin: Kit.Skin,
	controllers: { [string]: any },
	rebuild: () -> (),
	setSkin: (paletteId: string, accentId: string) -> (),
	notify: (text: string, tone: Tone) -> (),
}

-- ── Binding helpers ─────────────────────────────────────────────────────────

--- Creates the widget matching the entry kind and wires it to the store.
--- Each widget is a single root frame, so its LayoutOrder drives ordering
--- inside the parent UIListLayout.
local function bind(parent: Instance, entry: Config.Entry, ctx: Context, layoutOrder: number)
	local skin = ctx.skin
	local value = Store.get()[entry.key]

	parent.LayoutOrder = layoutOrder

	local function changed(next: any)
		Store.set(entry.key, next)
	end

	local controller
	if entry.kind == "bool" then
		controller = Kit.toggle(parent, entry, value == true, skin, changed)
	elseif entry.kind == "number" then
		controller = Kit.slider(parent, entry, value, skin, changed)
	elseif entry.kind == "choice" then
		controller = Kit.segmented(parent, entry, tostring(value), skin, changed)
	end

	if controller then
		ctx.controllers[entry.key] = controller
	end

	return controller
end

--- Pushes a value into a registered controller (used by presets and reset).
local function refreshControllers(ctx: Context, values: { [string]: any })
	for key, controller in ctx.controllers do
		local entry = Config.ENTRIES[key]
		if entry and controller and controller.refresh then
			local value = values[key]
			if value ~= nil then
				if entry.kind == "bool" then
					controller.refresh(value == true)
				else
					controller.refresh(value)
				end
			end
		end
	end
end

--- Renders the schema groups of a page into a container, one card per group.
--- opts.only restricts which groups render, opts.skip individual keys, and
--- opts.bare drops the card chrome when the caller already provides it.
local function renderGroups(
	parent: Instance,
	pageId: string,
	ctx: Context,
	opts: { skip: { [string]: boolean }?, only: { [string]: boolean }?, bare: boolean? }?
)
	local skin = ctx.skin
	local order = 0
	local skip = opts and opts.skip or nil
	local only = opts and opts.only or nil
	local bare = opts and opts.bare or false

	for _, group in Config.groupTitles(pageId) do
		if only and not only[group] then
			continue
		end

		local cardEntries = {}
		for _, entry in Config.page(pageId) do
			if entry.group == group and not (skip and skip[entry.key]) then
				table.insert(cardEntries, entry)
			end
		end

		if #cardEntries == 0 then
			continue
		end

		order += 1

		local serverCount = 0
		for _, entry in cardEntries do
			if entry.server then
				serverCount += 1
			end
		end
		local subtitle
		if serverCount > 0 then
			local plural = serverCount > 1
			subtitle = `{serverCount} option{plural and "s" or ""} appliquée{plural and "s" or ""} par le serveur.`
		end

		local host: GuiObject
		local body: Frame

		if bare then
			Kit.section(parent, group, skin)
			host = parent
			body = parent
		else
			local card = Kit.card(parent, group, subtitle, skin)
			card.frame.LayoutOrder = order
			host = card.frame
			body = card.body
		end

		for index, entry in cardEntries do
			bind(body, entry, ctx, if bare then 100 + index else index)
		end
	end
end

-- ── Home : qualité / graphismes ─────────────────────────────────────────────

local function buildHome(parent: Instance, ctx: Context)
	local skin = ctx.skin

	local presetCard =
		Kit.card(parent, "Profil de qualité", "Applique un ensemble cohérent d'options graphiques.", skin)
	presetCard.frame.LayoutOrder = 0

	local presetRow = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
	})
	presetRow.Parent = presetCard.body

	local presetLayout = Instance.new("UIListLayout")
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.SortOrder = Enum.SortOrder.LayoutOrder
	presetLayout.Padding = UDim.new(0, 8)
	presetLayout.Parent = presetRow

	local indicator = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromScale(0.25, 1),
	})
	indicator.Parent = presetRow
	Theme.corner(indicator, 9)

	local presetButtons = {}
	local presets = Config.PRESETS

	for index, preset in presets do
		local button = Kit.new("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.25, 1),
			Text = preset.label,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextColor3 = skin.palette.textMuted,
			AutoButtonColor = false,
			ZIndex = 3,
		})
		button.Parent = presetRow
		presetButtons[preset.id] = button

		button.MouseEnter:Connect(function()
			Anim.tween(button, { TextTransparency = 0.45 }, 0.16)
		end)
		button.MouseLeave:Connect(function()
			Anim.tween(button, { TextTransparency = 0 }, 0.2)
		end)

		button.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			Anim.tween(indicator, {
				Position = UDim2.fromScale((index - 1) * 0.25, 0),
			}, 0.32, Anim.EASING.enter)
			for id, other in presetButtons do
				Anim.tween(other, {
					TextColor3 = if id == preset.id then skin.palette.text else skin.palette.textMuted,
				}, 0.2)
			end
			Anim.pop(presetCard.frame, 0.24)

			-- Move the widgets first so they animate in step with the engine,
			-- then persist the bundle.
			for key, controller in ctx.controllers do
				local entry = Config.ENTRIES[key]
				if entry and entry.page == "home" and controller.set then
					local nextValue = preset.values[key]
					if nextValue ~= nil then
						controller.set(nextValue)
					end
				end
			end
			Store.setMany(preset.values)
			ctx.notify(`Profil « {preset.label} » appliqué.`, "ok")
		end)
	end

	Kit.hint(
		presetCard.body,
		"Aucun réglage n'est simulé : chaque option pilote une vraie propriété du moteur. "
			.. "Les options marquées « serveur » ne sont pas forcables depuis le client.",
		skin,
		"info"
	)

	renderGroups(parent, "home", ctx)

	task.defer(function()
		Anim.stagger(parent)
	end)
end

-- ── Apps : gameplay ──────────────────────────────────────────────────────────

local function buildApps(parent: Instance, ctx: Context)
	local skin = ctx.skin

	local header = Kit.card(parent, "Gameplay", "Vitesse, saut, caméra et confort de jeu.", skin)
	header.frame.LayoutOrder = 0

	local player = Players.LocalPlayer
	local readout = Kit.hint(header.body, "Connexion au serveur…", skin, "ok")
	local readoutLabel = readout:FindFirstChildOfClass("TextLabel") :: TextLabel

	if player then
		readoutLabel.Text = `Joueur : {player.DisplayName} · id {player.UserId}`
	end

	Store.onStatus(function(status)
		if status == "ready" then
			readoutLabel.Text = "Serveur connecté : les options serveur sont actives."
			Anim.tween(readoutLabel, { TextColor3 = skin.palette.textMuted }, 0.3)
		elseif status == "no-server" then
			readoutLabel.Text =
				"Broly.server.lua est introuvable : la vitesse, le saut et la gravité resteront ceux de ton jeu."
			Anim.tween(readoutLabel, { TextColor3 = Color3.fromRGB(255, 190, 70) }, 0.3)
		end
	end)

	renderGroups(parent, "apps", ctx)

	task.defer(function()
		Anim.stagger(parent)
	end)
end

-- ── Presets ─────────────────────────────────────────────────────────────────

local function countValues(values: { [string]: any }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

local function buildPresets(parent: Instance, ctx: Context)
	local skin = ctx.skin

	local card =
		Kit.card(parent, "Mes profils", "Sauvegarde une combinaison d'options et recharge-la en un clic.", skin)
	card.frame.LayoutOrder = 0

	local saveRow = Kit.row(card.body, 8, 34)
	saveRow.LayoutOrder = 1

	local nameField = Kit.textField(saveRow, "Nom du profil…", skin)
	nameField.Size = UDim2.new(1, -112, 0, 34)

	local function save()
		if Store.savePreset(nameField.Text) then
			nameField.Text = ""
			ctx.notify("Profil enregistré.", "ok")
		else
			ctx.notify("Nom invalide ou liste pleine (12 maximum).", "warn")
		end
	end

	Kit.button(saveRow, "Enregistrer", skin, "primary", save)

	nameField.FocusLost:Connect(function()
		if nameField.Text ~= "" then
			save()
		end
	end)

	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	list.Parent = card.body
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list

	local function renderList()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local presets = Store.getPresets()
		if #presets == 0 then
			Kit.hint(list, "Aucun profil enregistré pour l'instant.", skin, "info")
			return
		end

		for index, preset in presets do
			local item = Kit.new("Frame", {
				BackgroundColor3 = skin.palette.surfaceAlt,
				BackgroundTransparency = 0.25,
				Size = UDim2.new(1, 0, 0, 40),
			})
			item.Parent = list
			item.LayoutOrder = index
			Theme.corner(item, 9)

			local nameLabel = Theme.label(item, preset.name, 13, skin.palette.text, Enum.Font.GothamMedium)
			nameLabel.Size = UDim2.new(1, -270, 1, 0)
			nameLabel.Position = UDim2.fromOffset(12, 0)
			nameLabel.ZIndex = 3
			nameLabel.Active = false

			local countLabel = Theme.label(
				item,
				`{countValues(preset.values)} réglages`,
				10,
				skin.palette.textFaint,
				Enum.Font.Gotham
			)
			countLabel.Size = UDim2.new(0, 110, 1, 0)
			countLabel.Position = UDim2.new(1, -250, 0, 0)
			countLabel.ZIndex = 3
			countLabel.Active = false

			local applyButton = Kit.button(item, "Appliquer", skin, "primary", function()
				Store.applyPreset(index)
				local values = Store.get()
				local applied = {}
				for key, presetValue in preset.values do
					applied[key] = values[key] or presetValue
				end
				refreshControllers(ctx, applied)
				ctx.notify(`Profil « {preset.name} » appliqué.`, "ok")
				Anim.pop(item, 0.3)
			end)
			applyButton.AutomaticSize = Enum.AutomaticSize.None
			applyButton.Size = UDim2.fromOffset(84, 30)
			applyButton.Position = UDim2.new(1, -96, 0.5, -15)
			applyButton.ZIndex = 3
			Theme.padding(applyButton, 8)

			local deleteButton = Kit.button(item, "✕", skin, "danger", function()
				Store.deletePreset(index)
				Anim.tween(item, {
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundTransparency = 1,
				}, 0.22)
				task.delay(0.24, renderList)
			end)
			deleteButton.AutomaticSize = Enum.AutomaticSize.None
			deleteButton.Size = UDim2.fromOffset(32, 30)
			deleteButton.Position = UDim2.new(1, -54, 0.5, -15)
			deleteButton.ZIndex = 3
			Theme.padding(deleteButton, 0)

			local hit = Kit.new("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -150, 1, 0),
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
			})
			hit.Parent = item
			hit.MouseEnter:Connect(function()
				Anim.tween(item, { BackgroundTransparency = 0.12 }, 0.18)
			end)
			hit.MouseLeave:Connect(function()
				Anim.tween(item, { BackgroundTransparency = 0.25 }, 0.22)
			end)
		end
	end

	renderList()

	-- Import / export
	local ioCard = Kit.card(parent, "Sauvegarde manuelle", "Copie ou restaure ta configuration complète.", skin)
	ioCard.frame.LayoutOrder = 1

	local exportRow = Kit.row(ioCard.body, 8, 34)
	exportRow.LayoutOrder = 1

	local exportField = Kit.textField(ioCard.body, "Le JSON exporté s'affichera ici…", skin)
	exportField.LayoutOrder = 2
	exportField.MultiLine = true
	exportField.TextSize = 10
	exportField.TextEditable = false
	exportField.TextWrapped = true
	exportField.Size = UDim2.new(1, 0, 0, 56)

	Kit.button(exportRow, "Exporter", skin, "primary", function()
		local json = Store.exportJson()
		if json == "" then
			ctx.notify("Export impossible.", "warn")
			return
		end
		exportField.Text = json
		local copied = pcall(function()
			GuiService.SetClipboard(json)
		end)
		if copied then
			ctx.notify("Export copié dans le presse-papiers et affiché ci-dessous.", "ok")
		else
			ctx.notify("Copie automatique indisponible : le JSON est affiché, copie-le à la main.", "warn")
		end
		Anim.entrance(exportField)
	end)

	local importRow = Kit.row(ioCard.body, 8, 34)
	importRow.LayoutOrder = 3

	local importField = Kit.textField(importRow, "Colle ici un JSON importé…", skin)
	importField.Size = UDim2.new(1, -112, 0, 34)

	Kit.button(importRow, "Importer", skin, "ghost", function()
		local ok, err = Store.importJson(importField.Text)
		if ok then
			importField.Text = ""
			ctx.notify("Configuration importée.", "ok")
			ctx.rebuild()
		else
			ctx.notify(err or "Import impossible.", "warn")
		end
	end)

	Kit.hint(
		ioCard.body,
		"Un profil n'enregistre pas le thème, l'accent ni le raccourci : ce sont des préférences d'interface, pas de jeu.",
		skin,
		"info"
	)

	task.defer(function()
		Anim.stagger(parent)
	end)
end

-- ── Options ─────────────────────────────────────────────────────────────────

local function buildOptions(parent: Instance, ctx: Context)
	local skin = ctx.skin
	local order = 0

	order += 1
	local look = Kit.card(parent, "Apparence", "Thème, couleur d'accent et identité du menu.", skin)
	look.frame.LayoutOrder = order

	Kit.swatches(look.body, "Thème", Theme.PALETTES, skin.palette.id, skin, function(id)
		ctx.setSkin(id, Store.get().accent)
		ctx.notify("Thème changé.", "ok")
	end)

	Kit.swatches(look.body, "Couleur d'accent", Theme.ACCENTS, skin.accent.id, skin, function(id)
		ctx.setSkin(Store.get().palette, id)
		ctx.notify("Accent changé.", "ok")
	end)

	renderGroups(look.body, "options", ctx, {
		only = { Look = true },
		skip = { palette = true, accent = true },
		bare = true,
	})

	order += 1
	local comfort = Kit.card(
		parent,
		"Confort & accessibilité",
		"Animations adoucies, contraste, échelle et compteur d'images.",
		skin
	)
	comfort.frame.LayoutOrder = order
	renderGroups(comfort.body, "options", ctx, {
		only = { Accessibility = true },
		bare = true,
	})

	-- Raccourci clavier : widget dédié, car la valeur est un Enum.KeyCode.
	order += 1
	local keys = Kit.card(parent, "Raccourci clavier", nil, skin)
	keys.frame.LayoutOrder = order

	local keyRow = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	})
	keyRow.Parent = keys.body

	local keyLabel = Theme.label(keyRow, "Touche du menu", 13, skin.palette.text, Enum.Font.GothamMedium)
	keyLabel.Size = UDim2.new(1, -100, 0, 20)
	keyLabel.Position = UDim2.fromOffset(0, 11)

	local keyHelp = Theme.label(
		keyRow,
		"Clique le champ puis appuie sur la touche voulue.",
		10,
		skin.palette.textFaint,
		Enum.Font.Gotham
	)
	keyHelp.Size = UDim2.new(1, -100, 0, 18)
	keyHelp.Position = UDim2.fromOffset(0, 27)

	local listening = false

	local keyButton = Kit.new("TextButton", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		Size = UDim2.fromOffset(84, 32),
		Position = UDim2.new(1, -84, 0, 4),
		Text = tostring(Store.get().menuKey),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = skin.accent.primary,
		AutoButtonColor = false,
	})
	keyButton.Parent = keyRow
	Theme.corner(keyButton, 8)
	local keyStroke = Theme.stroke(keyButton, skin.palette.border, 0.5)

	keyButton.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		listening = true
		keyButton.Text = "…"
		Anim.tween(keyStroke, { Color = skin.accent.primary, Transparency = 0 }, 0.2)
	end)

	local keyListener
	keyListener = UserInputService.InputBegan:Connect(function(input, processed)
		if not listening then
			return
		end
		if processed then
			return
		end
		local code = input.KeyCode
		if code == Enum.KeyCode.Unknown then
			return
		end

		listening = false
		Anim.tween(keyStroke, { Color = skin.palette.border, Transparency = 0.5 }, 0.25)

		local name = code.Name
		if Config.sanitise("menuKey", name) ~= name then
			keyButton.Text = tostring(Store.get().menuKey)
			ctx.notify("Touche refusée : utilise une lettre, un chiffre ou F1-F12.", "warn")
			return
		end

		Store.set("menuKey", name)
		keyButton.Text = name
		Anim.pop(keyButton, 0.3)
		ctx.notify(`Menu désormais sur {name}.`, "ok")
	end)

	keyRow.Destroying:Connect(function()
		if keyListener then
			keyListener:Disconnect()
		end
	end)

	-- Données
	order += 1
	local data = Kit.card(parent, "Données", nil, skin)
	data.frame.LayoutOrder = order

	local statusLabel = Kit.hint(data.body, "En attente de synchronisation…", skin, "ok")
	local statusText = statusLabel:FindFirstChildOfClass("TextLabel") :: TextLabel

	Store.onStatus(function(status)
		local map: { [string]: StatusInfo } = {
			ready = { text = "Configuration synchronisée avec le DataStore.", tone = "ok" },
			saving = { text = "Sauvegarde en cours…", tone = "info" },
			["no-server"] = {
				text = "Broly.server.lua est introuvable : tes réglages ne seront pas conservés.",
				tone = "warn",
			},
			["load-failed"] = {
				text = "Chargement impossible, valeurs par défaut utilisées.",
				tone = "warn",
			},
			error = {
				text = "La sauvegarde a échoué, elle sera réessayée plus tard.",
				tone = "warn",
			},
		}
		local mapped = map[status]
		if mapped then
			statusText.Text = mapped.text
		end
	end)

	local dataRow = Kit.row(data.body, 8, 34)
	dataRow.LayoutOrder = 2

	Kit.button(dataRow, "Sauvegarder", skin, "primary", function()
		Store.save()
		ctx.notify("Sauvegarde envoyée au serveur.", "ok")
	end)

	Kit.button(dataRow, "Réinitialiser", skin, "danger", function()
		Store.reset()
		ctx.notify("Valeurs par défaut restaurées.", "warn")
		ctx.rebuild()
	end)

	Kit.hint(
		data.body,
		"La réinitialisation remet aussi le thème, l'accent et le raccourci clavier par défaut.",
		skin,
		"info"
	)

	-- À propos
	order += 1
	local about = Kit.card(parent, "À propos", nil, skin)
	about.frame.LayoutOrder = order

	local logoRow = Kit.row(about.body, 12, 52)
	logoRow.LayoutOrder = 1

	local logo = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		Size = UDim2.fromOffset(46, 46),
	})
	logo.Parent = logoRow
	Theme.corner(logo, 14)

	local logoAssetId = tonumber(Store.get().logoAssetId) or 0
	if logoAssetId > 0 then
		local image = Kit.new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = `rbxassetid://{logoAssetId}`,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 2,
		})
		image.Parent = logo
		Theme.corner(image, 14)
	else
		local monogram = Kit.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "B",
			TextSize = 24,
			Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(10, 10, 12),
			ZIndex = 2,
		})
		monogram.Parent = logo
	end

	local aboutText = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -58, 0, 46),
	})
	aboutText.Parent = logoRow

	local nameLabel = Theme.label(aboutText, "Broly", 17, skin.palette.text, Enum.Font.GothamBlack)
	nameLabel.Size = UDim2.new(1, 0, 0, 24)

	local authorLabel = Theme.label(aboutText, "par psych0pat3", 11, skin.accent.primary, Enum.Font.GothamBold)
	authorLabel.Size = UDim2.new(1, 0, 0, 18)
	authorLabel.Position = UDim2.fromOffset(0, 24)

	order += 1
	local noteCard = Kit.card(parent, "", nil, skin)
	noteCard.frame.LayoutOrder = order
	Kit.hint(
		noteCard.body,
		"Menu de qualité et de confort pour jeu Roblox. Chaque option agit sur une vraie propriété du moteur, "
			.. "les options serveur passent par Broly.server.lua.",
		skin,
		"info"
	)

	task.defer(function()
		Anim.stagger(parent)
	end)
end

-- ── Dispatcher ──────────────────────────────────────────────────────────────

local BUILDERS: { [string]: (parent: Instance, ctx: Context) -> () } = {
	home = buildHome,
	apps = buildApps,
	presets = buildPresets,
	options = buildOptions,
}

function Pages.build(pageId: string, parent: Instance, ctx: Context): Frame
	local builder = BUILDERS[pageId]

	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	})
	holder.Parent = parent
	Theme.padding(holder, 20)

	local scroll = Kit.scroll(holder, ctx.skin)
	if builder then
		builder(scroll, ctx)
	end

	return holder
end

return Pages
