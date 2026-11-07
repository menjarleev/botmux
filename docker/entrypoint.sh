#!/bin/sh
set -eu

mkdir -p "$HOME/.botmux" "$HOME/.local/bin" "$HOME/.bun/bin"

if [ "${1:-}" = serve ]; then
  shift
  cd "$HOME/.botmux"
  exec /usr/local/bin/botmux __supervisor "$@"
fi

exec "$@"
