--!strict
-- Remote names + server-side plausibility checks. The client never submits
-- score, tokens, checkpoints or finish claims; it submits intents with event
-- IDs and the server validates order, airtime, yaw and speed envelopes.
local Config = require(script.Parent.Config)
local TrickCatalog = require(script.Parent.TrickCatalog)
local BoardCatalog = require(script.Parent.BoardCatalog)

local NetworkContracts = {}

NetworkContracts.Remotes = {
	Ready = "Ready",
	StartRun = "StartRun",
	TrickEvent = "TrickEvent",
	LandEvent = "LandEvent",
	WipeoutEvent = "WipeoutEvent",
	UnlockItem = "UnlockItem",
	EquipItem = "EquipItem",
	RunUpdate = "RunUpdate",
	ProfileUpdate = "ProfileUpdate",
	Results = "Results",
}

function NetworkContracts.isValidEventId(id: any): boolean
	return type(id) == "string" and #id > 0 and #id <= Config.validation.maxEventIdLength
end

function NetworkContracts.isValidTrickId(id: any): boolean
	return TrickCatalog.isGrab(id)
end

function NetworkContracts.isValidItemId(id: any): boolean
	return BoardCatalog.getItem(id) ~= nil
end

function NetworkContracts.isPlausibleAirTime(airTime: any): boolean
	return type(airTime) == "number" and airTime >= Config.validation.minAirTime and airTime <= Config.validation.maxAirTime
end

function NetworkContracts.isPlausibleYaw(yawDeg: any, airTime: any): boolean
	if type(yawDeg) ~= "number" or type(airTime) ~= "number" then
		return false
	end
	local ceiling = Config.validation.maxSpinRateDeg * math.max(0, airTime) + Config.validation.yawToleranceDeg
	return math.abs(yawDeg) <= ceiling
end

function NetworkContracts.isPlausibleSpeed(speed: any): boolean
	return type(speed) == "number" and speed >= 0 and speed <= Config.validation.maxSpeed
end

function NetworkContracts.isPlausibleImpact(impact: any): boolean
	return type(impact) == "number" and impact >= 0 and impact <= Config.validation.maxSpeed * 2
end

return NetworkContracts
