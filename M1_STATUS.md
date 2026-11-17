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

## Launcher (`.\scripts\play.ps1`) — status
- `play.ps1`: pulls the current branch only (`git pull --ff-only origin <branch>`, never main), runs `build.ps1`, then opens `build\game.rbxlx` in Studio. Press Play; no publishing or API settings.
- `build.ps1`: uses `rojo` from PATH, or downloads the pinned `rojo-7.7.1-windows-x86_64.zip` into `.tools/` (git-ignored, TLS 1.2 forced for Windows PowerShell 5.1). Stamps `BuildTag`, runs `rojo build`, then `tests/place-check.mjs`, which now also requires every M1 server/shared/client module and the Workspace.Course greybox.
- **Fixed real Rojo build blocker:** 25 `CFrame` entries in `default.project.json` used a 6-number Euler form. Rojo 7.7.1 (`src/resolution.rs`, `AmbiguousValue::resolve`) accepts only 12-number CFrames, so the real `rojo build` would have failed while the fallback builder passed. Converted to position + 3x3 matrix (same Ry·Rx·Rz geometry). Guarded by `tests/project-check.mjs` (run by `npm test`); the old form fails it.
- **Fixed untimed waits** in `Main.client.luau` (HUD, client module requires, PlayerGui); all bounded at 10s, with a visible error if `ClientModules` is missing.

### Verified in this sandbox
- `npm test`: PASS (syntax, rules, client boot, missing-remotes variant, Rojo project guard, place check).
- Fallback build `npm run build:fallback` + `place-check`: PASS (includes M1 systems).
- Negative control: pre-fix `default.project.json` FAILS `project-check`.

### NOT verified in this sandbox (blockers)
- **`.\scripts\play.ps1` was not executed.** No PowerShell (`pwsh`) and no Windows host. Only ASCII/CRLF/no-BOM syntax was checked by inspection.
- **Real `rojo build` was not executed.** GitHub release downloads fail TLS from this sandbox (`curl` exit 35). CI pins Rojo 7.7.1 and runs it on push.
- **Roblox Studio open + Play: NOT RUN.** No Studio here. Status BLOCKED, not PASS.
- Course is Rojo-built greybox (from `default.project.json`), not a Studio-authored versioned artifact. Integrating a Studio-authored course is still pending.
