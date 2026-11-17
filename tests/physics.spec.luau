-- Deterministic physics: downhill accelerates, tuck beats coast, brake slows,
-- edge costs speed, air steer is weaker than ground. Uses Physics + Config.
local board = { turnRate = 2.4, maxSpeed = 62, grip = 0.75, accel = 10 }
local function step(speed, input, pitch, dt)
	return Physics.stepGrounded({ speed = speed, heading = 0, slip = 0, edge = 0 }, input, pitch, dt, board)
end

-- Downhill (pitch ~0.25 rad) from standstill gains speed.
local downhill = step(0, { steer = 0, tuck = false, brake = false, edge = 0 }, 0.25, 1)
assert(downhill.speed > 5, "downhill accelerates from standstill, got " .. tostring(downhill.speed))

-- Flat coast decays slowly; tuck gains; brake loses fast.
local coast = step(40, { steer = 0, tuck = false, brake = false, edge = 0 }, 0, 1)
local tuck = step(40, { steer = 0, tuck = true, brake = false, edge = 0 }, 0, 1)
local brake = step(40, { steer = 0, tuck = false, brake = true, edge = 0 }, 0, 1)
assert(tuck.speed > coast.speed, "tuck beats coast")
assert(brake.speed < coast.speed, "brake slows vs coast")
assert(brake.speed < 20, "brake to under half within ~1s step, got " .. tostring(brake.speed))

-- Speed is capped at board max.
local capped = step(100, { steer = 0, tuck = true, brake = false, edge = 0 }, 0.3, 1)
assert(capped.speed <= board.maxSpeed, "speed capped")

-- Steering turns heading; edge costs speed but turns harder.
local turn = step(30, { steer = 1, tuck = false, brake = false, edge = 0 }, 0.2, 0.5)
assert(turn.heading > 0, "steer right turns heading")
local edged = step(30, { steer = 1, tuck = false, brake = false, edge = 1 }, 0.2, 0.5)
assert(edged.speed < turn.speed, "edge costs speed")
assert(edged.heading > turn.heading, "edge turns harder")

-- Air yaw is weaker than ground turn for same input/dt.
local air = Physics.stepAir({ heading = 0, spin = 0 }, { steer = 1 }, 0.5)
assert(air.heading > 0 and air.heading < turn.heading, "air steer weaker than ground")

-- Pop cooldown.
assert(Physics.popVelocity(0, 10) ~= nil, "pop available after cooldown")
assert(Physics.popVelocity(10, 10.2) == nil, "pop blocked on cooldown")

print("PASS Physics: slope/tuck/brake/edge/air/pop")
