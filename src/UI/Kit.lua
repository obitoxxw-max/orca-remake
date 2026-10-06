--!strict
-- Broly UI - Component kit
-- Reusable widgets built imperatively on top of Roblox instances. Everything
-- is themed from a (palette, accent) pair passed in at build time; changing
-- the theme rebuilds the interface rather than patching it.

local UserInputService = game:GetService("UserInputService")

local Anim = require(script.Parent.Parent.Anim)
local Config = require(script.Parent.Parent.Config)
local Theme = require(script.Parent.Parent.Theme)

local Kit = {}

export type Skin = {
	palette: Theme.Palette,
	accent: Theme.Accent,
	contrast: boolean,
}

export type OnChange = (value: any) -> ()

-- ── Base helpers ────────────────────────────────────────────────────────────

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function textColor(skin: Skin): Color3
	if skin.contrast then
		return Color3.new(1, 1, 1)
	end
	return skin.palette.text
end

local function mutedColor(skin: Skin): Color3
	if skin.contrast then
		return Color3.new(0.85, 0.85, 0.85)
	end
	return skin.palette.textMuted
end

--- Adds a hover / press / release feedback loop to any button.
function Kit.interactive(button: GuiObject, skin: Skin, baseColor: Color3?, stroke: UIStroke?)
	button.MouseEnter:Connect(function()
		Anim.tween(button, {
			BackgroundColor3 = if baseColor then baseColor:Lerp(Color3.new(1, 1, 1), 0.08) else skin.palette.surfaceAlt,
		}, 0.18)
		if stroke then
			Anim.tween(stroke, { Transparency = 0.2 }, 0.18)
		end
	end)

	button.MouseLeave:Connect(function()
		Anim.tween(button, { BackgroundColor3 = baseColor or skin.palette.surfaceAlt }, 0.22)
		if stroke then
			Anim.tween(stroke, { Transparency = 0.5 }, 0.22)
		end
	end)
end

--- Lays out a row of children horizontally, spaced by `gap`.
function Kit.row(parent: Instance, gap: number, height: number?): Frame
	local frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 0),
	})
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.VerticalAlignment.Left
	layout.Parent = frame
	return frame
end

function Kit.column(parent: Instance, gap: number): Frame
	local frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = frame
	return frame
end

-- ── Card ────────────────────────────────────────────────────────────────────

export type Card = {
	frame: Frame,
	body: Frame,
}

function Kit.card(parent: Instance, title: string, subtitle: string?, skin: Skin): Card
	local frame = Kit.new("Frame", {
		Name = title,
		BackgroundColor3 = skin.palette.surface,
		BackgroundTransparency = skin.contrast and 0 or 0.35,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	frame.Parent = parent
	Theme.corner(frame, 14)
	local stroke = Theme.stroke(frame, skin.palette.border, 0.5)
	if not skin.contrast then
		Theme.gradient(frame, 145, {
			Color3.fromRGB(255, 255, 255):Lerp(skin.palette.surface, 0.94),
			skin.palette.surface:Lerp(Color3.fromRGB(0, 0, 0), 0.12),
		})
	end
	Theme.padding(frame, 16)

	local header = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	header.Parent = frame
	Theme.padding(header, 0)

	local titleLabel = Theme.label(header, title, 15, textColor(skin), Enum.Font.GothamBold)
	titleLabel.LayoutOrder = 1

	local subLabel
	if subtitle then
		subLabel = Theme.label(header, subtitle, 11, mutedColor(skin), Enum.Font.Gotham)
		subLabel.LayoutOrder = 2
		subLabel.Size = UDim2.new(1, 0, 0, 18)
		subLabel.TextWrapped = true
		subLabel.Position = UDim2.fromOffset(0, 20)
		titleLabel.Size = UDim2.new(1, 0, 0, 20)
	end

	-- Header uses an absolute-positioned layout because the subtitle wraps.
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 0)
	headerLayout.Parent = header

	local divider = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.border,
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 10,
	})
	divider.Parent = frame
	Theme.corner(divider, 1)

	local body = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 11,
	})
	body.Parent = frame

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 10)
	bodyLayout.Parent = body

	return { frame = frame, body = body }
