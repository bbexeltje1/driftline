--!strict
-- Pending/banked trick scoring. One grab + spin per air forms a combination;
-- clean banks full, sketchy banks reduced, bail discards pending (banked kept).
-- Variety chain multiplies, capped; repeats in a chain diminish. Pure tables.
local Config = require(script.Parent.Config)
local TrickCatalog = require(script.Parent.TrickCatalog)
local Landing = require(script.Parent.Landing)

local TrickScorer = {}

export type Scorer = {
	pending: number,
	banked: number,
	chainCount: number,
	seenInChain: { [string]: number },
	hasGrab: boolean,
	hasSpin: boolean,
}

function TrickScorer.new(): Scorer
	return { pending = 0, banked = 0, chainCount = 0, seenInChain = {}, hasGrab = false, hasSpin = false }
end

-- Record a grab in the current air. Returns awarded points or nil if invalid.
function TrickScorer.addGrab(scorer: Scorer, trickId: string?): number?
	local grab = TrickCatalog.getGrab(trickId)
	if not grab then
		return nil
	end
	if scorer.hasGrab then
		return nil -- one grab per air
	end
	local repeats = scorer.seenInChain[trickId] or 0
	local scale = 1
	for _ = 1, repeats do
		scale *= Config.scoring.repeatScale
	end
	local points = math.floor(grab.base * scale)
	scorer.pending += points
	scorer.seenInChain[trickId] = repeats + 1
	scorer.hasGrab = true
	return points
end

-- Record accumulated spin yaw for the current air. Returns points or nil.
function TrickScorer.addSpin(scorer: Scorer, yawDeg: number): number?
	if scorer.hasSpin then
		return nil -- one spin evaluation per air
	end
	local tier = TrickCatalog.spinTier(yawDeg)
	if not tier then
		return nil
	end
	scorer.pending += tier.points
	scorer.hasSpin = true
	return tier.points
end

-- Pending total with combination bonus and capped chain multiplier.
function TrickScorer.computePending(scorer: Scorer): number
	if scorer.pending <= 0 then
		return 0
	end
	local total = scorer.pending
	if scorer.hasGrab and scorer.hasSpin then
		total *= 1 + Config.scoring.comboBonus
	end
	local chain = 1 + 0.25 * math.max(0, scorer.chainCount - 1)
	chain = math.min(chain, Config.scoring.chainCap)
	return math.floor(total * chain)
end

-- End the current air. Clean/sketchy banks (sketchy reduced); bail discards.
-- Returns banked amount. Always resets per-air state (one bank per landing).
function TrickScorer.land(scorer: Scorer, quality: string): number
	local pending = TrickScorer.computePending(scorer)
	local factor = Landing.bankFactor(quality)
	local amount = math.floor(pending * factor)
	scorer.banked += amount
	if amount > 0 then
		scorer.chainCount += 1
	else
		scorer.chainCount = 0
	end
	scorer.pending = 0
	scorer.hasGrab = false
	scorer.hasSpin = false
	return amount
end

-- Bail/wipeout: pending lost, banked preserved, chain reset.
function TrickScorer.bail(scorer: Scorer)
	scorer.pending = 0
	scorer.hasGrab = false
	scorer.hasSpin = false
	scorer.chainCount = 0
end

return TrickScorer
