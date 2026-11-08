# Persistent BotMux Docker runtime

Refs [#1](https://github.com/menjarleev/botmux/issues/1) and
[#3](https://github.com/menjarleev/botmux/issues/3).

This is a long-running Linux environment with Node, Bun, Python, tmux and build
tools. BotMux is installed at first startup into persistent HOME, not bundled
into the image. A container may configure multiple bots and share its memory,
files and CLI logins. Different Compose projects receive separate data volumes.

For AI-assisted provisioning and backend installation, read
[AI setup instructions](AI-SETUP.md), or use the portable
[skill](../skills/botmux-docker-runtime/SKILL.md).

## Start a new instance

```sh
docker compose build
docker compose up -d --wait --wait-timeout 300
docker compose exec botmux botmux dashboard
```

First startup installs the exact `BOTMUX_VERSION` (default `3.58.0`) and creates
an empty bot registry only when no registry exists. Later starts retain the
selected installed version, even if the environment default changes.
Installation
requires access to the npm registry. Open the private login link printed by the
last command yourself; do not paste its token into a chat or shared log.

The default dashboard is <http://127.0.0.1:7891>. Add bots in the dashboard, or
run setup **after** initial startup:

```sh
docker compose exec botmux botmux setup
docker compose exec botmux bash
```

The image contains no `botmux` executable before bootstrap. For an offline setup
shell, `docker compose run --rm botmux bash` works; install BotMux explicitly
with `botmux-runtime install 3.58.0` before invoking it there.

Agent CLIs are installed separately. npm globals go to `/home/node/.local`;
Bun globals, user-local Python environments, credentials and memory under HOME
also persist. Use official backend instructions and authenticate inside this
instance. Host Keychain entries and host login files are not automatically
shared.
Use `/workspace` as the bot working directory.

## Homeserver

Use the separate-port override alongside an existing installation:

```sh
docker compose -f compose.yaml -f compose.homeserver.yaml up --build -d --wait --wait-timeout 300
docker compose -f compose.yaml -f compose.homeserver.yaml exec botmux botmux dashboard
```

Dashboard port: 18891. First bot terminal port: 18800. Both bind to host
loopback
by default. For a remote server, forward both ports through SSH:

```sh
ssh -N -L 18891:127.0.0.1:18891 -L 18800:127.0.0.1:18800 YOUR_SSH_HOST
```

The login link then works at `127.0.0.1:18891` on your computer. Do not bind an
admin or terminal endpoint to a LAN/public interface without authorization.
Additional bots use terminal ports 8801, 8802, etc. inside the container and
need
matching explicit host mappings and SSH forwards. All configured bots may share
one container; it is not restricted to one bot.

To isolate private-network access between container groups, also apply
`compose.isolated.yaml` **last**. It moves the port mappings to a dedicated
network guard. Each project needs its own HOME/workspace volumes and host ports.
The guard requires namespaced `NET_ADMIN`; BotMux itself drops all capabilities.
Public IPv4 egress is allowed; new private/reserved-IP connections and all
non-loopback IPv6 egress are blocked. Replies to inbound admin connections work.
Private model endpoints and private git servers will require a deliberate policy
change. This is not an external-service information-sharing prevention system.

## Update without recreating the container

```sh
docker compose exec botmux botmux-runtime update 3.58.0
```

For homeserver deployments, include the same `-f` arguments used at startup.
Choose an explicit published version. This command installs and checks the new
release in a separate version directory, atomically selects it, restarts BotMux
and waits for its dashboard health check. Updates are serialized by `flock`.
The container's runtime process stays alive while BotMux restarts. tmux
processes
remain in the same container. Lark and browser connections may briefly
reconnect.

Rollback to a retained version uses the same command with its version number.
An installation failure leaves the selected version unchanged. If activation
fails, the previous version is reselected but the fleet is **not** forcibly
restarted, so an intervening operator stop is respected. Inspect the private
`~/.botmux/container-lifecycle.log`, then explicitly start/restart if
appropriate.
Version rollback does not reverse database migrations; back up data before an
upgrade with a migration or an untested version jump.

Use this helper rather than BotMux's package updater or scheduled automatic
updates: it owns the version directories and rollback selection. Native
`botmux restart`, `botmux start` and `botmux stop` remain usable; stop leaves
the
container running. Its lightweight watchdog respects BotMux's intentional-stop
marker. Lifecycle output is stored privately because it may contain login URLs.

## Persistence and the restart boundary

HOME stores versioned BotMux installs, configuration, databases, login state,
backend installations and memory. `/workspace` stores projects. Both use named
volumes; use a unique Compose project name per container group. Do not share
HOME
between simultaneous instances. Do not mount host HOME or the Docker socket.

Daily BotMux updates do not require rebuilding the image. Updating Node, Bun or
OS packages requires an image update and container replacement, which **does end
running processes**, including tmux tasks. Volumes preserve files, not
processes.
Back up both volumes with services stopped. `docker compose down -v` deletes
them.
The non-root user has UID/GID 1000; host bind mounts must be writable by that
user.

## Validation

```sh
sh docker/smoke.sh botmux:local
node --test docker/runtime.test.mjs
docker build -f docker/Dockerfile.network -t botmux-network-guard:local .
sh docker/isolation-smoke.sh botmux:local botmux-network-guard:local
```

The disposable test installs 3.57.2, updates to 3.58.0, rolls back, and verifies
that the container start time and a tmux task PID stay unchanged. It checks
configuration, memory and fake login markers, plus persistence after container
replacement and graceful shutdown. It does not authenticate a real backend,
verify Lark delivery, or prove BotMux-managed CLI reattachment during a live
task.
The isolation probe also temporarily bypasses its one peer deny rule to prove
the negative test is exercising the guard, then restores it and checks denial.
