--!strict
-- Pure grounded/airborne motion rules. No Roblox API: plain tables/numbers only,
-- so Node/Luau tests can drive them deterministically. Client predicts with these;
-- the server validates envelopes (NetworkContracts) and never trusts client score.
local Config = require(script.Parent.Config)

local Physics = {}

export type GroundedState = {
	speed: number,
	heading: number,
	slip: number,
	edge: number,
}

export type GroundedInput = {
	steer: number, -- -1..1 (A/D)
	tuck: boolean, -- W
	brake: boolean, -- S
	edge: number, -- -1..1 (Q/E hold)
}

export type BoardStats = {
	turnRate: number,
	maxSpeed: number,
	grip: number, -- 0..1
	accel: number,
}

local function clamp(value: number, lo: number, hi: number): number
	if value < lo then
		return lo
	elseif value > hi then
		return hi
	end
	return value
end

-- One grounded step. slopePitch: radians, positive when the terrain falls away
-- along the current heading (downhill). Returns a fresh state table.
function Physics.stepGrounded(state: GroundedState, input: GroundedInput, slopePitch: number, dt: number, board: BoardStats): GroundedState
	local cfg = Config.physics
	local steer = clamp(input.steer or 0, -1, 1)
	local edge = clamp(input.edge or 0, -1, 1)
	local speed = math.max(0, state.speed or 0)

	-- Downhill gravity projected onto the tangent.
	local gravityAccel = cfg.gravity * math.sin(slopePitch)
	local accel = gravityAccel + board.accel * 0.15
	if input.tuck then
		accel += cfg.tuckAccel
	end
	if input.brake then
		accel -= cfg.brakeDecel
	end

	-- Drag (tuck cuts it) and edge scrub.
	local dragScale = if input.tuck then cfg.tuckDragScale else 1
	speed -= speed * cfg.dragCoef * dragScale * dt
	if edge ~= 0 then
		speed -= cfg.edgeSpeedCost * math.abs(edge) * dt
	end
	speed += accel * dt
	speed = clamp(speed, 0, board.maxSpeed)

	-- Speed-sensitive steering: more authority with speed, capped so low-speed
	-- pivots stay controllable. Edge adds grip/turn authority at speed cost.
	local speedFactor = clamp(speed / math.max(1, board.maxSpeed), 0, 1)
	local turnAuthority = board.turnRate * (0.45 + 0.55 * speedFactor)
	turnAuthority *= 1 + 0.35 * math.abs(edge)
	local heading = (state.heading or 0) + steer * turnAuthority * dt

	-- Lateral slip: bounded, reduced by grip and by edging.
	local grip = clamp(board.grip + 0.25 * math.abs(edge), 0, 1)
	local slip = clamp(steer * speed * (1 - grip) * 0.08, -8, 8)

	return { speed = speed, heading = heading, slip = slip, edge = edge }
end

-- One airborne step: ballistic momentum is kept by the caller; this only
-- advances yaw/spin with weaker authority. No free speed gain in air.
function Physics.stepAir(state: { heading: number, spin: number }, input: { steer: number }, dt: number): { heading: number, spin: number }
	local cfg = Config.physics
	local steer = clamp(input.steer or 0, -1, 1)
	local yawRate = cfg.spinRate * cfg.airSteerScale
	local spin = (state.spin or 0) + steer * yawRate * dt
	local heading = (state.heading or 0) + steer * yawRate * dt
	return { heading = heading, spin = spin }
end

-- Deliberate pop: returns the upward velocity, or nil while on cooldown.
function Physics.popVelocity(lastPopAt: number, now: number): number?
	if now - lastPopAt < Config.physics.popCooldown then
		return nil
	end
	return Config.physics.popVelocity
end

return Physics
