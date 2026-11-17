--!strict
-- DRIFTLINE shared tuning. The server owns every authoritative number; both sides read this.
-- All values are original M1 test targets (see GAME_DESIGN.md), gated by Studio Play evidence.
return {
	displayName = "DRIFTLINE",
	buildLabel = "m1.0.0",
	readyAttribute = "ServerReady",

	-- Physics (studs / seconds / radians). Pure rules live in Physics.luau.
	physics = {
		gravity = 60, -- studs/s^2, projected onto slope tangent when grounded
		tuckAccel = 14,
		brakeDecel = 30,
		dragCoef = 0.12, -- per-second speed fraction lost to drag
		tuckDragScale = 0.45,
		edgeSpeedCost = 6, -- speed lost per second while edging
		airSteerScale = 0.35, -- airborne yaw authority vs grounded
		spinRate = 3.2, -- rad/s max spin from A/D in air
		popVelocity = 22, -- studs/s upward on deliberate pop
		popCooldown = 0.8, -- seconds
		maxDelta = 1 / 30, -- bounded simulation step
	},

	-- Landing classification thresholds (impact studs/s, degrees).
	landing = {
		cleanMaxImpact = 28,
		cleanMaxAlign = 18,
		cleanMaxYaw = 25,
		bailMinImpact = 55,
		bailMinAlign = 65,
		bailMinYaw = 90,
		sketchyBankFactor = 0.5,
	},

	-- Scoring (original calibration, GAME_DESIGN.md).
	scoring = {
		comboBonus = 0.25, -- grab + spin in one air = +25%
		chainCap = 2.0, -- variety chain multiplier cap
		repeatScale = 0.5, -- each repeat of same trick in a chain halves value
	},

	-- Economy (session-only in M1; durable in M2).
	economy = {
		baseGrant = 120, -- tokens for any legitimate finish (buys one cheapest unlock)
		scoreDivisor = 20, -- +1 token per 20 banked score
		maxGrant = 300,
	},

	-- Run rules.
	run = {
		wipeoutPenalty = 3, -- seconds, once per wipeout
		gateCount = 2,
		gateRadius = 18, -- studs from gate centre that count as passing
		finishRadius = 18,
	},

	-- Validation envelopes (server authority).
	validation = {
		minAirTime = 0.3,
		maxAirTime = 5.0,
		maxSpinRateDeg = 220, -- deg/s plausible spin ceiling
		yawToleranceDeg = 45,
		maxSpeed = 90, -- studs/s hard envelope
		maxEventIdLength = 64,
	},
}
