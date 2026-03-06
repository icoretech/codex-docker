#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:?IMAGE must be set}"
REPO_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DOCKERFILE="${DOCKERFILE:-$REPO_ROOT/Dockerfile}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"

if [ -z "$EXPECTED_VERSION" ] && [ -f "$DOCKERFILE" ]; then
  RELEASE_TAG=$(awk -F= '/^ARG CODEX_RELEASE_TAG=/{print $2; exit}' "$DOCKERFILE")
  EXPECTED_VERSION="${RELEASE_TAG#rust-v}"
fi

echo "==> codex version"
VERSION_OUTPUT=$(docker run --rm "$IMAGE" --version 2>&1)
printf '%s\n' "$VERSION_OUTPUT"

if [ -n "$EXPECTED_VERSION" ]; then
  printf '%s' "$VERSION_OUTPUT" | grep -F "codex-cli $EXPECTED_VERSION" >/dev/null
fi

echo "==> codex help"
ROOT_HELP_OUTPUT=$(docker run --rm "$IMAGE" --help 2>&1)
printf '%s\n' "$ROOT_HELP_OUTPUT"
printf '%s' "$ROOT_HELP_OUTPUT" | grep -F "Codex CLI" >/dev/null

echo "==> codex exec help"
EXEC_HELP_OUTPUT=$(docker run --rm "$IMAGE" exec --help 2>&1)
printf '%s\n' "$EXEC_HELP_OUTPUT"
printf '%s' "$EXEC_HELP_OUTPUT" | grep -F "Run Codex non-interactively" >/dev/null

echo "==> codex mcp-server help"
MCP_OUTPUT=$(docker run --rm "$IMAGE" mcp-server --help 2>&1)
printf '%s\n' "$MCP_OUTPUT"
printf '%s' "$MCP_OUTPUT" | grep -F "Start Codex as an MCP server" >/dev/null

echo "==> helper help"
HELP_OUTPUT=$(docker run --rm "$IMAGE" codex-bootstrap help 2>&1)
printf '%s\n' "$HELP_OUTPUT"
printf '%s' "$HELP_OUTPUT" | grep -F "Codex container helper" >/dev/null