end

-- ── Section title inside a card ─────────────────────────────────────────────

function Kit.section(parent: Instance, text: string, skin: Skin)
	local label = Theme.label(parent, string.upper(text), 10, skin.palette.textFaint, Enum.Font.GothamBold)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, 0, 0, 14)
	label.LayoutOrder = -100
	return label
end

-- ── Toggle ──────────────────────────────────────────────────────────────────

function Kit.toggle(parent: Instance, entry: Config.Entry, current: boolean, skin: Skin, onChange: OnChange)
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	row.Parent = parent

	local hit = Kit.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	})
	hit.Parent = row

	local label = Theme.label(hit, entry.label, 13, textColor(skin), Enum.Font.GothamMedium)
	label.Size = UDim2.new(1, -60, 0, 20)
	label.Position = UDim2.fromOffset(0, 10)

	if entry.help then
		local help = Theme.label(hit, entry.help, 10, skin.palette.textFaint, Enum.Font.Gotham)
		help.Size = UDim2.new(1, -60, 0, 26)
		help.Position = UDim2.fromOffset(0, 27)
		help.TextWrapped = true
		help.TextXAlignment = Enum.TextXAlignment.Left
	end

	local track = Kit.new("Frame", {
		BackgroundColor3 = current and skin.accent.primary or skin.palette.surfaceAlt,
		Size = UDim2.fromOffset(42, 23),
		Position = UDim2.new(1, -42, 0, 9),
		ZIndex = 3,
		Active = false,
	})
	track.Parent = row
	Theme.corner(track, 12)

	local knob = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(17, 17),
		Position = UDim2.fromOffset(current and 21 or 4, 3),
		ZIndex = 4,
		Active = false,
	})
	knob.Parent = track
	Theme.corner(knob, 9)
	Theme.shadow(knob, UDim2.fromOffset(17, 17), Vector2.new(0, 1), 0.3, 9)

	local state = current

	local function render(animate: boolean)
		local accent = skin.accent.primary
		local target = state and accent or skin.palette.surfaceAlt

		if animate then
			Anim.tween(track, { BackgroundColor3 = target }, 0.25)
			Anim.moveTo(knob, UDim2.fromOffset(state and 21 or 4, 3), {
				stiffness = 420,
				damping = 28,
				restDelta = 0.2,
			})
			Anim.tween(knob, {
				BackgroundColor3 = state and Color3.new(1, 1, 1) or skin.palette.textMuted,
			}, 0.25)
		else
			track.BackgroundColor3 = target
			knob.Position = UDim2.fromOffset(state and 21 or 4, 3)
			knob.BackgroundColor3 = state and Color3.new(1, 1, 1) or skin.palette.textMuted
		end
	end

	hit.MouseEnter:Connect(function()
		Anim.tween(label, { TextTransparency = 0.08 }, 0.16)
	end)
	hit.MouseLeave:Connect(function()
		Anim.tween(label, { TextTransparency = 0 }, 0.2)
	end)

	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		state = not state
		render(true)
		onChange(state)
	end)

	return {
		set = function(value: boolean)
			state = value == true
			render(true)
		end,
		refresh = function(value: boolean)
			if value ~= state then
				state = value == true
				render(true)
			end
		end,
	}
end

-- ── Slider ──────────────────────────────────────────────────────────────────

