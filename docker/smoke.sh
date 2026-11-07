#!/bin/sh
# Refs #1: exercise the image without Lark credentials or host state.
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
docker run --rm -v "$volume:/home/node" "$image" sh -ec '
  test "$(id -u)" = 1000
  version=$(botmux --version)
  test -n "$version" && test "$version" != unknown
  printf "%s\n" "$version"
  node --version
  bun --version
  node -e '\''const { CanvasElement } = require(process.env.NAPI_RS_NATIVE_LIBRARY_PATH); const canvas = new CanvasElement(16, 16); if (!canvas.toBuffer("image/png").length) process.exit(1);'\''
  mkdir -p /tmp/sample-cli
  cd /tmp/sample-cli
  printf "%s\n" "{\"name\":\"sample-cli\",\"version\":\"1.0.0\",\"bin\":{\"sample-cli\":\"cli.sh\"}}" > package.json
  printf "%s\n" "#!/bin/sh" "echo CLI_PERSISTED" > cli.sh
  chmod +x cli.sh
  npm pack >/dev/null
  npm install -g ./sample-cli-1.0.0.tgz
  printf "%s\n" HOME_PERSISTED > "$HOME/smoke-marker"
  tmux -L docker-smoke new-session -d "sleep 30"
  tmux -L docker-smoke has-session
  tmux -L docker-smoke kill-server
'

docker run --rm -v "$volume:/home/node" "$image" sh -ec '
  test "$(sample-cli)" = CLI_PERSISTED
  test "$(cat "$HOME/smoke-marker")" = HOME_PERSISTED
'

docker run -d --name "$name" -v "$volume:/home/node" "$image" >/dev/null
ready=false
attempt=0
while [ "$attempt" -lt 60 ]; do
  attempt=$((attempt + 1))
  if docker exec "$name" curl -fsS http://127.0.0.1:7891/__health >/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
if [ "$ready" != true ]; then
  docker logs "$name"
  exit 1
fi
docker exec "$name" curl -fsS http://127.0.0.1:7891/ >/dev/null
docker stop -t 120 "$name" >/dev/null
test "$(docker inspect -f '{{.State.ExitCode}}' "$name")" = 0
printf '%s\n' 'PASS: CLI persistence, tmux, dashboard and graceful shutdown'
