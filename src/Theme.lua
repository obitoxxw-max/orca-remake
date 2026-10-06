--!strict
-- Broly UI - Theme
-- Palettes, accents and small instance helpers used across the interface.

local Theme = {}

export type Accent = {
	id: string,
	label: string,
	primary: Color3,
	secondary: Color3,
	glow: Color3,
}

export type Palette = {
	id: string,
	label: string,
	base: Color3,
	surface: Color3,
	surfaceAlt: Color3,
	border: Color3,
	text: Color3,
	textMuted: Color3,
	textFaint: Color3,
	shadow: Color3,
	highContrast: boolean,
}

-- ── Base palettes ───────────────────────────────────────────────────────────

Theme.PALETTES = {
	{
		id = "midnight",
		label = "Midnight",
		base = Color3.fromRGB(8, 9, 14),
		surface = Color3.fromRGB(17, 19, 27),
		surfaceAlt = Color3.fromRGB(25, 28, 38),
		border = Color3.fromRGB(46, 51, 66),
		text = Color3.fromRGB(238, 241, 248),
		textMuted = Color3.fromRGB(148, 157, 178),
		textFaint = Color3.fromRGB(94, 102, 121),
		shadow = Color3.fromRGB(0, 0, 0),
		highContrast = false,
	},
	{
		id = "obsidian",
		label = "Obsidian",
		base = Color3.fromRGB(0, 0, 0),
		surface = Color3.fromRGB(10, 10, 12),
		surfaceAlt = Color3.fromRGB(20, 20, 24),
		border = Color3.fromRGB(40, 40, 48),
		text = Color3.fromRGB(250, 250, 252),
		textMuted = Color3.fromRGB(160, 160, 172),
		textFaint = Color3.fromRGB(104, 104, 116),
		shadow = Color3.fromRGB(0, 0, 0),
		highContrast = false,
	},
	{
		id = "carbon",
		label = "Carbon",
		base = Color3.fromRGB(22, 24, 28),
		surface = Color3.fromRGB(31, 34, 40),
		surfaceAlt = Color3.fromRGB(41, 45, 53),
		border = Color3.fromRGB(62, 67, 78),
		text = Color3.fromRGB(240, 242, 246),
		textMuted = Color3.fromRGB(154, 161, 174),
		textFaint = Color3.fromRGB(102, 108, 120),
		shadow = Color3.fromRGB(0, 0, 0),
		highContrast = false,
	},
	{
		id = "contrast",
		label = "High Contrast",
		base = Color3.fromRGB(0, 0, 0),
		surface = Color3.fromRGB(12, 12, 12),
		surfaceAlt = Color3.fromRGB(30, 30, 30),
		border = Color3.fromRGB(210, 210, 210),
		text = Color3.fromRGB(255, 255, 255),
		textMuted = Color3.fromRGB(226, 226, 226),
		textFaint = Color3.fromRGB(190, 190, 190),
		shadow = Color3.fromRGB(0, 0, 0),
		highContrast = true,
	},
}

-- ── Accents (Broly inspired) ────────────────────────────────────────────────

Theme.ACCENTS = {
	{
		id = "lime",
		label = "Lime",
		primary = Color3.fromRGB(176, 255, 60),
		secondary = Color3.fromRGB(96, 200, 24),
		glow = Color3.fromRGB(140, 255, 90),
	},
	{
		id = "golden",
		label = "Golden",
		primary = Color3.fromRGB(255, 200, 40),
		secondary = Color3.fromRGB(240, 150, 16),
		glow = Color3.fromRGB(255, 232, 140),
	},
	{
		id = "crimson",
		label = "Crimson",
		primary = Color3.fromRGB(255, 68, 88),
		secondary = Color3.fromRGB(198, 26, 52),
		glow = Color3.fromRGB(255, 130, 145),
	},
	{
		id = "vast",
		label = "Vast",
		primary = Color3.fromRGB(70, 220, 255),
		secondary = Color3.fromRGB(20, 150, 210),
		glow = Color3.fromRGB(150, 240, 255),
	},
	{
		id = "legendary",
		label = "Legendary",
		primary = Color3.fromRGB(186, 110, 255),
		secondary = Color3.fromRGB(126, 52, 200),
		glow = Color3.fromRGB(220, 175, 255),
	},
}

Theme.DEFAULT_PALETTE = "midnight"
Theme.DEFAULT_ACCENT = "golden"

-- ── Resolution ──────────────────────────────────────────────────────────────

function Theme.getPalette(id: string): Palette
	for _, palette in Theme.PALETTES do
		if palette.id == id then
			return palette
		end
	end
	return Theme.PALETTES[1]
end

function Theme.getAccent(id: string): Accent
	for _, accent in Theme.ACCENTS do
		if accent.id == id then
			return accent
		end
	end
	return Theme.ACCENTS[1]
end

-- ── Instance helpers ────────────────────────────────────────────────────────

function Theme.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Transparency = transparency
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

--- Rounded clipping. Roblox has no clip-path, so a frame with matching corner
--- radius and ClipsDescendants is the only way to keep children inside a
--- rounded container.
function Theme.clip(parent: GuiObject, radius: number)
	local frame = Instance.new("Frame")
	frame.Name = "Clip"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ClipsDescendants = true
	frame.BorderSizePixel = 0
	frame.ZIndex = parent.ZIndex
	frame.Parent = parent
	Theme.corner(frame, radius)
	return frame
end

--- Cheap drop shadow: a solid black copy offset behind the object. Roblox has
--- no blur primitive, so this is the closest thing that stays performant.
function Theme.shadow(parent: Instance, size: UDim2, offset: Vector2, transparency: number, radius: number)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = transparency
	shadow.BorderSizePixel = 0
	shadow.Size = size
	shadow.Position = UDim2.fromOffset(offset.X, offset.Y)
	shadow.ZIndex = (parent :: GuiObject).ZIndex - 1
	shadow.Parent = parent
	Theme.corner(shadow, radius)
	return shadow
end

function Theme.gradient(parent: Instance, rotation: number, stops: { Color3 })
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	for index, color in stops do
		g.Color = ColorSequence.new(index - 1, color)
	end
	g.Parent = parent
	return g
end

function Theme.padding(parent: Instance, all: number?)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, all or 0)
	p.PaddingRight = UDim.new(0, all or 0)
	p.PaddingTop = UDim.new(0, all or 0)
	p.PaddingBottom = UDim.new(0, all or 0)
	p.Parent = parent
	return p
end

function Theme.list(parent: Instance, direction: number, gap: number, padding: number?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Left
	if padding then
		l.VerticalAlignment = padding
	end
	l.Parent = parent
	if direction == Enum.FillDirection.Horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	return l
end

function Theme.pin(parent: Instance)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

--- Builds a text label with sensible defaults.
function Theme.label(parent: Instance, text: string, size: number, color: Color3, weight: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Font = weight or Enum.Font.GothamMedium
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.Parent = parent
	return t
end

return Theme