function Kit.slider(parent: Instance, entry: Config.Entry, current: number, skin: Skin, onChange: OnChange)
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
	})
	row.Parent = parent

	local hit = Kit.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		AutoButtonColor = false,
	})
	hit.Parent = row

	local label = Theme.label(hit, entry.label, 13, textColor(skin), Enum.Font.GothamMedium)
	label.Size = UDim2.new(1, -70, 0, 20)
	label.Position = UDim2.fromOffset(0, 6)

	local valueLabel =
		Theme.label(hit, Config.formatValue(entry, current), 12, skin.accent.primary, Enum.Font.GothamBold)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Size = UDim2.new(1, 0, 0, 18)
	valueLabel.Position = UDim2.fromOffset(0, 7)

	local trackWidth = 0

	local track = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		Size = UDim2.new(1, -18, 0, 8),
		Position = UDim2.fromOffset(0, 36),
		ClipsDescendants = true,
		Active = false,
	})
	track.Parent = row
	Theme.corner(track, 4)

	local fill = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		Size = UDim2.fromScale(0, 1),
		Active = false,
	})
	fill.Parent = track
	Theme.corner(fill, 4)

	-- Glow behind the knob for the accent bloom.
	local knob = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(0, 28),
		ZIndex = 3,
		Active = false,
	})
	knob.Parent = row
	Theme.corner(knob, 8)
	Theme.stroke(knob, skin.palette.border, 0.3, 2)

	local glow = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.glow,
		BackgroundTransparency = 0.75,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(-5, 23),
		ZIndex = 2,
		Active = false,
	})
	glow.Parent = row
	Theme.corner(glow, 13)

	local minValue = entry.min or 0
	local maxValue = entry.max or 100
	local value = current

	local function ratio(): number
		if maxValue <= minValue then
			return 0
		end
		return math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
	end

	local function renderFill(animate: boolean)
		local t = ratio()
		if animate then
			Anim.tween(fill, { Size = UDim2.fromScale(t, 1) }, 0.18)
			local knobX = t * math.max(trackWidth - 16, 0)
			Anim.moveTo(knob, UDim2.fromOffset(knobX, 28), { stiffness = 400, damping = 30, restDelta = 0.3 })
			Anim.moveTo(glow, UDim2.fromOffset(knobX - 5, 23), { stiffness = 400, damping = 30, restDelta = 0.3 })
		else
			fill.Size = UDim2.fromScale(t, 1)
			knob.Position = UDim2.fromOffset(t * math.max(trackWidth - 16, 0), 28)
			glow.Position = UDim2.fromOffset(t * math.max(trackWidth - 16, 0) - 5, 23)
		end
		valueLabel.Text = Config.formatValue(entry, value)
	end

	local function setFromX(absoluteX: number)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local t = math.clamp((absoluteX - left) / width, 0, 1)
		local next = minValue + (t * (maxValue - minValue))
		local clean = Config.sanitise(entry.key, next)
		if clean ~= value then
			value = clean
			renderFill(false)
			onChange(clean)
		end
	end

	local dragging = false

	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function()
		if dragging then
			dragging = false
			renderFill(true)
		end
	end)

	-- Keep the knob pinned to the track width as the window resizes.
	local function readWidth()
		trackWidth = track.AbsoluteSize.X
		renderFill(false)
	end
	track:GetPropertyChangedSignal("AbsoluteSize"):Connect(readWidth)
	task.defer(readWidth)

	hit.MouseEnter:Connect(function()
		Anim.tween(knob, { Size = UDim2.fromOffset(19, 19) }, 0.18)
		Anim.tween(glow, { BackgroundTransparency = 0.6 }, 0.18)
	end)
	hit.MouseLeave:Connect(function()
		Anim.tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.2)
		Anim.tween(glow, { BackgroundTransparency = 0.75 }, 0.2)
	end)

	return {
		set = function(newValue: number)
			value = newValue
			renderFill(true)
		end,
		refresh = function(newValue: number)
			if newValue ~= value then
				value = newValue
				renderFill(true)
			end
		end,
	}
end

-- ── Segmented control ───────────────────────────────────────────────────────

