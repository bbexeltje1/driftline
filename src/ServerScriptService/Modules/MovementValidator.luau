--!strict
-- Server-side plausibility checks for trick/landing intents. The server
-- observes the character itself (position/velocity polling in RunService)
-- and validates client intents against envelopes; it never trusts scores.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkContracts = require(ReplicatedStorage.Shared.NetworkContracts)
local Landing = require(ReplicatedStorage.Shared.Landing)

local MovementValidator = {}

-- Validate a grab intent. seenIds guards duplicate event IDs.
function MovementValidator.validateGrab(payload: any, seenIds: { [string]: boolean }): boolean
	if type(payload) ~= "table" then
		return false
	end
	if not NetworkContracts.isValidEventId(payload.eventId) then
		return false
	end
	if seenIds[payload.eventId] then
		return false
	end
	if not NetworkContracts.isValidTrickId(payload.trickId) then
		return false
	end
	if not NetworkContracts.isPlausibleAirTime(payload.airTime) then
		return false
	end
	if not NetworkContracts.isPlausibleSpeed(payload.speed) then
		return false
	end
	return true
end

-- Validate a landing intent and classify it. Returns quality or nil.
function MovementValidator.validateLanding(payload: any, seenIds: { [string]: boolean }): string?
	if type(payload) ~= "table" then
		return nil
	end
	if not NetworkContracts.isValidEventId(payload.eventId) then
		return nil
	end
	if seenIds[payload.eventId] then
		return nil
	end
	if not NetworkContracts.isPlausibleAirTime(payload.airTime) then
		return nil
	end
	if not NetworkContracts.isPlausibleYaw(payload.yawDeg, payload.airTime) then
		return nil
	end
	if not NetworkContracts.isPlausibleImpact(payload.impact) then
		return nil
	end
	if type(payload.alignDeg) ~= "number" or math.abs(payload.alignDeg) > 180 then
		return nil
	end
	return Landing.classify(payload.impact, payload.alignDeg, payload.yawDeg)
end

return MovementValidator
