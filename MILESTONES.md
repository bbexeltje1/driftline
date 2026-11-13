# Milestone specifications — DRIFTLINE

**Planning only.** All milestones unstarted. Owner approval is required before implementation. M1 requires a real Studio Play test, not just passing scripted tests. Each numbered step is independently reviewable; Arena owns implementation, Qwen tests only. Every milestone also inherits regression of earlier acceptance tests and `npm test` + Rojo build; progression beyond M1 requires the prior milestone accepted or explicit owner waiver. Test IDs resolve in `QA_TEST_CASES.md`. Acceptance gates resolve in `ACCEPTANCE_CRITERIA.md`.

## M1 — Full mechanical vertical slice
- **Objective:** complete original greybox ride → tricks → finish → reward → unlock → equip → replay on PC keyboard.
- **Gameplay:** stable downhill gravity/momentum/coast/tuck/brake/carve/edge/slope/contact; ramps/pop/air yaw and poses; two grabs + spin combinations, pending/banked score, clean/sketchy/bail, crash/recover/time penalty; original greybox Switchback Basin with start, pitches, turns, two ramps, obstacle, two ordered gates, finish and safe line; functional idle/ride/tuck/carve left/right/takeoff/air/trick/landing/failed landing/crash/recovery pose transitions; follow camera; minimal HUD and results; base board, one stat sidegrade and one cosmetic with server-validated token unlock/equip (session only).
- **Technical:** extend template without removing four rules; shared tunables/contracts, client input/prediction/camera/animation/HUD, server run/course/checkpoint/score/economy validator, distinct run/rider state machines, bounded remote requests, duplicate protection; Studio Edit-mode course objects are authoritative (Arena creates them as approved implementation work; Qwen never edits). No gameplay runtime recreation of Studio course/layout; if Rojo cannot represent geometry, Arena supplies a Studio-edit plan and serialized Studio-owned place workflow before coding. Avoid assuming standalone `.rbxlx` auto-includes Studio-only course: define versioned course artifact and validate sync.
- **Dependencies:** owner approval on design, repository remote/branch, PC key mapping, Studio course-asset workflow; template audit done, no M1 code yet.
- **Steps:** 1) audit branch and record baseline; 2) define run/trick/profile schemas and deterministic unit tests; 3) choose & measure stable controller in Studio with placeholder contact geometry; 4) wire grounded/airborne/landing/crash physics and validated run start; 5) add original pose graph/camera and inspect input-to-pose timing; 6) author original Studio greybox + gates/finish and version its artifact; 7) add trick scoring and results, server checks and HUD; 8) add session tokens, unlock/equip/replay; 9) run regression, Rojo build and multi-run Studio QA; 10) commit/push only once authorized.
- **Automated:** deterministic force/slope/turn limits and landing classification; score combo/penalty/repeat; gate order/finish once; malformed/duplicate remote and insufficient funds; equip/sidegrade lookup; existing template tests/place check; Rojo build.
- **Studio QA:** Q01–Q12, Q16; keyboard and single-player runs with screenshots, Output and state evidence.
- **Expected:** ride entire course with animation tracking motion; valid finish banks score, grants exactly one reward; unlock and equip work on replay; crash loses pending score, not already banked; no errors/infinite yields.
- **Acceptance:** AC1 and M1 gates in `ACCEPTANCE_CRITERIA.md` all pass in real Studio Play; BLOCKED is not PASS.
- **Done:** source and Studio artifact reproducible, tests/build pass, Qwen evidence PASS, owner accepts; no visual polish requirement.
- **Risks/questions:** Studio Edit-mode source-of-truth vs Rojo-built place, network ownership/latency, controller stability, session-only rewards, exact input mapping; log owner decisions before starting.

## M2 — Reliable profiles and economy
- **Objective:** make earned progress durable without breaking offline Studio play.
- **Gameplay:** persistent inventory/equip, XP/levels and basic achievements; results identify saved/pending/temporary state.
- **Technical:** versioned profile, migrations, DataStore adapter with retry/backoff, session lock or conflict strategy, idempotent run grants and transaction journal, Studio session fallback; published test place only for real persistence QA.
- **Dependencies:** M1 accepted; owner provides safe published test experience/API permissions.
- **Steps:** 1) schema/migration tests; 2) persistence adapter; 3) transactional rewards and duplicate guard; 4) autosave/shutdown/error UX; 5) test across rejoin and failure paths.
- **Automated:** round-trip migrations, duplicate grants, invalid data normalization, unavailable/throttled store fallback.
- **Studio QA:** Q13 plus Q11/Q12 regressions in published test place and offline Studio.
- **Expected:** legitimate reward survives rejoin, duplicates never double-credit, offline clearly temporary.
- **Acceptance:** AC2 plus inherited gates; no false persistence claims.
- **Done:** safe data path, documented rollback and QA evidence; owner signs off.
- **Risks/questions:** publish/API access and data budget; do not enable production writes for tests.