function Kit.segmented(parent: Instance, entry: Config.Entry, current: string, skin: Skin, onChange: OnChange)
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, entry.help and 66 or 50),
	})
	row.Parent = parent

	local label = Theme.label(row, entry.label, 13, textColor(skin), Enum.Font.GothamMedium)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Position = UDim2.fromOffset(0, 0)

	if entry.help then
		local help = Theme.label(row, entry.help, 10, skin.palette.textFaint, Enum.Font.Gotham)
		help.Size = UDim2.new(1, 0, 0, 28)
		help.Position = UDim2.fromOffset(0, 17)
		help.TextWrapped = true
	end

	local count = #entry.choices
	local container = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		BackgroundTransparency = skin.contrast and 0 or 0.3,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, entry.help and 44 or 26),
	})
	container.Parent = row
	Theme.corner(container, 10)
	Theme.stroke(container, skin.palette.border, 0.55)

	local indicator = Kit.new("Frame", {
		BackgroundColor3 = skin.accent.primary,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1 / count, 1),
		Active = false,
	})
	indicator.Parent = container
	Theme.corner(indicator, 8)

	local buttons = {}
	local value = current

	local function moveIndicator(animate: boolean)
		local index = 1
		for position, choice in entry.choices do
			if choice.id == value then
				index = position
				break
			end
		end
		local target = UDim2.fromScale(1 / count, 1, (index - 1) / count, 0)
		if animate then
			Anim.tween(indicator, { Position = target }, 0.3, Anim.EASING.enter)
		else
			indicator.Position = target
		end
	end

	for index, choice in entry.choices do
		local button = Kit.new("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1 / count, 1),
			Text = choice.label,
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextColor3 = mutedColor(skin),
			AutoButtonColor = false,
			ZIndex = 3,
		})
		button.Parent = container
		buttons[choice.id] = button

		button.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			value = choice.id
			moveIndicator(true)
			Anim.pop(container, 0.24)
			for id, other in buttons do
				Anim.tween(other, {
					TextColor3 = if id == choice.id then textColor(skin) else mutedColor(skin),
				}, 0.2)
			end
			onChange(choice.id)
		end)
	end

	moveIndicator(false)
	for id, button in buttons do
		button.TextColor3 = if id == current then textColor(skin) else mutedColor(skin)
	end

	return {
		set = function(newValue: string)
			value = newValue
			moveIndicator(true)
			for id, button in buttons do
				Anim.tween(button, {
					TextColor3 = if id == newValue then textColor(skin) else mutedColor(skin),
				}, 0.2)
			end
		end,
		refresh = function(newValue: string)
			if newValue ~= value then
				value = newValue
				moveIndicator(true)
			end
		end,
	}
end

-- ── Colour swatch row ───────────────────────────────────────────────────────

function Kit.swatches(
	parent: Instance,
	labelText: string,
	accents: { Theme.Accent },
	currentId: string,
	skin: Skin,
	onChange: (id: string) -> ()
)
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
	})
	row.Parent = parent

	local label = Theme.label(row, labelText, 13, textColor(skin), Enum.Font.GothamMedium)
	label.Size = UDim2.new(1, 0, 0, 20)

	local strip = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 24),
	})
	strip.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = strip

	local buttons = {}

	for index, accent in accents do
		local button = Kit.new("TextButton", {
			BackgroundColor3 = accent.primary,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(0, 0),
			Text = "",
			AutoButtonColor = false,
		})
		button.Parent = strip
		Theme.corner(button, 13)
		buttons[accent.id] = button

		local ring = Theme.stroke(button, Color3.new(1, 1, 1), 1, 2)
		ring.Name = "Ring"

		local function render(selected: boolean, animate: boolean)
			Anim.tween(ring, {
				Transparency = if selected then 0.15 else 1,
			}, animate and 0.2 or 0)
			Anim.tween(button, {
				Size = if selected then UDim2.fromOffset(30, 30) else UDim2.fromOffset(26, 26),
			}, animate and 0.25 or 0, Anim.EASING.enter)
		end

		render(accent.id == currentId, false)

		button.MouseEnter:Connect(function()
			Anim.tween(button, {
				BackgroundColor3 = accent.glow,
			}, 0.18)
		end)
		button.MouseLeave:Connect(function()
			Anim.tween(button, {
				BackgroundColor3 = accent.primary,
			}, 0.22)
		end)

		button.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			for id, other in buttons do
				local otherRing = other:FindFirstChild("Ring") :: UIStroke
				local selected = id == accent.id
				Anim.tween(otherRing, { Transparency = if selected then 0.15 else 1 }, 0.2)
				Anim.tween(other, {
					Size = if selected then UDim2.fromOffset(30, 30) else UDim2.fromOffset(26, 26),
				}, 0.25, Anim.EASING.enter)
			end
			Anim.pop(button, 0.3)
			onChange(accent.id)
		end)
	end

	return {
		set = function(newId: string)
			for id, button in buttons do
				local ring = button:FindFirstChild("Ring") :: UIStroke
				local selected = id == newId
				Anim.tween(ring, { Transparency = if selected then 0.15 else 1 }, 0.2)
				Anim.tween(button, {
					Size = if selected then UDim2.fromOffset(30, 30) else UDim2.fromOffset(26, 26),
				}, 0.25, Anim.EASING.enter)
			end
		end,
	}
