# Validation record

Refs #1 and #3. Checked on 2026-11-07 against the Issue #3 candidate.

| Criterion | Evidence | Result |
|---|---|---|
| Runtime-only image, server installation | AMD64 build, first boot installs pinned npm release | Passed |
| Upgrade without replacing container | 3.57.2 → 3.58.0, unchanged container start time | Passed |
| Preserve a running tmux task | Same pane PID before/after upgrade and version rollback | Passed |
| Retain configuration and state | Registry checksum, memory and fake login markers | Passed |
| Roll back retained release | 3.58.0 → 3.57.2 → 3.58.0 in same container | Passed |
| Failed install preserves selection | Actual runtime with failing npm fixture | Passed |
| Respect intervening operator stop | Actual runtime with failing restart/stop fixture | Passed |
| Keep lifecycle secrets private | No marker in stdout/stderr; lifecycle log mode 0600 | Passed |
| Separate container HOME and deny peer access | Two real peer containers, guard deny and bypass mutation | Passed |
| Permit public installation traffic | Guarded container reaches npm registry | Passed |
| Backend installation | Official Grok npm package, `grok 1.0.77` under dropped capabilities | Passed |
| Skill package | Skill creator validator and independent scenario walkthrough | Passed |
| Shell and Compose configuration | ShellCheck and three-layer Compose validation | Passed |

The runtime unit suite has three behavior tests. The independent failure probe
identified an unconditional rollback restart that could undo an operator stop;
that restart was removed and the probe repeated successfully. A fresh-install
README race was resolved with Compose health checks and `up --wait`.

No real backend credentials were used. Backend OAuth, Lark send/receive, lost
message handling, screenshot rendering of the npm binary, and BotMux-managed CLI
reattachment during a live task have not been verified. The tmux probe establishes
process survival, not full live conversational recovery. A version rollback does
not undo data migrations. Current runtime ARM64 CI is separate from this AMD64
server evidence. Container/base-image replacement still terminates processes.
