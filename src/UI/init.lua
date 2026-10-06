--!strict
-- Broly UI - Shell
-- Window chrome, animated navbar, page router, drag, hotkey, toasts and the FPS
-- readout. Changing the theme tears the whole interface down and mounts it
-- again, which is far less error prone than recolouring every instance.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ViewportService = game:GetService("ViewportService")

local Anim = require(script.Parent.Parent.Anim)
local Config = require(script.Parent.Parent.Config)
local Kit = require(script.Parent.Kit)
local Pages = require(script.Parent.Pages)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.Theme)

local UI = {}
UI.__index = UI

local BASE_WIDTH = 1000
local BASE_HEIGHT = 660
local NAV_WIDTH = 214
local TITLE_HEIGHT = 64
local TAB_HEIGHT = 38
local TAB_GAP = 6
local TAB_PADDING = 10

local TABS = {
	{ id = "home", label = "Accueil", badge = "H" },
	{ id = "apps", label = "Apps", badge = "A" },
	{ id = "presets", label = "Presets", badge = "P" },
	{ id = "options", label = "Options", badge = "O" },
}

-- ── Toasts ──────────────────────────────────────────────────────────────────

local function toneColor(skin: Kit.Skin, tone: string): Color3
	if tone == "ok" then
		return Color3.fromRGB(90, 220, 130)
	elseif tone == "warn" then
		return Color3.fromRGB(255, 190, 70)
	end
	return skin.accent.primary
end

local function newToastHost(parent: GuiObject): Frame
	local host = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(290, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = false,
	})
	host.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = host

	return host
end