## M3 — Course and challenge expansion
- **Objective:** demonstrate replayable line choice and event-specific goals.
- **Gameplay:** Frostline Ridge + Beacon Quarry originals; Score Jam and Time Attack; optional route challenges and difficulty targets.
- **Technical:** Studio-authored course manifest/gate validation, mode rules, split records, challenge progress, per-course budgets.
- **Dependencies:** M2 accepted; original course asset workflow established.
- **Steps:** 1) author two greyboxes; 2) gate/route manifests; 3) mode start/finish and rewards; 4) challenge verification; 5) balance runs.
- **Automated:** wrong-course/wrong-order reject, mode score/time separation, reward caps, challenge idempotency.
- **Studio QA:** Q14, Q16 and Q01–Q12 regressions on each course.
- **Expected:** all routes finish, different modes produce distinct validated results; no impossible gates.
- **Acceptance:** AC3; measured course traversal and challenge pass on safe/trick lines.
- **Done:** course QA evidence and owner-approved event balance.
- **Risks/questions:** difficulty tuning and terrain contact seams; final course names can change.

## M4 — Cross-device control and accessibility
- **Objective:** deliver equivalent fundamentals on controller and touch.
- **Gameplay:** remappable bindings, hold/toggle edge option, readable touch gestures/buttons, camera shake toggle and accessible labels.
- **Technical:** device-agnostic intent mapping, input priority/state transitions, responsive mobile HUD safe areas, device-specific animation parity.
- **Dependencies:** M3 accepted; owner approves device matrix/hardware access.
- **Steps:** 1) map controller/touch intents; 2) build touch UI in Studio-owned visual layout; 3) remap/preferences; 4) compare physics/trick reachability; 5) device QA.
- **Automated:** mapping parity, conflicting inputs, press/release lifecycle, saved preference validation.
- **Studio QA:** Q15 on real/emulated devices plus Q01–Q12 critical path.
- **Expected:** brake/carve/pop/grab/spin/finish/equip reachable without keyboard.
- **Acceptance:** AC4; no device marked supported without recorded Play evidence.
- **Done:** owner signs off control usability and device coverage.
- **Risks/questions:** multitouch simultaneity and available QA devices.

## M5 — Deep tricks and tuning
- **Objective:** expand expressive combinations without scoring exploits.
- **Gameplay:** more original grabs/rotation tiers, variety objectives, landing tuning, style pose variants and meaningful risk choices.
- **Technical:** versioned trick definitions, server plausibility bounds, telemetry for speed/airtime/bails, data-driven animation hooks.
- **Dependencies:** M4 accepted, stable M1 scoring.
- **Steps:** 1) define legal trick grammar; 2) add poses and blends; 3) scoring/risk tuning; 4) score validation stress tests; 5) playtest.
- **Automated:** combo permutations, repeat reduction, impossible event rejection, threshold edges.
- **Studio QA:** Q17 and Q05–Q08 regressions across device mappings.
- **Expected:** expanded tricks are distinguishable and fair; bails cannot bank pending score.
- **Acceptance:** AC5 and no inflation exploit in test corpus.
- **Done:** balanced rules, clips and evidence approved.
- **Risks/questions:** animation workload; avoid increasing mechanical complexity faster than controls support.

## M6 — Full progression and customization
- **Objective:** supply long-term skill-based goals and the catalogue from `GAME_DESIGN.md`.
- **Gameplay:** additional sidegrade boards, original riders/outfits/decks/trails/titles, course/event unlocks, achievements, XP and optional recurring challenges.
- **Technical:** validated catalog ownership/equip, server-time challenge schedules, inventory migrations, normalized competitive stats.
- **Dependencies:** M5 accepted; M2 profile stability.
- **Steps:** 1) catalogue/economy balancing; 2) unlock predicates; 3) equip slots; 4) original asset integration; 5) abuse and rejoin QA.
- **Automated:** slot/ownership checks, migration and grant idempotency, normalized stats, expiry boundaries.
- **Studio QA:** Q18, Q13, Q12 regressions.
- **Expected:** every unlock has documented path/effect and honest equip state.
- **Acceptance:** AC6; no pay-for-stat advantages and no unintended stacking.
- **Done:** full catalogue and economy signed off.
- **Risks/questions:** content production scale and whether rotating challenges are worth live ops.