end

-- ── Buttons ─────────────────────────────────────────────────────────────────

export type ButtonVariant = "primary" | "ghost" | "danger"

function Kit.button(parent: Instance, labelText: string, skin: Skin, variant: ButtonVariant?, onClick: () -> ())
	variant = variant or "ghost"

	local background, textTone
	if variant == "primary" then
		background = skin.accent.primary
		textTone = Color3.new(0.05, 0.05, 0.05)
	elseif variant == "danger" then
		background = skin.palette.surfaceAlt
		textTone = Color3.fromRGB(255, 120, 130)
	else
		background = skin.palette.surfaceAlt
		textTone = textColor(skin)
	end

	local button = Kit.new("TextButton", {
		BackgroundColor3 = background,
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = labelText,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = textTone,
		AutoButtonColor = false,
	})
	button.Parent = parent
	Theme.corner(button, 9)
	Theme.padding(button, 14)

	if variant ~= "primary" then
		Theme.stroke(button, skin.palette.border, 0.5)
	end

	local base = background
	local hover = if variant == "primary" then skin.accent.glow:Lerp(skin.accent.primary, 0.35) else skin.palette.border

	Kit.interactive(button, skin, base, button:FindFirstChildOfClass("UIStroke"))

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		Anim.tween(button, { BackgroundColor3 = hover }, 0.12)
	end)
	button.InputEnded:Connect(function()
		Anim.tween(button, { BackgroundColor3 = base }, 0.2)
	end)

	button.MouseButton1Click:Connect(function()
		Anim.pop(button, 0.26)
		onClick()
	end)

	return button
end

-- ── Text field ──────────────────────────────────────────────────────────────

function Kit.textField(parent: Instance, placeholder: string, skin: Skin)
	local box = Kit.new("TextBox", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = skin.palette.textFaint,
		TextColor3 = textColor(skin),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
	})
	box.Parent = parent
	Theme.corner(box, 9)
	Theme.padding(box, 12)
	Theme.stroke(box, skin.palette.border, 0.5)

	local stroke = box:FindFirstChildOfClass("UIStroke") :: UIStroke
	box.Focused:Connect(function()
		Anim.tween(stroke, { Color = skin.accent.primary, Transparency = 0.2 }, 0.18)
	end)
	box.FocusLost:Connect(function()
		Anim.tween(stroke, { Color = skin.palette.border, Transparency = 0.5 }, 0.22)
	end)

	return box
end

-- ── Scroll container ────────────────────────────────────────────────────────

function Kit.scroll(parent: Instance, skin: Skin): ScrollingFrame
	local frame = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = skin.accent.primary,
		ScrollBarImageTransparency = 0.35,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
	})
	frame.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	layout.Parent = frame

	return frame
end

-- ── Hint / status strip ─────────────────────────────────────────────────────

function Kit.hint(parent: Instance, text: string, skin: Skin, tone: "info" | "warn" | "ok")
	local frame = Kit.new("Frame", {
		BackgroundColor3 = skin.palette.surfaceAlt,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	frame.Parent = parent
	Theme.corner(frame, 10)
	Theme.padding(frame, 12)

	local dot = Kit.new("Frame", {
		BackgroundColor3 = if tone == "ok"
			then Color3.fromRGB(90, 220, 130)
			elseif tone == "warn" then Color3.fromRGB(255, 190, 70)
			else skin.accent.primary,
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(0, 6),
		Active = false,
	})
	dot.Parent = frame
	Theme.corner(dot, 4)

	local label = Theme.label(frame, text, 11, mutedColor(skin), Enum.Font.Gotham)
	label.Size = UDim2.new(1, -18, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.Position = UDim2.fromOffset(16, 0)
	label.Active = false

	return frame
end

return Kit
