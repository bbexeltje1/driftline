--!strict
-- Run lifecycle rules: ordered gates, finish eligibility, token grant, penalty.
-- Pure tables; the server RunService owns live instances of these.
local Config = require(script.Parent.Config)

local RunRules = {}

export type Run = {
	runId: string,
	gatesPassed: { [number]: boolean },
	finished: boolean,
	penalty: number,
	granted: boolean,
}

function RunRules.newRun(runId: string): Run
	return { runId = runId, gatesPassed = {}, finished = false, penalty = 0, granted = false }
end

function RunRules.nextGate(run: Run): number?
	for index = 1, Config.run.gateCount do
		if not run.gatesPassed[index] then
			return index
		end
	end
	return nil
end

-- Pass the next ordered gate. Returns true only for the expected gate, once.
function RunRules.passGate(run: Run, gateIndex: number): boolean
	if run.finished then
		return false
	end
	if gateIndex ~= RunRules.nextGate(run) then
		return false
	end
	run.gatesPassed[gateIndex] = true
	return true
end

function RunRules.canFinish(run: Run): boolean
	if run.finished then
		return false
	end
	return RunRules.nextGate(run) == nil
end

-- Token grant for a legitimate finish. Bounded; first finish buys one unlock.
function RunRules.tokenGrant(bankedScore: number, _elapsed: number): number
	local grant = Config.economy.baseGrant + math.floor(math.max(0, bankedScore) / Config.economy.scoreDivisor)
	return math.min(grant, Config.economy.maxGrant)
end

-- Wipeout: +3s once per wipeout. Timer never goes backward (penalty only grows).
function RunRules.applyWipeoutPenalty(run: Run): number
	run.penalty += Config.run.wipeoutPenalty
	return run.penalty
end

function RunRules.elapsedWithPenalty(baseElapsed: number, penalty: number): number
	return math.max(0, baseElapsed) + math.max(0, penalty)
end

return RunRules
