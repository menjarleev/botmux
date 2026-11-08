# AI-assisted BotMux container setup

Refs #1 and #3. The operator can hand this file directly to an AI agent.
The durable runtime model and exact commands are in [README](README.md).

## Outcome and inputs

Provision a long-running container, install a pinned BotMux release inside its
persistent HOME, install the operator's selected agent backend(s), and configure
chat access. Multiple bots in one container may share files and memory. Separate
container groups must use separate HOME/workspace volumes and admin credentials.

Discover architecture, Docker/Compose versions, available memory/disk, existing
services and occupied ports. Read the target repository's instructions. Ask only
for missing decisions: deployment host/access, backend, model provider/login
mode
and who may operate each Lark app. Do not choose a paid provider or invent app
credentials. Reuse authorized SSH/secret-manager access; never request pasted
passwords or API keys when a supported secure route exists.

## Provisioning

1. Identify the tracking GitHub Issue before durable changes. Use an isolated
   deployment directory and preserve existing host bots and unrelated services.
2. Build `Dockerfile`. It installs tools only; no source build or bundled BotMux
   binary is required. Pin `BOTMUX_VERSION` to a published exact version.
3. Select a unique Compose project name, separate named HOME/workspace volumes,
   and unused ports. Use `compose.homeserver.yaml` when ports 7891/8800 are
   busy.
   Default to host loopback with SSH forwarding. Ask before broader exposure.
4. Start the container and wait for `/__health`. First startup installs BotMux.
   Use `exec botmux ...` for setup afterwards; do not invoke an uninstalled
   `botmux setup` in a fresh one-off container.
5. Generate the dashboard login link with `botmux dashboard`. Open it privately
   or let the operator run the command. Do not log or publish the token.
6. Configure Lark apps and their allowed users in the dashboard or `botmux
setup`.
   Use the app's own validated owner identity, not another app's `open_id`.
   Choose `/workspace` or an explicitly authorized project mount.

Do not enable a Lark app in this instance while it is still active in another
instance unless the operator explicitly planned that migration.

## Install the selected backend

Run installers **inside the running container as its normal user**. Pin npm
package versions and record the result. Read the backend's current official
instructions before installing; package names and OAuth flows may change.

- Grok: official package `@xai-official/grok`; use
  `npm install -g @xai-official/grok@VERSION`, then follow its interactive
  login.
  Source: [xAI Grok Build](https://github.com/xai-org/grok-build).
- OpenCode: `npm install -g opencode-ai@VERSION`, then select/authenticate the
  chosen provider using the installed CLI. Source:
  [OpenCode installation](https://opencode.ai/docs/).
- Hermes: read [official installation instructions](https://hermes-agent.nousresearch.com/docs/getting-started/installation)
  and inspect the installer before executing it. Install under HOME using its
  supported user-local Python/uv environment, then run `hermes setup`.
  Avoid host service installation and unnecessary systemd/Gateway setup when
  Hermes is being used as a BotMux CLI backend.
- Other CLIs: use official instructions and verify Linux/architecture support.

Use the backend's real `--version` and a small non-destructive invocation to
verify executable availability. Then configure the matching BotMux adapter.
OAuth/device login may require the operator in their browser; explain exactly
what is waiting and resume verification after login. Do not claim login success
from installation alone. A remote loopback callback may require SSH forwarding
or the backend's documented device/manual callback flow.

Installations must land under persistent HOME, not ephemeral `/usr/local`.
If an installer requires root or unsupported paths, report it and adapt the
image explicitly rather than silently changing host services or permissions.

## Acceptance and update

Verify dashboard access, backend executable/version, selected adapter and an
operator-authorized Lark reply. Keep installation, authentication and live
message delivery as separate checks. Do not send test messages without explicit
permission. Record skipped interactive/live checks honestly.

For a daily BotMux update, use `botmux-runtime update EXACT_VERSION` **inside
the
running container**, not `compose down/up`, container restart, image rebuild,
BotMux's upstream package updater or automatic-update schedule. Verify version,
dashboard recovery, unchanged container start time and a pre-existing tmux task
PID. Check persistent configuration and login-state files without printing
secrets.
Keep the prior version for rollback; changing versions cannot undo DB
migrations.
Base-image upgrades remain a maintenance operation that ends running processes.

If container isolation is requested, apply `compose.isolated.yaml` last and test
private-network denial plus required public egress before deployment. Do not
weaken the guard to make a private endpoint work without an explicit decision.

Deliver the deployment location, exact versions, private access method, update
and rollback commands, completed evidence and any pending OAuth/Lark checks.
Never include secrets, login URLs with tokens, or a claim of zero message loss.
