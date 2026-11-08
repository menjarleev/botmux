#!/bin/sh
set -eu

mkdir -p "$HOME/.botmux" "$HOME/.local/bin" "$HOME/.bun/bin"

if [ "${1:-}" = serve ]; then
  shift
  exec botmux-runtime serve "$@"
fi

exec "$@"
