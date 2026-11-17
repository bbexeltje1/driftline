--!strict
-- Original M1 trick definitions. Two grabs (Meteor, Sail) + spin tiers.
-- No reference names or assets; all numbers are DRIFTLINE calibration.
local TrickCatalog = {}

TrickCatalog.Grabs = {
	Meteor = { id = "Meteor", name = "Meteor", base = 100, pose = "meteor" },
	Sail = { id = "Sail", name = "Sail", base = 120, pose = "sail" },
}

-- Spin tiers by accumulated yaw (degrees). First tier reached wins.
TrickCatalog.SpinTiers = {
	{ tier = "half-spin", minYaw = 180, points = 80 },
	{ tier = "full-spin", minYaw = 360, points = 200 },
	{ tier = "double-spin", minYaw = 720, points = 400 },
}

function TrickCatalog.getGrab(id: string?): { id: string, name: string, base: number, pose: string }?
	if type(id) ~= "string" then
		return nil
	end
	return TrickCatalog.Grabs[id]
end

function TrickCatalog.isGrab(id: string?): boolean
	return TrickCatalog.getGrab(id) ~= nil
end

-- Highest spin tier earned for a yaw magnitude, or nil below half-spin.
function TrickCatalog.spinTier(yawDeg: number): { tier: string, points: number }?
	local magnitude = math.abs(yawDeg or 0)
	local best: { tier: string, points: number }? = nil
	for _, entry in ipairs(TrickCatalog.SpinTiers) do
		if magnitude >= entry.minYaw then
			best = { tier = entry.tier, points = entry.points }
		end
	end
	return best
end

return TrickCatalog
