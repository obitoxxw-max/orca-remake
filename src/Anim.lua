--!strict
-- Broly UI - Animation primitives
-- Tween + spring helpers with a global motion scale so the whole
-- interface can honour the "reduce motion" accessibility option.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Anim = {}

-- 1 = full motion, 0 = instant. Every duration in this module is scaled by it.
Anim.MotionScale = 1

export type Easing = Enum.EasingStyle

Anim.EASING = {
	standard = Enum.EasingStyle.Quint,
	enter = Enum.EasingStyle.Back,
	exit = Enum.EasingStyle.Quint,
	linear = Enum.EasingStyle.Linear,
	bounce = Enum.EasingStyle.Elastic,
}

export type SpringConfig = {
	stiffness: number?,
	damping: number?,
	restDelta: number?,
}

local DEFAULT_SPRING: SpringConfig = {
	stiffness = 190,
	damping = 26,
	restDelta = 0.001,
}

local running = {}

function Anim.setMotionScale(scale: number)
	Anim.MotionScale = math.clamp(scale, 0, 1)
end

local function scaled(duration: number): number
	return math.max(0, duration * Anim.MotionScale)
end

--- Stops any animations previously attached to this instance.
function Anim.cancel(instance: Instance)
	local set = running[instance]
	if not set then
		return
	end
	for _, entry in set do
		if entry.Cancel then
			(entry :: Tween):Cancel()
		elseif entry.Disconnect then
			(entry :: RBXScriptConnection):Disconnect()
		end
	end
	running[instance] = nil
end

--- Tweens properties on an instance. Non-motion properties (colors, transparency)
--- are tweened at full duration so the interface never looks broken when motion is reduced.
function Anim.tween(
	instance: Instance,
	goals: { [string]: any },
	duration: number?,
	easing: Easing?,
	direction: Enum.EasingDirection?
)
	local info =
		TweenInfo.new(scaled(duration or 0.25), easing or Anim.EASING.standard, direction or Enum.EasingDirection.Out)

	-- Cancel anything already running on this instance, otherwise two tweens
	-- fight over the same property and the value jitters.
	Anim.cancel(instance)

	local tween = TweenService:Create(instance, info, goals)

	local set = {}
	running[instance] = set
	table.insert(set, tween)

	tween:Play()
	tween.Completed:Once(function()
		local current = running[instance]
		if current then
			local index = table.find(current, tween)
			if index then
				table.remove(current, index)
			end
		end
	end)

	return tween
end

--- Critically damped spring step. Returns the new value and new velocity.
function Anim.stepSpring(value: number, target: number, velocity: number, dt: number, config: SpringConfig?)
	local cfg = config or DEFAULT_SPRING
	local stiffness = cfg.stiffness or DEFAULT_SPRING.stiffness
	local damping = cfg.damping or DEFAULT_SPRING.damping

	-- Clamp dt so a frame hitch cannot make the spring explode.
	local step = math.min(dt, 1 / 30)

	local displacement = value - target
	local accel = (-stiffness * displacement) - (damping * velocity)
	local newVelocity = velocity + (accel * step)
	local newValue = value + (newVelocity * step)

	return newValue, newVelocity
end

function Anim.isSettled(value: number, target: number, velocity: number, config: SpringConfig?)
	local rest = (config or DEFAULT_SPRING).restDelta or DEFAULT_SPRING.restDelta
	return math.abs(value - target) < rest and math.abs(velocity) < rest
end

--- Drives a numeric property towards a target with a spring.
--- For UDim2 properties such as Position, use Anim.moveTo instead.
function Anim.springNumber(instance: Instance, property: string, target: number, config: SpringConfig?)
	local config = config or DEFAULT_SPRING

	if typeof(target) ~= "number" then
		warn(`[Broly] Anim.springNumber wants a number for "{property}", got {typeof(target)}`)
		return
	end

	local current = (instance :: any)[property]
	if typeof(current) ~= "number" then
		warn(`[Broly] Anim.springNumber wants a numeric property, "{property}" is {typeof(current)}`)
		return
	end

	if Anim.MotionScale <= 0 then
		(instance :: any)[property] = target
		return
	end

	Anim.cancel(instance)

	local value = current
	local velocity = 0
	local rest = config.restDelta or DEFAULT_SPRING.restDelta

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local previous = value
		value, velocity = Anim.stepSpring(value, target, velocity, dt, config)

		if math.abs(value - target) < rest and math.abs(velocity) < rest then
			value = target
			velocity = 0
		end

		(instance :: any)[property] = value

		if value == target and velocity == 0 then
			connection:Disconnect()
			Anim.cancel(instance)
		elseif previous == value then
			-- Fully stalled (target equal to current), bail out safely.
			connection:Disconnect()
			Anim.cancel(instance)
		end
	end)

	local set = running[instance] or {}
	table.insert(set, connection)
	running[instance] = set
