--!strict
-- Pure ride-force rules for the physics-driven board. No Roblox API: the client converts
-- these scalar accelerations into a VectorForce each frame, so the rules stay testable.
local Config = require(script.Parent.Config)

local RideDynamics = {}

local function clamp(value: number, lo: number, hi: number): number
	if value < lo then
		return lo
	elseif value > hi then
		return hi
	end
	return value
end

-- Spring support along the ground normal. compression: studs the rider sits below rest
-- height. closingSpeed: velocity toward the ground (positive = falling onto it).
-- Returns an accel >= 0; damping stops the spring from bouncing.
function RideDynamics.supportAccel(compression: number, closingSpeed: number): number
	local ride = Config.ride
	if compression <= 0 then
		return 0
	end
	return math.max(0, ride.springK * compression - ride.springDamp * closingSpeed)
end

-- Forward accel along the slope. Base push, tuck boost that fades near top speed,
-- brake when moving, and a hard cap above board.maxSpeed.
function RideDynamics.driveAccel(speed: number, tuck: boolean, brake: boolean, board: { maxSpeed: number, accel: number }): number
	local cfg = Config.physics
	local accel = board.accel * 0.15
	if tuck then
		accel += cfg.tuckAccel * (1 - clamp(speed / board.maxSpeed, 0, 1))
	end
	if brake and speed > 0.5 then
		accel -= cfg.brakeDecel
	end
	if speed > board.maxSpeed then
		accel -= (speed - board.maxSpeed) * 8
	end
	return accel
end

-- Drag opposes forward speed; tuck cuts it.
function RideDynamics.dragAccel(speed: number, tuck: boolean): number
	local scale = if tuck then Config.physics.tuckDragScale else 1
	return -Config.physics.dragCoef * scale * speed
end

-- Lateral velocity is removed at this rate; edging adds grip.
function RideDynamics.gripRate(board: { grip: number }, edge: number): number
	return Config.ride.gripRate * clamp(board.grip + 0.25 * math.abs(edge), 0, 1)
end

-- Vertical accel that makes Roblox's world gravity behave as the game's gravity.
function RideDynamics.gravityCorrection(worldGravity: number): number
	return worldGravity - Config.physics.gravity
end

-- Heading convention: forward = (-sin h, 0, -cos h), i.e. CFrame.Angles(0, h, 0).LookVector.
-- Increasing h turns left, so steer > 0 (D, right) decreases heading.
function RideDynamics.steerHeading(heading: number, steer: number, edge: number, speed: number, board: { turnRate: number, maxSpeed: number }, dt: number): number
	local speedFactor = clamp(speed / math.max(1, board.maxSpeed), 0, 1)
	local authority = board.turnRate * (0.45 + 0.55 * speedFactor) * (1 + 0.35 * math.abs(edge))
	return heading - clamp(steer, -1, 1) * authority * dt
end

return RideDynamics
