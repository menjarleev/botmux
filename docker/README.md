# Docker runtime

Refs #1: <https://github.com/menjarleev/botmux/issues/1>

This image contains BotMux, Node, Bun, tmux, Python and build tools. Agent
CLIs are optional: install them during configuration, without rebuilding the
image. The service runs as the unprivileged `node` user (UID/GID 1000).

## Build and configure

Allow at least 8 GB of memory for the source build, including Docker Desktop's
VM memory limit. The TypeScript compiler uses a build-only 6 GB heap limit.
Source builds use version `0.0.0-docker` when the checkout has no release version.
Override that fallback with `--build-arg BOTMUX_VERSION=0.0.0-docker.<revision>`.

```sh
docker compose build
docker compose run --rm botmux botmux setup
docker compose up -d
docker compose logs -f
```

Open <http://127.0.0.1:7891> for the dashboard. Run setup before starting bots.
Alternatively, start the service with no bots and configure it in the dashboard.
Use `/workspace` for the bot working directory. Do not copy host paths unchanged.

Install the selected CLI using its official instructions inside the container:

```sh
docker compose exec botmux bash
```

For npm-based CLIs, `npm install -g <package>@<version>` installs into
`/home/node/.local`, which is writable and persistent. Bun global installs,
user-local Python virtual environments and login files under HOME also persist.
Record chosen versions for repeatable recovery. System-wide installers requiring
root need a derived image; arbitrary CLI installers are not guaranteed to work.
After installing a CLI, authenticate inside the container and select it in
BotMux. Host login files and macOS Keychain are not automatically available.

For configuration before service startup, use:

```sh
docker compose run --rm botmux bash
```

## Persistence and lifecycle

`botmux-home` stores configuration, databases, CLI installations and credentials.
`botmux-workspace` stores projects. Container replacement preserves both volumes;
`docker compose down -v` deletes them. Back up both volumes with the service
stopped. Do not share one home volume between simultaneous BotMux services.

The foreground fleet supervisor manages bot daemons and the dashboard. Docker
handles container restarts; do not enable host autostart from inside the image.
Use `docker compose stop` for graceful shutdown. Bot logs are also available
through `docker compose exec botmux botmux logs`.

Persistent session records do not preserve running processes across container
replacement. CLI resume support determines whether a conversation can recover;
unsaved terminal state cannot survive replacement.

## Workspaces and network access

To work on a host project, replace the workspace volume with a bind mount such
as `./projects:/workspace`. On Linux, make it writable by UID/GID 1000. Mount only
the intended projects. The example does not mount the Docker socket or host HOME.

Ports are published on host loopback only. One bot uses terminal port 8800;
additional bot indices use 8801, 8802, etc. Publish each required port explicitly.
For remote access, use an authenticated reverse proxy or VPN, set
`WEB_EXTERNAL_HOST` to the reachable hostname, and configure matching port
forwarding. A hostname setting alone does not make a port reachable.

Rebuild the image to update BotMux. Do not update its binary in place: the image
binary belongs to root. CLI installations in the home volume are updated
separately. This addition does not migrate or stop host bot instances; stop a
host instance before enabling the same Lark app in Docker.

## Validation

```sh
sh docker/smoke.sh botmux:local
```

This uses a disposable home volume to check non-root execution, installing a
fixture CLI after build, CLI and home persistence after replacement, PNG
rendering, tmux, dashboard startup and graceful shutdown. It does not authenticate
an agent or test live Lark delivery. The script removes only its own container
and volume.
