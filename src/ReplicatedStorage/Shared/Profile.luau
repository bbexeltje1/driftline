--!strict
-- Session-only player profile (M1). No DataStore: progress lives in server
-- memory for this session and is labelled temporary. Durable saving is M2.
-- Pure table logic so unlock/equip/grant-once are unit-testable.
local BoardCatalog = require(script.Parent.BoardCatalog)
local RunRules = require(script.Parent.RunRules)

local Profile = {}

export type SessionProfile = {
	userId: number,
	tokens: number,
	owned: { [string]: boolean },
	equippedBoard: string,
	equippedCosmetic: string?,
	completedRuns: { [string]: boolean },
}

function Profile.new(userId: number): SessionProfile
	return {
		userId = userId,
		tokens = 0,
		owned = { Trailboard = true },
		equippedBoard = "Trailboard",
		equippedCosmetic = nil,
		completedRuns = {},
	}
end

-- Grant tokens once per unique completed run ID. Returns granted amount or 0.
function Profile.grantForRun(profile: SessionProfile, runId: string, bankedScore: number, elapsed: number): number
	if type(runId) ~= "string" or #runId == 0 then
		return 0
	end
	if profile.completedRuns[runId] then
		return 0
	end
	local amount = RunRules.tokenGrant(bankedScore, elapsed)
	profile.completedRuns[runId] = true
	profile.tokens += amount
	return amount
end

function Profile.canAfford(profile: SessionProfile, cost: number): boolean
	return profile.tokens >= cost
end

-- Idempotent purchase: owned or insufficient funds or unknown item -> false.
function Profile.unlock(profile: SessionProfile, itemId: string?): boolean
	local item = BoardCatalog.getItem(itemId)
	if not item then
		return false
	end
	if profile.owned[itemId] then
		return false
	end
	if profile.tokens < item.cost then
		return false
	end
	profile.tokens -= item.cost
	profile.owned[itemId] = true
	return true
end

-- Equip an owned item into its slot. Returns true on success.
function Profile.equip(profile: SessionProfile, slot: string?, itemId: string?): boolean
	if type(itemId) ~= "string" or not profile.owned[itemId] then
		return false
	end
	if slot == "board" and BoardCatalog.isBoard(itemId) then
		profile.equippedBoard = itemId
		return true
	elseif slot == "cosmetic" and BoardCatalog.isCosmetic(itemId) then
		profile.equippedCosmetic = itemId
		return true
	end
	return false
end

function Profile.boardStats(profile: SessionProfile): { turnRate: number, maxSpeed: number, grip: number, accel: number }
	local board = BoardCatalog.getBoard(profile.equippedBoard) or BoardCatalog.Boards.Trailboard
	return { turnRate = board.turnRate, maxSpeed = board.maxSpeed, grip = board.grip, accel = board.accel }
end

return Profile
