#!/usr/bin/env sh
set -eu

case "${1:-}" in
  "")
    exec codex
    ;;
  codex-bootstrap)
    shift
    exec /usr/local/bin/codex-bootstrap "$@"
    ;;
  codex)
    shift
    exec codex "$@"
    ;;
  *)
    exec codex "$@"
    ;;
esac
