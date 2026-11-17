# DRIFTLINE M1 — Implementation Status (evidence log)

Branch: `arena/373194be-driftline`. Build label `m1.0.0`.

## Automated (verified in sandbox)
- `npm test`: PASS — Luau syntax (23 files), Config, Physics, Landing, Tricks, RunRules, Profile, Contracts specs, client boot vs strict stub (HUD-first, build tag, bounded Remotes wait), missing-remotes variant (`SERVER NOT READY`), place-check.
- `npm run build`: builds `build/game.rbxlx` via `scripts/build-place.mjs` (fallback emitter).
- `node tests/place-check.mjs build/game.rbxlx`: PASS.

## Not yet verified
- **Rojo build**: Rojo 7.7.1 binary could not be downloaded in this sandbox (GitHub release TLS failures, npm wrapper fetch failure). CI (`.github/workflows/checks.yml`) runs the real `rojo build`; the fallback output is not authoritative until CI passes.
- **Roblox Studio Play QA (Q01–Q12, Q16)**: NOT RUN. No Studio access from this sandbox. Status: BLOCKED (not PASS).
- **Studio course artifact**: `Workspace.Course` is currently greybox geometry defined in `default.project.json`. The design requires Studio-authored, versioned geometry as the layout source of truth. That Studio-authored `.rbxl`/`.rbxlx` course artifact has not been produced yet. Until integrated and verified in Studio, the course is NOT a complete playable course.

## Known gaps
- Movement tuning is untested in Studio (feel, slope pitch, landing thresholds).
- Board is a client-side visual (anchored, placed from HRP); rider HRP is owned by BoardController.
- Session-only progression (grant once per finish, unlock/equip) is covered by pure-rule specs only.