local function pushToast(host: Frame, text: string, skin: Kit.Skin, tone: string)
	local children = host:GetChildren()
	if #children > 4 then
		local oldest = children[2]
		if oldest and oldest:IsA("GuiObject") then
			oldest:Destroy()
		end
	end

	local color = toneColor(skin, tone)

	local frame = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	frame.Parent = host
	frame.LayoutOrder = tick()
	Theme.corner(frame, 11)
	Theme.padding(frame, 12)
	Theme.stroke(frame, color, 0.6)

	local dot = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(12, 13),
	})
	dot.Parent = frame
	Theme.corner(dot, 4)

	local label = Theme.label(frame, text, 11, skin.palette.text, Enum.Font.GothamMedium)
	label.Size = UDim2.new(1, -28, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.Position = UDim2.fromOffset(28, 10)

	Anim.tween(frame, { BackgroundTransparency = 0.05 }, 0.24)

	local dead = false
	frame.Destroying:Connect(function()
		dead = true
	end)

	task.delay(3.2, function()
		if dead or not frame.Parent then
			return
		end
		Anim.tween(frame, { BackgroundTransparency = 1 }, 0.25)
		task.delay(0.3, function()
			if frame.Parent then
				frame:Destroy()
			end
		end)
	end)
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

export type Controller = {
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	rebuild: () -> (),
	setSkin: (paletteId: string, accentId: string) -> (),
	notify: (text: string, tone: "info" | "warn" | "ok") -> (),
}

function UI.new(screenGui: ScreenGui): Controller
	local self = setmetatable({}, UI)

	self.screenGui = screenGui
	self.connections = {}
	self.instances = {}
	self.unsubscribers = {}
	self.controllers = {}
	self.currentPage = "home"
	self.isOpen = false
	self.fitScale = 1
	self.fpsValue = 0

	local config = Store.get()
	self.skin = {
		palette = Theme.getPalette(config.palette or Theme.DEFAULT_PALETTE),
		accent = Theme.getAccent(config.accent or Theme.DEFAULT_ACCENT),
		contrast = false,
	}
	self.skin.contrast = self.skin.palette.highContrast or config.highContrastText == true

	self:mount()

	return {
		open = function()
			self:open()
		end,
		close = function()
			self:close()
		end,
		toggle = function()
			self:toggle()
		end,
		rebuild = function()
			self:rebuild()
		end,
		setSkin = function(paletteId, accentId)
			self:setSkin(paletteId, accentId)
		end,
		notify = function(text, tone)
			self:notify(text, tone)
		end,
	}
end

function UI:track<T>(item: T): T
	table.insert(self.connections, item :: any)
	return item
end

function UI:listen(unsubscribe: () -> ())
	table.insert(self.unsubscribers, unsubscribe)
end

function UI:dispose()
	for _, unsubscribe in self.unsubscribers do
		pcall(unsubscribe)
	end
	table.clear(self.unsubscribers)

	for _, connection in self.connections do
		if connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	table.clear(self.connections)

	for _, instance in self.instances do
		if instance.Parent then
			instance:Destroy()
		end
	end
	table.clear(self.instances)

	table.clear(self.controllers)
	self.currentHolder = nil
	self.pageHost = nil
	self.fpsLabel = nil
end

-- ── Mount ───────────────────────────────────────────────────────────────────

function UI:mount()
	local skin = self.skin

	-- Honour the accessibility preference before anything animates.
	Anim.setMotionScale(if Store.get().reduceMotion then 0 else 1)

	local root = Kit.new("Frame", {
		Name = "BrolyWindow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	root.Parent = self.screenGui
	self.root = root
	table.insert(self.instances, root)

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = root
	self.uiScale = uiScale

	-- Fake accent bloom: two rounded frames peeking out behind the shell.
	local outerGlow = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(BASE_WIDTH + 36, BASE_HEIGHT + 36),
		Position = UDim2.fromOffset(-18, -18),
		ZIndex = 1,
	})
	outerGlow.Parent = root
	Theme.corner(outerGlow, 34)

	local shell = Kit.new("Frame", {
		Name = "Shell",
		BackgroundColor3 = skin.palette.surface,
		BackgroundTransparency = if skin.contrast then 0 else 0.1,
		Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	shell.Parent = root
	Theme.corner(shell, 20)
	Theme.gradient(shell, 155, {
		skin.palette.surface:Lerp(Color3.fromRGB(255, 255, 255), 0.05),
		skin.palette.base,
	})
	Theme.clip(shell, 20)
	self.shell = shell
	self.shellStroke = Theme.stroke(shell, skin.accent.primary, 0.7)

	-- ── Title bar ───────────────────────────────────────────────────────────

	local titleBar = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		ZIndex = 10,
	})
	titleBar.Parent = shell

	local logo = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(20, 12),
		ZIndex = 11,
	})
	logo.Parent = titleBar
	Theme.corner(logo, 12)
	Theme.clip(logo, 12)
	logo.Active = false

	local logoAssetId = tonumber(Store.get().logoAssetId) or 0
	if logoAssetId > 0 then
		local image = Kit.new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = `rbxassetid://{logoAssetId}`,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 12,
			Active = false,
		})
		image.Parent = logo
	else
		local monogram = Kit.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "B",
			TextSize = 21,
			Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(10, 10, 12),
			ZIndex = 12,
			Active = false,
		})
		monogram.Parent = logo
	end

	local titleLabel = Theme.label(titleBar, "BROLY", 19, skin.palette.text, Enum.Font.GothamBlack)
	titleLabel.Size = UDim2.fromOffset(180, 24)
	titleLabel.Position = UDim2.fromOffset(72, 12)
	titleLabel.ZIndex = 11
	titleLabel.Active = false

	local subtitleLabel = Theme.label(titleBar, "par psych0pat3", 10, skin.palette.textMuted, Enum.Font.GothamMedium)
	subtitleLabel.Size = UDim2.fromOffset(180, 16)
	subtitleLabel.Position = UDim2.fromOffset(72, 34)
	subtitleLabel.ZIndex = 11
	subtitleLabel.Active = false

	local closeButton = Kit.new("TextButton", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -38, 0, 17),
		Text = "✕",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = skin.palette.textMuted,
		AutoButtonColor = false,
		ZIndex = 11,
	})
	closeButton.Parent = titleBar
	Theme.corner(closeButton, 9)
	local closeStroke = Theme.stroke(closeButton, skin.palette.border, 0.5)
	Kit.interactive(closeButton, skin, skin.palette.surfaceAlt, closeStroke)
	closeButton.MouseButton1Click:Connect(function()
		self:close()
	end)

	local divider = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.border,
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, TITLE_HEIGHT),
		ZIndex = 10,
	})
	divider.Parent = shell

	-- ── Navbar ──────────────────────────────────────────────────────────────

	local navbar = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, NAV_WIDTH, 1, -(TITLE_HEIGHT + 1)),
		Position = UDim2.fromOffset(0, TITLE_HEIGHT + 1),
		ZIndex = 10,
	})
	navbar.Parent = shell
	self.navbar = navbar

	local indicator = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		BackgroundTransparency = 0.85,
		Size = UDim2.new(1, -(TAB_PADDING * 2), 0, TAB_HEIGHT),
		Position = UDim2.fromOffset(TAB_PADDING, TAB_PADDING),
		ZIndex = 11,
	})
	indicator.Parent = navbar
	Theme.corner(indicator, 11)
	self.indicator = indicator

	local tabsList = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, (#TABS * TAB_HEIGHT) + ((#TABS - 1) * TAB_GAP) + (TAB_PADDING * 2)),
		ZIndex = 12,
	})
	tabsList.Parent = navbar

	local tabsPadding = Instance.new("UIPadding")
	tabsPadding.PaddingLeft = UDim.new(0, TAB_PADDING)
	tabsPadding.PaddingRight = UDim.new(0, TAB_PADDING)
	tabsPadding.PaddingTop = UDim.new(0, TAB_PADDING)
	tabsPadding.PaddingBottom = UDim.new(0, TAB_PADDING)
	tabsPadding.Parent = tabsList

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Padding = UDim.new(0, TAB_GAP)
	tabsLayout.Parent = tabsList

	local tabButtons = {}
	self.tabButtons = tabButtons

	for index, tab in TABS do
		local button = Kit.new("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			ZIndex = 13,
		})
		button.Parent = tabsList

		local badge = Kit.new("Frame", {
			BackgroundColor3 = skin.accent.primary,
			BackgroundTransparency = 0.85,
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(0, (TAB_HEIGHT - 24) / 2),
			ZIndex = 14,
			Active = false,
		})
		badge.Parent = button
		Theme.corner(badge, 8)

		local badgeText = Kit.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = tab.badge,
			TextSize = 11,
			Font = Enum.Font.GothamBlack,
			TextColor3 = skin.accent.primary,
			ZIndex = 15,
			Active = false,
		})
		badgeText.Parent = badge

		local label = Theme.label(button, tab.label, 13, skin.palette.textMuted, Enum.Font.GothamMedium)
		label.Size = UDim2.new(1, -40, 0, 18)
		label.Position = UDim2.fromOffset(34, (TAB_HEIGHT - 18) / 2)
		label.ZIndex = 14
		label.Active = false

		tabButtons[tab.id] = { button = button, label = label, badge = badge, badgeText = badgeText }

		button.MouseEnter:Connect(function()
			if self.currentPage ~= tab.id then
				Anim.tween(label, { TextTransparency = 0.4 }, 0.16)
			end
		end)
		button.MouseLeave:Connect(function()
			Anim.tween(label, { TextTransparency = 0 }, 0.2)
		end)

		button.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			self:goTo(tab.id)
		end)
	end

	local footer = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(TAB_PADDING * 2), 0, 16),
		Position = UDim2.new(0, TAB_PADDING, 1, -26),
		Text = `Broly v1.0 · {skin.palette.label}`,
		TextSize = 9,
		Font = Enum.Font.Gotham,
		TextColor3 = skin.palette.textFaint,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	footer.Parent = navbar

	-- ── Content ─────────────────────────────────────────────────────────────

	local content = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -NAV_WIDTH, 1, -(TITLE_HEIGHT + 1)),
		Position = UDim2.fromOffset(NAV_WIDTH, TITLE_HEIGHT + 1),
		ClipsDescendants = true,
		ZIndex = 10,
	})
	content.Parent = shell

	local pageHost = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
	})
	pageHost.Parent = content
	self.pageHost = pageHost

	self.toastHost = newToastHost(root)

	-- ── FPS readout ─────────────────────────────────────────────────────────

	local fpsAccum, fpsFrames = 0, 0
	self:track(RunService.Heartbeat:Connect(function(dt)
		fpsAccum += dt
		fpsFrames += 1
		if fpsAccum < 0.5 then
			return
		end
		self.fpsValue = math.floor(fpsFrames / fpsAccum)
		fpsAccum = 0
		fpsFrames = 0

		local label = self.fpsLabel
		if label and label.Parent then
			label.Text = `{self.fpsValue} FPS`
			label.TextColor3 = if self.fpsValue >= 55
				then Color3.fromRGB(120, 230, 150)
				elseif self.fpsValue >= 30 then Color3.fromRGB(255, 210, 90)
				else Color3.fromRGB(255, 110, 110)
		end
	end))

	-- ── Drag ────────────────────────────────────────────────────────────────

	local dragging = false
	local dragOffset = Vector2.zero

	local function clampPosition()
		local viewport = ViewportService:GetCameraViewportSize()
		local scale = self.fitScale * self.uiScale.Scale
		local halfW = (BASE_WIDTH * scale) / 2
		local halfH = (BASE_HEIGHT * scale) / 2
		root.Position = UDim2.fromOffset(
			math.clamp(root.Position.X.Offset, halfW + 6, viewport.X - halfW - 6),
			math.clamp(root.Position.Y.Offset, halfH + 6, viewport.Y - halfH - 6)
		)
	end
	self.clampPosition = clampPosition

	self:track(titleBar.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		dragOffset = Vector2.new(input.Position.X - root.AbsolutePosition.X, input.Position.Y - root.AbsolutePosition.Y)
	end))

	self:track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			root.Position = UDim2.fromOffset(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y)
			clampPosition()
		end
	end))

	self:track(UserInputService.InputEnded:Connect(function()
		dragging = false
	end))

	local function applyViewportFit()
		local viewport = ViewportService:GetCameraViewportSize()
		local fit = math.min(1, (viewport.X - 40) / BASE_WIDTH, (viewport.Y - 40) / BASE_HEIGHT)
		self.fitScale = math.clamp(fit, 0.55, 1)
		local preference = tonumber(Store.get().uiScale) or 1
		uiScale.Scale = self.fitScale * preference
		clampPosition()
	end
	self.applyViewportFit = applyViewportFit

	applyViewportFit()
	self:track(ViewportService:GetPropertyChangedSignal("CameraViewportSize"):Connect(applyViewportFit))

	-- ── Hotkey ──────────────────────────────────────────────────────────────

	local function bindHotkey()
		if self.hotkeyConnection then
			self.hotkeyConnection:Disconnect()
			self.hotkeyConnection = nil
		end
		local code = Config.keyValue("menuKey", Store.get().menuKey)
		if not code then
			return
		end
		self.hotkeyConnection = self:track(UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == code then
				self:toggle()
			end
		end))
	end
	self.bindHotkey = bindHotkey
	bindHotkey()

	-- ── Global toggles ──────────────────────────────────────────────────────

	local function syncGlobalToggles()
		Anim.setMotionScale(if Store.get().reduceMotion then 0 else 1)

		local wantsFps = Store.get().showFps == true
		if wantsFps and not self.fpsLabel then
			local label = Kit.new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(120, 20),
				Position = UDim2.fromOffset(14, 8),
				Text = `-- FPS`,
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextColor3 = skin.palette.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 40,
			})
			label.Parent = self.screenGui
			self.fpsLabel = label
			table.insert(self.instances, label)
		elseif not wantsFps and self.fpsLabel then
			local index = table.find(self.instances, self.fpsLabel)
			if index then
				table.remove(self.instances, index)
			end
			self.fpsLabel:Destroy()
			self.fpsLabel = nil
		end

		if self.fpsLabel then
			self.fpsLabel.Text = `{self.fpsValue} FPS`
		end

		applyViewportFit()
		Store.apply()
	end
	self.syncGlobalToggles = syncGlobalToggles

	self:listen(Store.onChange(function(_, key)
		if key == "reduceMotion" or key == "showFps" or key == "uiScale" then
			syncGlobalToggles()
		elseif key == "menuKey" then
			bindHotkey()
		end
	end))

	-- A theme change (from a swatch, a preset import or a reset) remounts the
	-- whole interface. Store.set only emits when the value really changed, so
	-- this cannot loop.
	self:listen(Store.onChange(function(_, key)
		if key == "palette" or key == "accent" or key == "logoAssetId" or key == "highContrastText" then
			task.defer(function()
				self:rebuild()
			end)
		end
	end))

	syncGlobalToggles()
	self:goTo(self.currentPage, true)
