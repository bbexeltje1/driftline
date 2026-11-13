# Reference research — 1080 Snowboarding (N64)

Research snapshot: 2026-11-13. Source: [djsaunde/1080-decomp](https://github.com/djsaunde/1080-decomp), commit `421243a8cdcca7a3584135077ffd8d18ceecb010`. Paths below refer to that commit. **Research only; no reference code or assets are to be copied.** V = directly visible in checked source, P = plausible interpretation of partial source, U = not established. A source comment is evidence of a researcher's interpretation, not independent runtime verification.

## Limits of the evidence

The reference README reports ~38.22% matched code bytes overall (snapshot 2026-09-12) despite a ROM-exact build; untouched assembly, `NON_MATCHING` bodies, anonymous symbols and ROM-extracted assets are not evidence of fully recovered design. No ROM was run and no extracted assets were inspected. Byte-exact compilation does not mean all mechanics have readable C. We did not measure original feel, scoring formula, input map or mode rules. The repository README's status is a *repository claim*, not our build verification.

## Source-backed observations

| System | Evidence and confidence | What is NOT established |
|---|---|---|
| Ground sampling/contact | `src/game_uso/game_uso.c` around `game_uso_func_000097EC` describes multi-point terrain ray/height sampling and flattened contact points; the checked-in body is a donor placeholder and comment calls the earlier pass structural. **P** ground sampling; not a complete decoded physics specification. | Number/placement of contact points, exact forces and terrain materials. |
| Collision response | Same file `game_uso_func_0000BB8C` comment calls it a snowboard contact-response solver; explicitly describes a NON_MATCHING structural reconstruction. **P**. | Exact friction, suspension, impulse and crash thresholds from this routine. |
| Speed/steer | `game_uso_func_000071E0` comment identifies a speed-gated counter and steer stage; body is a donor splice placeholder. `game_uso_func_0000EAF4` contains turn-state accumulation and input-bit branches (`0x10000`, `0x4000`, etc.) but is non-matching, interpretation of controls provisional. **P**. | Exact control layout, acceleration/deceleration curves, edge angles, carving rules and numerical tuning. |
| Landing/wipeout | `game_uso_func_00011750` is described as byte-exact by source comment: on a float field `< -30.0f` it advances a short counter; at threshold it dispatches event/FX and resets; otherwise resets counter. **V** conditional dispatch, **P** that float is vertical impact and event a wipeout. | User-facing crash rules, score penalties, recovery length; do not reuse the numeric threshold. |
| Camera | `game_uso_func_000024BC`, `00002CC8`, `00003558` comments identify homing, position snap and spring-vector camera work. **P** camera-follow behavior. | Exact camera offsets, damping or collision handling. |
| Modes/processes | `README.md` names `arcproc_uso`, `h2hproc_uso`, `timproc_uso_b*`, `titproc_uso`, `game_uso`, five `boarder*_uso` and an `eddproc_uso` overlay. **V** distinct named overlays; **P** arcade/head-to-head/timing/title/edit roles (README descriptions). | Complete mode rules, unlocks, challenge lists, whether edit means customization. |
| Riders | Five `boarder*_uso` overlays listed in README; `src/boarder1_uso/boarder1_uso.c` consists primarily of small data-copy/initialization functions. **V** multiple boarder-specific modules; **U** rider stats. | Number of playable characters, any unique performance or cosmetics. |
| Timer/UI | `timproc_uso_b5` contains named timing-screen/track-panel comments and screen-state routines; README identifies timer-process variants. **P** timing/display pipeline. | Race timing method, checkpoint and finish semantics. |
| Sound/FX | `game_uso_func_00011750` calls event dispatch with different flags and effect routines in hard-hit condition; **V** event dispatch, **P** audible/visual effect. | Exact sound palette and event meanings. |
| Tricks/combos/scoring | No trustworthy complete rules located in inspected overlays. **U**. | Input grammar, names, multipliers, trick scoring, spin thresholds, score banking. |
| Animation | `game_uso_func_0000EAF4` returns turn-like state categories; **P** connection to pose; no verified animation graph. **U** for transitions. | Exact animations, frame timing and blend behavior. |
| Progression/unlocks | No reliable source-derived reward or unlock rules found. **U**. | Difficulty progression, currency, unlock criteria, board attributes. |
| Races/checkpoints | Names imply timing and competition; no verified checkpoint/finish condition established. **U**. | Checkpoint count, laps, disqualification and race penalties. |

**Research follow-up:** inspect individual assembly/function call graphs and, if legally available, test an original game copy to validate further behavior. Never elevate inference to verified without a specific source or observed run. The project below uses original design proposals, not assertions about the N64 game's precise rules.