## M7 — Multiplayer heats and ghosts
- **Objective:** let friends compete fairly while preserving solo responsiveness.
- **Gameplay:** synchronized heats, finishes/rank, shared courses and optional validated ghost playback; solo remains available.
- **Technical:** server start clock and run IDs, per-player validation, interpolation/network ownership, disconnect and late-join policy, ghost retention limits.
- **Dependencies:** M6 accepted; stable server run service and balanced stats.
- **Steps:** 1) heat lifecycle; 2) spawn/isolation and networking; 3) ranking; 4) ghost snapshots; 5) concurrent QA.
- **Automated:** ordering/ties, disconnected player cleanup, double-finish, ghost payload validation.
- **Studio QA:** Q19 plus core run regression in 2+ client simulation.
- **Expected:** two riders finish independently; ranks and rewards cannot be forged.
- **Acceptance:** AC7; concurrent Studio evidence.
- **Done:** owner approves latency/fairness results.
- **Risks/questions:** network physics ownership and ghost storage cost.

## M8 — Competitive records and social
- **Objective:** durable records and fair asynchronous competition.
- **Gameplay:** per-course/mode boards, personal best, seasonal or all-time filter (if approved), friend challenge sharing.
- **Technical:** server-validated record writes, sorted storage budgets, moderation/privacy, anti-abuse audit, reset policy.
- **Dependencies:** M7 accepted and trustworthy score validation.
- **Steps:** 1) board eligibility; 2) record stores; 3) UX; 4) exploit simulation; 5) audit tools.
- **Automated:** best-record compare, tie policy, invalid run exclusion, budget/backoff.
- **Studio QA:** Q20 plus Q13/Q19 regressions on safe test stores.
- **Expected:** only eligible completed runs appear; personal best matches server results.
- **Acceptance:** AC8; privacy and abuse review approved.
- **Done:** documented reset/recovery process and QA evidence.
- **Risks/questions:** leaderboard moderation and season cadence.

## M9 — Presentation, animation and sound polish
- **Objective:** original cohesive identity without obscuring mechanics.
- **Gameplay:** full menu, rider/board/inventory/challenges/results/records UI; polished original animation, feedback, camera and audio cues; final original course art passes.
- **Technical:** UI state ownership separated from server, asset attribution ledger, scalable layouts, accessibility/performance toggles, Studio-owned visual objects.
- **Dependencies:** M8 accepted; all mechanical screens stable.
- **Steps:** 1) UI wireframes; 2) Studio-authored layouts; 3) animation/audio passes; 4) feedback usability; 5) accessibility regression.
- **Automated:** state navigation and missing-asset fallback, no gameplay-rule drift.
- **Studio QA:** Q21 and Q01–Q20 selective regressions.
- **Expected:** visually distinctive, readable at PC/mobile resolution, full action flow intact.
- **Acceptance:** AC9; asset originality documented, no UI-blocked runs.
- **Done:** owner signs off branding and usability.
- **Risks/questions:** asset licensing and low-end device effects budgets.

## M10 — Optimization and release readiness
- **Objective:** ship a stable, measurable, recoverable Roblox release.
- **Gameplay:** final balance, onboarding, fail-safe respawn and polished end-to-end replay.
- **Technical:** profiling, network/data budgets, security sweep, migration/rollback, error logging, release checklist, production/private test separation.
- **Dependencies:** M9 accepted; platform policy/privacy review.
- **Steps:** 1) regression matrix; 2) low-end profiling and optimize; 3) persistence/load testing; 4) security/privacy; 5) release candidate + rollback rehearsal.
- **Automated:** all suites, build/place check, schema migration, abuse and stress tests.
- **Studio QA:** Q22 plus Q01–Q21 relevant device/mode matrix in release candidate.
- **Expected:** no critical errors, stable budgets and clear recovery from failures.
- **Acceptance:** AC10, owner release authorization; Qwen never publishes.
- **Done:** signed release checklist; Arena publishes only on explicit separate authorization.
- **Risks/questions:** Roblox device performance, compliance, operational ownership.
