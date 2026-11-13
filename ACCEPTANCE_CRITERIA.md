# Milestone acceptance contract

Every criterion requires actual evidence: automation log with commit hash, Rojo build result, Studio version/build tag, Play mode/time, screenshots or video and Output excerpts, observed runtime values, PASS/FAIL/BLOCKED with reproduction. A BLOCKED result cannot pass. Qwen is QA only; owner accepts milestones. All milestones: prior regression tests pass, no critical runtime errors, no decompiled code/assets incorporated, authored Studio objects persist in Edit mode, and documentation reflects truth. CI does not substitute for Play testing.

## AC1 — M1 complete vertical slice (all mandatory)
1. Boot into a visible ready/HUD state without indefinite waits or errors; PC keyboard legend and build tag visible. Ready→start→running→finished→results→replay completes in Studio Play.
2. On flat/downhill/slope changes: terrain contact remains stable; gravity accelerates downhill, momentum continues while coasting, tuck improves speed, brake measurably slows; left/right turn, edge/carve grip and lateral slip are visible and usable. No tunneling, stuck states or uncontrolled launches on the test route. Log before/after telemetry for each action.
3. Both ramp takeoffs and optional pop produce airtime. Air steer/spin/pose responds; air control weaker than ground, no free acceleration. Terrain seams do not falsely score landings.
4. Original idle, ride, tuck, left/right carve, takeoff, air, each trick pose, clean landing, sketchy/failed landing, crash and recovery poses visibly transition at the corresponding action; rider visibly leans with direction/speed. Camera maintains rider and line of travel in frame without clipping severe enough to prevent completion.
5. At least two distinct trick poses, a spin tier and a combined grab+spin produce deterministic pending score; clean banks it, sketchy reduces it, bail clears pending while preserving banked score. Combo cap and repeat rule verified; duplicate touchdown cannot pay twice. Score/time/results agree with server state.
6. Starting area, varied pitches, S-turn, two ramps, hazard/safe line, exactly two ordered gates and finish are traversable in original greybox course. Missing/out-of-order gate cannot finalize. At least one no-trick safe run and one scoring run finish.
7. Wipeout shows feedback, applies specified once-per-wipeout +3 s penalty, loses unbanked points and recovers to safe checkpoint; race timer never goes backward.
8. A legitimate completed run yields server-calculated session tokens once; insufficient funds cannot unlock; a rewarded player unlocks at least one of the sidegrade board or cosmetic, equips it, and sees equipped effect in the next ride. The other item is also obtainable through play. Session-only status conspicuous; **M1 does not promise persistence across sessions**.
9. HUD speed/timer/score/trick/combo/landing/gate/result present and responds; no final menus/art required. Server rejects client-supplied score/currency/checkpoint/finish claims, impossible and duplicate transactions under tests.
10. Existing starter tests still pass; new deterministic rule/security tests pass; `rojo build default.project.json --output build/game.rbxlx` succeeds; built-place check passes; Q01–Q12 and Q16 PASS in actual Studio Play with screenshots, Output and observable state; owner approves.

## AC2–AC10
- **AC2 (M2):** Q13 PASS in published *test* place: reward/equip survives rejoin; migration and duplicate-award/failure tests pass; offline Studio remains clearly session-only; no production data touched by QA.
- **AC3 (M3):** Q14 PASS; both new original courses have safe and trick-line clean completions; Score Jam and Time Attack rank by correct fields and reject bad gate routes; all inherited core tests pass on representative routes.
- **AC4 (M4):** Q15 PASS with recorded controller and touch hardware/emulation, core ride/trick/finish/equip complete without keyboard; remaps saved; accessible labels and camera shake preference functional.
- **AC5 (M5):** Q17 PASS: every new trick distinguishable, all legal combinations evaluated, invalid/unrealistic event spam rejected and scoring remains capped; landing/animation parity across devices.
- **AC6 (M6):** Q18 PASS: catalogue documented and unlock/equip/rejoin tested for each category, competitive stat normalization verified, no paid performance gating, achievements/challenge rewards idempotent.
- **AC7 (M7):** Q19 PASS with ≥2 concurrent Studio clients and recorded ranks, independent scores/finishes, disconnect cleanup and verified server reward.
- **AC8 (M8):** Q20 PASS in nonproduction storage: eligible records only, consistent PB and tie rule; privacy/anti-abuse review and storage-budget policy approved.
- **AC9 (M9):** Q21 PASS: all screens navigable at PC/touch resolutions, asset originality ledger complete, sound/camera/FX have accessibility controls, critical action path unbroken.
- **AC10 (M10):** Q22 and required full regression PASS on release candidate with documented device/network/profile budgets, rollback rehearsal and owner authorization; QA cannot publish.