end

function Anim.fadeIn(instance: GuiObject, duration: number?)
	if Anim.MotionScale <= 0 then
		instance.GroupTransparency = 0
		return
	end
	Anim.tween(instance, { GroupTransparency = 0 }, duration or 0.22)
end

function Anim.fadeOut(instance: GuiObject, duration: number?)
	if Anim.MotionScale <= 0 then
		instance.GroupTransparency = 1
		return
	end
	Anim.tween(instance, { GroupTransparency = 1 }, duration or 0.16)
end

--- Single shared UIScale per frame. Pop and entrance must never own two scales
--- on the same frame or they fight over the transform.
local function ensureScale(frame: GuiObject): UIScale
	local scale = frame:FindFirstChild("BrolyScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "BrolyScale"
		scale.Parent = frame
	end
	return scale
end

--- Scales a frame in from 0.9 with an overshoot, then resets the scale to 1
--- so the frame keeps its layout size.
function Anim.pop(frame: Frame, duration: number?)
	local scale = ensureScale(frame)

	if Anim.MotionScale <= 0 then
		scale.Scale = 1
		return
	end

	scale.Scale = 0.94
	Anim.tween(scale, { Scale = 1 }, duration or 0.32, Anim.EASING.enter)
end

--- Layout-safe entrance: fade plus a subtle scale pop.
--- Deliberately avoids touching Position, because anything parented to a
--- UIListLayout has its Position rewritten on every layout pass.
function Anim.entrance(frame: GuiObject, delay: number?, duration: number?)
	if Anim.MotionScale <= 0 then
		frame.GroupTransparency = 0
		ensureScale(frame).Scale = 1
		return
	end

	frame.GroupTransparency = 1

	local scale = ensureScale(frame)
	scale.Scale = 0.97

	local tween = Anim.tween(frame, { GroupTransparency = 0 }, duration or 0.32)
	Anim.tween(scale, { Scale = 1 }, duration or 0.34, Anim.EASING.enter)

	if delay and delay > 0 then
		tween:Pause()
		task.delay(scaled(delay), function()
			if tween.PlaybackState == Enum.PlaybackState.Completed then
				return
			end
			if frame.Parent then
				tween:Play()
			else
				tween:Cancel()
			end
		end)
	end
end

--- Staggered entrance for the children of a UIListLayout container.
function Anim.stagger(container: GuiObject, gap: number?)
	local step = scaled(gap or 0.045)
	local index = 0
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			index += 1
			Anim.entrance(child :: GuiObject, (index - 1) * step)
		end
	end
end

--- Smoothly animates a UDim2 position, keeping the layout untouched afterwards.
function Anim.moveTo(frame: Frame, target: UDim2, config: SpringConfig?)
	if Anim.MotionScale <= 0 then
		frame.Position = target
		return
	end

	local config = config or { stiffness = 260, damping = 28, restDelta = 0.4 }
	local position = frame.Position
	local velocity = Vector2.zero

	local function step(dt: number): (Vector2, Vector2)
		local step2 = math.min(dt, 1 / 30)
		local rest = config.restDelta or 0.4

		local x, vx = Anim.stepSpring(position.X.Offset, target.X.Offset, velocity.X, step2, config)
		local y, vy = Anim.stepSpring(position.Y.Offset, target.Y.Offset, velocity.Y, step2, config)

		-- Interpolate scale channels directly; they rarely change.
		local newPos = UDim2.new(target.X.Scale, x, target.Y.Scale, y)
		local newVel = Vector2.new(vx, vy)

		if
			math.abs(x - target.X.Offset) < rest
			and math.abs(y - target.Y.Offset) < rest
			and math.abs(vx) < rest
			and math.abs(vy) < rest
		then
			newPos = target
			newVel = Vector2.zero
		end

		return newPos, newVel
	end

	Anim.cancel(frame)
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local settledBefore = velocity == Vector2.zero
			and position.X.Offset == target.X.Offset
			and position.Y.Offset == target.Y.Offset

		position, velocity = step(dt)
		frame.Position = position

		if settledBefore or (position == target and velocity == Vector2.zero) then
			connection:Disconnect()
			Anim.cancel(frame)
		end
	end)

	local set = running[frame] or {}
	table.insert(set, connection)
	running[frame] = set
end

return Anim
