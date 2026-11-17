-- Trick scoring: grab+spin combo, chain cap, repeat diminishing, bank/bail.
local scorer = TrickScorer.new()
assert(TrickScorer.addGrab(scorer, "Meteor") == 100, "Meteor base 100")
assert(TrickScorer.addGrab(scorer, "Sail") == nil, "one grab per air")
assert(TrickScorer.addSpin(scorer, 360) == 200, "full-spin 200")
-- Combo +25%: (100+200)*1.25 = 375.
assert(TrickScorer.computePending(scorer) == 375, "combo pending 375, got " .. tostring(TrickScorer.computePending(scorer)))
local banked = TrickScorer.land(scorer, "clean")
assert(banked == 375, "clean banks full pending")
assert(scorer.banked == 375, "banked accumulates")
assert(TrickScorer.computePending(scorer) == 0, "pending cleared after landing (one bank per landing)")

-- Sketchy banks half.
local s2 = TrickScorer.new()
TrickScorer.addGrab(s2, "Sail")
assert(TrickScorer.land(s2, "sketchy") == 60, "sketchy banks half of 120")

-- Bail discards pending, keeps banked.
local s3 = TrickScorer.new()
TrickScorer.addGrab(s3, "Meteor")
TrickScorer.land(s3, "clean")
assert(s3.banked == 100, "banked before bail")
TrickScorer.addGrab(s3, "Sail")
TrickScorer.bail(s3)
assert(s3.banked == 100, "bail keeps banked")
assert(TrickScorer.computePending(s3) == 0, "bail clears pending")

-- Repeat diminishing: second Meteor in chain is half.
local s4 = TrickScorer.new()
TrickScorer.addGrab(s4, "Meteor")
TrickScorer.land(s4, "clean")
local second = TrickScorer.addGrab(s4, "Meteor")
assert(second == 50, "repeat diminished to 50, got " .. tostring(second))

-- Spin tiers.
assert(TrickCatalog.spinTier(100) == nil, "below half-spin = no tier")
assert(TrickCatalog.spinTier(180).points == 80, "half-spin 80")
assert(TrickCatalog.spinTier(720).points == 400, "double-spin 400")
assert(TrickCatalog.isGrab("Meteor") and TrickCatalog.isGrab("Sail"), "two grabs exist")
assert(not TrickCatalog.isGrab("Nope"), "unknown trick rejected")

print("PASS Tricks: combo/chain/repeat/bank/bail")
