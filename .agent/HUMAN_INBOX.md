# Owner decisions needed before implementation

1. **Separate GitHub repo:** please create a new private repo from `bbexeltje1/game2` main (or authorize/provide a GitHub write-capable mechanism) and give its exact URL; authorize `arena/development` branch setup and initial docs push. This environment has no supported GitHub connector or `gh`; local copy/branch exists only. Confirm name/visibility and whether history should be cloned or fresh template commit. Never make `game2` the remote.
2. **Studio course artifact:** choose how Studio-owned greybox Workspace geometry will be saved/versioned and merged with Rojo source, without runtime creating or replacing designed objects. Suggested: a versioned `.rbxlx` place edited in Studio plus Rojo live sync for scripts, with verified build/export procedure; or a documented Rojo-managed static geometry artifact edited in Studio then exported back. Template currently has no Workspace mapping. Approve workflow before M1 code.
3. **M1 controls:** approve W tuck, S brake, A/D steer/spin, Q/E edge, Space pop, J/K grab and start/retry bindings. Confirm if edge should be a hold or toggle. PC only for M1 was selected in clarification.
4. **M1 persistence promise:** approve session-only Studio progression/unlocks in M1 and published test-place persistence in M2, or supply earlier published test-place credentials and revise milestones.
5. **Game identity/economy:** approve or rename DRIFTLINE, basic modes/course names, modest board sidegrades, +3-second bail penalty and non-pay-to-win policy. Prices/thresholds need tuning after first Play evidence.
6. **QA access:** confirm Qwen's Studio MCP controls, screenshot/output/runtime inspection and a nonproduction published test experience for M2. Owner supervises handoffs initially.

If unresolved, mark dependent QA/implementation BLOCKED and continue only independent planning. Do not request credentials in documentation or commit secrets.
