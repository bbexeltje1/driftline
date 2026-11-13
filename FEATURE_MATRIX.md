# Feature inventory and implementation matrix

All entries **NOT STARTED** as of 2026-11-13. `V/P/U` refers to reference evidence in `GAME_REFERENCE_RESEARCH.md`, not project completion. `Original proposal` means no reference claim. Status updated only with source/Studio QA evidence; no speculative completion.

| System | Reference | DRIFTLINE implementation scope | First milestone | Status |
|---|---|---|---|---|
| Terrain sampling/ground contact/stability | P | multi-probe contact and stable grounded transitions | M1 | Not started |
| Downhill acceleration/coast/speed retention | U | tangent gravity, drag, capped speed | M1 | Not started |
| Tuck/push/brake/deceleration | U | independent speed controls | M1 | Not started |
| Heading/turning/carving/edge/grip/slip | P steer, U exact physics | speed-sensitive steer, explicit edge intent | M1 | Not started |
| Slope seams, walls/obstacles | P contact | seam hysteresis, obstacle speed loss | M1 | Not started |
| Ramp/pop/jump/airtime | U | natural takeoff plus bounded pop | M1 | Not started |
| Air steer/rotation | U | weaker yaw in air, spin tiers | M1 | Not started |
| Trick inputs/poses/combinations | U | 2 grabs + spin combos; expand later | M1/M5 | Not started |
| Pending score, combo, variety, bank | U | server validated capped chain, no credit on bail | M1/M5 | Not started |
| Landing quality/consequences | V impact gate, P wipeout | clean/sketchy/bail rules | M1 | Not started |
| Wipeout/recovery/penalty | P | checkpoint reset, +3 s once, pending loss | M1 | Not started |
| Race clock/start/gates/finish | P timer process, U rules | ordered gates/server finish | M1 | Not started |
| Camera follow/speed feedback | P camera routines | predictive lookahead/damped follow | M1/M9 | Not started |
| Animation state/transitions | P turn states, U graph | original functional poses first | M1/M9 | Not started |
| Sound/visual feedback | P event dispatch | basic cues then original polish | M1/M9 | Not started |
| Free Ride run and greybox course | U rules | original Switchback Basin | M1 | Not started |
| Score Jam/Time Attack/line events | P named modes, U rules | original modes | M3 | Not started |
| More courses/difficulty | U | original layouts/challenges | M3/M6 | Not started |
| Riders and board identities | V boarder modules, U stats | original riders, sidegrade boards | M1/M6 | Not started |
| Session reward/unlock/equip | U | first complete loop, temporary in Studio | M1 | Not started |
| Persistent profile/XP/achievements | U | durable progression | M2/M6 | Not started |
| Full cosmetic/customization catalogue | U | 10 categories (see GAME_DESIGN) | M6 | Not started |
| Controller/touch/remap/accessibility | U | device-specific controls | M4 | Not started |
| Multiplayer heats/ghosts | P h2h overlay, U rules | original server-authoritative heats | M7 | Not started |
| Records/leaderboards/social | U | verified competitive records | M8 | Not started |
| Full UI/menu/rewards presentation | U | original stream-energy identity | M9 | Not started |
| Performance/release/security | U | profiling/abuse/rollback | M10 | Not started |

Template foundation (existing, **not** feature implementation): basic HUD, server/client entry points, shared config, bounded remote wait, Studio temporary progress, Node Luau tests, CI Rojo place validation. See `PROJECT_MEMORY.md` for audited details.