end

-- ── Public actions ──────────────────────────────────────────────────────────

function UI:makeContext(): Pages.Context
	return {
		skin = self.skin,
		controllers = self.controllers,
		rebuild = function()
			self:rebuild()
		end,
		setSkin = function(paletteId, accentId)
			self:setSkin(paletteId, accentId)
		end,
		notify = function(text, tone)
			self:notify(text, tone)
		end,
	}
end

function UI:markTabs(pageId: string)
	local skin = self.skin
	for id, tab in self.tabButtons do
		local active = id == pageId
		Anim.tween(tab.label, {
			TextColor3 = if active then skin.palette.text else skin.palette.textMuted,
		}, 0.2)
		Anim.tween(tab.badge, {
			BackgroundTransparency = if active then 0.55 else 0.85,
		}, 0.2)
		Anim.tween(tab.badgeText, {
			TextColor3 = if active then skin.palette.text else skin.accent.primary,
		}, 0.2)
	end
end

function UI:goTo(pageId: string, instant: boolean?)
	if self.currentPage == pageId and self.currentHolder then
		return
	end
	self.currentPage = pageId

	for index, tab in TABS do
		if tab.id == pageId then
			Anim.moveTo(
				self.indicator,
				UDim2.fromOffset(TAB_PADDING, TAB_PADDING + (index - 1) * (TAB_HEIGHT + TAB_GAP))
			)
			break
		end
	end

	self:markTabs(pageId)

	local previous = self.currentHolder
	self.currentHolder = nil

	if previous then
		Anim.fadeOut(previous, 0.12)
		task.delay(0.14, function()
			if previous.Parent then
				previous:Destroy()
			end
		end)
	end

	local holder = Pages.build(pageId, self.pageHost, self:makeContext())
	self.currentHolder = holder

	if instant or Anim.MotionScale <= 0 then
		holder.GroupTransparency = 0
	else
		Anim.fadeIn(holder, 0.24)
	end
