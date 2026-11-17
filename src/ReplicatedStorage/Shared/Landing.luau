--!strict
-- Landing evaluation: clean / sketchy / bail from impact + alignment + yaw error.
-- Pure function; thresholds live in Config.landing.
local Config = require(script.Parent.Config)

local Landing = {}

-- impactSpeed: studs/s downward at touchdown. alignErrorDeg: board vs travel
-- direction. yawErrorDeg: residual spin/yaw mismatch at touchdown.
function Landing.classify(impactSpeed: number, alignErrorDeg: number, yawErrorDeg: number): string
	local t = Config.landing
	local impact = math.abs(impactSpeed or 0)
	local align = math.abs(alignErrorDeg or 0)
	local yaw = math.abs(yawErrorDeg or 0)

	if impact >= t.bailMinImpact or align >= t.bailMinAlign or yaw >= t.bailMinYaw then
		return "bail"
	end
	if impact <= t.cleanMaxImpact and align <= t.cleanMaxAlign and yaw <= t.cleanMaxYaw then
		return "clean"
	end
	return "sketchy"
end

function Landing.bankFactor(quality: string): number
	if quality == "clean" then
		return 1
	elseif quality == "sketchy" then
		return Config.landing.sketchyBankFactor
	end
	return 0
end

return Landing
