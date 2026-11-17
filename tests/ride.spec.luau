-- Deterministic ride-force rules (RideDynamics). Pure numbers, no Roblox API.
local board = { turnRate = 2.4, maxSpeed = 62, grip = 0.75, accel = 10 }
local Config = require(script.Parent.Config)

-- Spring: no support when at or above rest height; support grows with compression.
assert(RideDynamics.supportAccel(0, 0) == 0, "no support at rest height")
assert(RideDynamics.supportAccel(-1, 0) == 0, "no support above rest height")
assert(RideDynamics.supportAccel(1, 0) == Config.ride.springK, "support = springK * compression")
assert(RideDynamics.supportAccel(1, 5) < RideDynamics.supportAccel(1, 0), "closing speed is damped")
assert(RideDynamics.supportAccel(0.1, 100) == 0, "support never pulls the rider down")

-- Drive: tuck pushes more than coasting at low speed; brake pulls back; cap pushes back above max.
local coast = RideDynamics.driveAccel(20, false, false, board)
local tuck = RideDynamics.driveAccel(20, true, false, board)
local brake = RideDynamics.driveAccel(20, false, true, board)
assert(tuck > coast, "tuck adds drive")
assert(brake < coast, "brake reduces drive")
assert(RideDynamics.driveAccel(70, false, false, board) < 0, "speed above max is pushed back")

-- Drag: opposes forward speed, and tuck cuts it.
assert(RideDynamics.dragAccel(30, false) < 0, "drag opposes speed")
assert(RideDynamics.dragAccel(30, true) > RideDynamics.dragAccel(30, false), "tuck cuts drag")

-- Grip: edging raises grip; grip is bounded.
assert(RideDynamics.gripRate(board, 1) > RideDynamics.gripRate(board, 0), "edge adds grip")

-- Gravity: Roblox world gravity is corrected down to the game gravity.
assert(math.abs(RideDynamics.gravityCorrection(196.2) - (196.2 - Config.physics.gravity)) < 1e-9, "gravity correction")

-- Steering: D (steer > 0) turns right, i.e. heading decreases; edge turns harder; speed matters.
local right = RideDynamics.steerHeading(0, 1, 0, 30, board, 0.5)
local left = RideDynamics.steerHeading(0, -1, 0, 30, board, 0.5)
assert(right < 0 and left > 0, "steer right (D) decreases heading, left increases it")
assert(RideDynamics.steerHeading(0, 1, 1, 30, board, 0.5) < right, "edge turns harder")
assert(math.abs(RideDynamics.steerHeading(0, 1, 0, 60, board, 0.5)) > math.abs(right), "faster turns more")
