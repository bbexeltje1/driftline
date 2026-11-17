--!strict
-- Session-only profiles. No DataStore at module load (template rule 2);
-- Studio runs use temporary in-memory progress labelled as such.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Shared.Profile)

local ProfileService = {}

local profiles: { [number]: any } = {}

function ProfileService.get(userId: number): any
	local existing = profiles[userId]
	if existing then
		return existing
	end
	local created = Profile.new(userId)
	profiles[userId] = created
	return created
end

function ProfileService.clear(userId: number)
	profiles[userId] = nil
end

return ProfileService
