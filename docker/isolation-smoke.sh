#!/bin/sh
# Refs #3: test the guard even when peers share a reachable Docker network.
set -eu
image=${1:-botmux:local}
guard_image=${2:-botmux-network-guard:local}
name="botmux-isolation-$$"
cleanup() {
  docker rm -f "$name-a" "$name-b" "$name-guard-a" "$name-guard-b" >/dev/null 2>&1 || true
  docker volume rm "$name-home-a" "$name-home-b" >/dev/null 2>&1 || true
  docker network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
docker network create "$name" >/dev/null
for side in a b; do
  docker volume create "$name-home-$side" >/dev/null
  docker run -d --name "$name-guard-$side" --network "$name" \
    --cap-drop ALL --cap-add NET_ADMIN --security-opt no-new-privileges \
    --read-only --tmpfs /run "$guard_image" >/dev/null
  attempt=0
  until docker exec "$name-guard-$side" test -f /run/network-ready; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
      docker logs "$name-guard-$side"
      exit 1
    fi
    sleep 1
  done
  docker run -d --name "$name-$side" --network "container:$name-guard-$side" \
    --cap-drop ALL --security-opt no-new-privileges \
    -v "$name-home-$side:/home/node" "$image" node -e \
    'require("http").createServer((q,s)=>s.end("peer")).listen(8765,"0.0.0.0")' >/dev/null
done
sleep 2
docker exec "$name-b" sh -ec 'echo PRIVATE_B > "$HOME/memory-marker"'
docker exec "$name-a" sh -ec 'test ! -e "$HOME/memory-marker"'
docker exec "$name-a" curl -fsS http://127.0.0.1:8765/ >/dev/null
peer=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name-guard-b")
if docker exec "$name-a" curl -fsS --max-time 3 "http://$peer:8765/" >/dev/null 2>&1; then
  echo 'FAIL: peer was reachable with the guard enabled'
  exit 1
fi
# Mutation check: the probe must become reachable when this one deny is bypassed.
docker exec "$name-guard-a" iptables -w -I OUTPUT 3 -d "$peer/32" -j ACCEPT
docker exec "$name-a" curl -fsS --max-time 3 "http://$peer:8765/" >/dev/null
docker exec "$name-guard-a" iptables -w -D OUTPUT -d "$peer/32" -j ACCEPT
if docker exec "$name-a" curl -fsS --max-time 3 "http://$peer:8765/" >/dev/null 2>&1; then
  exit 1
fi
docker exec "$name-a" node -e '
  const status = require("fs").readFileSync("/proc/self/status", "utf8");
  if (!/^CapEff:\s+0+$/m.test(status) || !/^NoNewPrivs:\s+1$/m.test(status)) process.exit(1);
'
docker exec "$name-a" curl -fsS --max-time 20 https://registry.npmjs.org/botmux/latest >/dev/null
printf '%s\n' 'PASS: private peer denied, bypass probe verified, public egress and separate HOME'
