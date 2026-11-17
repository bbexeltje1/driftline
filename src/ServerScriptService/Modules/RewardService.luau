--!strict
-- Token grants: server-calculated, once per unique completed run ID.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Shared.Profile)

local RewardService = {}

-- Returns granted tokens (0 when already granted or invalid).
function RewardService.grantForFinish(profile: any, runId: string, bankedScore: number, elapsed: number): number
	return Profile.grantForRun(profile, runId, bankedScore, elapsed)
end

return RewardService
