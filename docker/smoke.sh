#!/bin/sh
# Refs #1, #3: real release updates without replacing the container.
set -eu
image=${1:-botmux:local}
name="botmux-smoke-$$"
volume="$name-home"
cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
docker volume create "$volume" >/dev/null
docker run -d --name "$name" -e BOTMUX_VERSION=3.57.2 \
  -v "$volume:/home/node" "$image" >/dev/null
attempt=0
until docker exec "$name" curl -fsS http://127.0.0.1:7891/__health >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 180 ]; then
    docker logs "$name"
    exit 1
  fi
  sleep 2
done
started=$(docker inspect -f '{{.State.StartedAt}}' "$name")
docker exec "$name" sh -ec '
  test "$(id -u)" = 1000
  test "$(botmux --version)" = 3.57.2
  mkdir -p "$HOME/.config/runtime-smoke"
  printf "%s\n" FAKE_LOGIN_MARKER > "$HOME/.config/runtime-smoke/auth"
  printf "%s\n" MEMORY_MARKER > "$HOME/smoke-memory"
  tmux -L botmux new-session -d -s runtime-smoke "exec sleep 600"
'
task=$(docker exec "$name" tmux -L botmux display-message \
  -p -t runtime-smoke '#{pane_pid}')
config=$(docker exec "$name" sha256sum /home/node/.botmux/bots.json)
docker exec "$name" botmux-runtime update 3.58.0
test "$(docker exec "$name" botmux --version)" = 3.58.0
test "$(docker inspect -f '{{.State.StartedAt}}' "$name")" = "$started"
test "$(docker exec "$name" tmux -L botmux display-message \
  -p -t runtime-smoke '#{pane_pid}')" = "$task"
test "$(docker exec "$name" sha256sum /home/node/.botmux/bots.json)" = "$config"
docker exec "$name" sh -ec '
  test "$(cat "$HOME/.config/runtime-smoke/auth")" = FAKE_LOGIN_MARKER
  test "$(cat "$HOME/smoke-memory")" = MEMORY_MARKER
'
if docker exec "$name" botmux-runtime update invalid-version; then
  exit 1
fi
test "$(docker exec "$name" botmux --version)" = 3.58.0
docker exec "$name" botmux-runtime update 3.57.2
test "$(docker exec "$name" botmux --version)" = 3.57.2
test "$(docker exec "$name" tmux -L botmux display-message \
  -p -t runtime-smoke '#{pane_pid}')" = "$task"
docker exec "$name" botmux-runtime update 3.58.0
docker stop -t 120 "$name" >/dev/null
test "$(docker inspect -f '{{.State.ExitCode}}' "$name")" = 0
docker run --rm -v "$volume:/home/node" "$image" sh -ec '
  test "$(botmux --version)" = 3.58.0
  test "$(cat "$HOME/.config/runtime-smoke/auth")" = FAKE_LOGIN_MARKER
  test "$(cat "$HOME/smoke-memory")" = MEMORY_MARKER
'
printf '%s\n' 'PASS: version update/rollback, stable container and tmux PID, persistent state'