end

function UI:notify(text: string, tone: "info" | "warn" | "ok")
	if self.toastHost then
		pushToast(self.toastHost, text, self.skin, tone)
	end
end

function UI:setSkin(paletteId: string, accentId: string)
	self.skin.palette = Theme.getPalette(paletteId or self.skin.palette.id)
	self.skin.accent = Theme.getAccent(accentId or self.skin.accent.id)
	self.skin.contrast = self.skin.palette.highContrast
	-- Persisting emits a store change, which remounts the interface.
	Store.setMany({ palette = self.skin.palette.id, accent = self.skin.accent.id })
end

function UI:rebuild()
	local wasOpen = self.isOpen

	self:dispose()
	self:mount()

	if not wasOpen then
		self.isOpen = false
		if self.root then
			self.root.Visible = false
			self.root.GroupTransparency = 1
		end
	end
end

function UI:open()
	if self.isOpen or not self.root then
		return
	end
	self.isOpen = true
	self.root.Visible = true

	if Anim.MotionScale <= 0 then
		self.root.GroupTransparency = 0
		self:goTo(self.currentPage, true)
		return
	end

	self.root.GroupTransparency = 1
	Anim.tween(self.root, { GroupTransparency = 0 }, 0.2)
	self:goTo(self.currentPage, true)
end

function UI:close()
	if not self.isOpen or not self.root then
		return
	end
	self.isOpen = false

	if Anim.MotionScale <= 0 then
		self.root.GroupTransparency = 1
		self.root.Visible = false
		return
	end

	Anim.tween(self.root, { GroupTransparency = 1 }, 0.15)
	task.delay(0.18, function()
		if not self.isOpen and self.root then
			self.root.Visible = false
		end
	end)
end

function UI:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

return UI
