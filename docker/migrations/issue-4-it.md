# IT host-to-container migration

Refs [#4](https://github.com/menjarleev/botmux/issues/4).
Validated on 2026-11-07; this records deployment evidence, not Issue closure.

## Result

- IT now runs in the persistent Docker runtime with BotMux 3.58.0.
- Its original OpenCode 1.19.5 executable, DeepSeek configuration and credential
  were transferred within the server. No credential was returned to chat or Git.
- The original Lark app identity and one-user allowlist were retained.
- Six active session records now use `/workspace`; one closed record was retained
  as history. Its historical reference to another host workspace was not copied
  as a live filesystem mount.
- OpenCode history was copied with SQLite backup, including committed WAL data.
- A minimal Docker-side DeepSeek request passed before enabling Lark.
- Docker reports IT online with Lark WebSocket connected, one connection attempt.
- The other host bot's PID remained unchanged throughout the cutover.
- A real Lark message/reply acceptance check is still pending the operator.

## Cutover and rollback boundary

The target was staged without a Lark configuration. IT reported zero busy
sessions before cutover. Only host IT was stopped, then an inactive placeholder
was set in its original array slot. A second exact stop and stopped/PID-zero
check closed the manual-restart window before the final snapshot and Docker
activation. The other bot's raw array index was preserved.

The host placeholder uses `activationPending: true`, with no associated recovery
job or managed activation marker. Indexed daemon loading and explicit start-bot
reject that state. Do not activate it while Docker IT is connected. A full host
restart may attempt and park this pending member; final removal requires a
planned host-fleet index transition, not deletion of the earlier array slot
while the later bot remains supervised by its old index.

Private snapshots, original host configuration and guarded rollback tools are
kept on the server with restrictive permissions. Stop Docker IT and confirm it
is disconnected before restoring the host row and starting host IT. If future
bots are added to the container, preserve those rows during rollback.

Host tmux processes were not moved into Docker. Persisted context/history was
migrated; full conversational cold-resume still needs real-message acceptance.
No outbound Lark test message was sent by the migration tooling.
