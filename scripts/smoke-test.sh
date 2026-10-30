#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:?IMAGE must be set}"
REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
sh "$REPO_ROOT/scripts/test-websocket-token.sh"
DOCKERFILE="${DOCKERFILE:-$REPO_ROOT/Dockerfile}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"

if [ -z "$EXPECTED_VERSION" ] && [ -f "$DOCKERFILE" ]; then
  RELEASE_TAG=$(awk -F= '/^ARG CODEX_RELEASE_TAG=/{print $2; exit}' "$DOCKERFILE")
  EXPECTED_VERSION="${RELEASE_TAG#rust-v}"
fi

echo "==> codex version"
VERSION_OUTPUT=$(docker run --rm --network=none "$IMAGE" --version 2>&1)
printf '%s\n' "$VERSION_OUTPUT"

if [ -n "$EXPECTED_VERSION" ]; then
  printf '%s' "$VERSION_OUTPUT" | grep -F "codex-cli $EXPECTED_VERSION" >/dev/null
fi

echo "==> codex help"
ROOT_HELP_OUTPUT=$(docker run --rm --network=none "$IMAGE" --help 2>&1)
printf '%s\n' "$ROOT_HELP_OUTPUT"
printf '%s' "$ROOT_HELP_OUTPUT" | grep -F "Codex CLI" >/dev/null

echo "==> codex login help"
LOGIN_HELP_OUTPUT=$(docker run --rm --network=none "$IMAGE" login --help 2>&1)
printf '%s\n' "$LOGIN_HELP_OUTPUT"
printf '%s' "$LOGIN_HELP_OUTPUT" | grep -F -- "--device-auth" >/dev/null
printf '%s' "$LOGIN_HELP_OUTPUT" | grep -F -- "--with-access-token" >/dev/null

echo "==> codex exec help"
EXEC_HELP_OUTPUT=$(docker run --rm --network=none "$IMAGE" exec --help 2>&1)
printf '%s\n' "$EXEC_HELP_OUTPUT"
printf '%s' "$EXEC_HELP_OUTPUT" | grep -F "Run Codex non-interactively" >/dev/null

echo "==> sandbox prerequisites"
SANDBOX_OUTPUT=$(docker run --rm --network=none --entrypoint sh "$IMAGE" -lc 'command -v bwrap && bwrap --version' 2>&1)
printf '%s\n' "$SANDBOX_OUTPUT"
printf '%s' "$SANDBOX_OUTPUT" | grep -F "bubblewrap" >/dev/null
echo "==> Code Mode host"
CODE_MODE_HOST_OUTPUT=$(docker run --rm --network=none --entrypoint sh "$IMAGE" -lc 'test -x /usr/local/bin/codex-code-mode-host && test "$(command -v codex-code-mode-host)" = /usr/local/bin/codex-code-mode-host && codex-code-mode-host --help' 2>&1)
printf '%s\n' "$CODE_MODE_HOST_OUTPUT"

echo "==> packaged runtime layout"
docker run --rm --network=none --entrypoint sh "$IMAGE" -lc '
  test "$(readlink -f "$(command -v codex)")" = /opt/codex/bin/codex &&
  test "$(readlink -f "$(command -v codex-exec-server)")" = /opt/codex/bin/codex-exec-server &&
  test "$(readlink -f "$(command -v codex-code-mode-host)")" = /opt/codex/bin/codex-code-mode-host &&
  test -s /opt/codex/codex-package.json &&
  test -x /opt/codex/codex-path/rg &&
  test -x /opt/codex/codex-resources/bwrap &&
  /opt/codex/codex-path/rg --version &&
  printf "%s\n" package-runtime-probe | /opt/codex/codex-path/rg "^package-runtime-probe$" &&
  /opt/codex/codex-resources/bwrap --version
'

echo "==> packaged voice helper loader"
docker run --rm --network=none --entrypoint sh "$IMAGE" -lc '
  voice_root=/opt/codex/codex-resources/voice
  test -s "$voice_root/manifest.json" &&
  voice_commit=$(LD_LIBRARY_PATH="$voice_root/lib" "$voice_root/bin/codex-voice-host" --build-commit) &&
  printf "%s\n" "$voice_commit" | grep -E "^[0-9a-f]{40}$" &&
  grep -F "\"buildCommit\": \"$voice_commit\"" "$voice_root/manifest.json"
'

echo "==> packaged exec server"
EXEC_SERVER_OUTPUT=$(docker run --rm --network=none --entrypoint codex-exec-server "$IMAGE" --version 2>&1)
printf '%s\n' "$EXEC_SERVER_OUTPUT"
if [ -n "$EXPECTED_VERSION" ]; then
  [ "$(printf '%s' "$EXEC_SERVER_OUTPUT" | awk '{print $NF}')" = "$EXPECTED_VERSION" ]
fi
docker run --rm --network=none --entrypoint codex-exec-server "$IMAGE" --help

echo "==> codex mcp help"
MCP_OUTPUT=$(docker run --rm --network=none "$IMAGE" mcp --help 2>&1)
printf '%s\n' "$MCP_OUTPUT"
printf '%s' "$MCP_OUTPUT" | grep -F "Manage external MCP servers" >/dev/null

echo "==> codex remote-control help"
REMOTE_CONTROL_OUTPUT=$(docker run --rm --network=none "$IMAGE" remote-control --help 2>&1)
printf '%s\n' "$REMOTE_CONTROL_OUTPUT"
printf '%s' "$REMOTE_CONTROL_OUTPUT" | grep -F "Usage: codex remote-control" >/dev/null
printf '%s' "$REMOTE_CONTROL_OUTPUT" | grep -F "start  Start" >/dev/null
printf '%s' "$REMOTE_CONTROL_OUTPUT" | grep -F "stop   Stop" >/dev/null

echo "==> codex remote-control start help"
REMOTE_CONTROL_START_OUTPUT=$(docker run --rm --network=none "$IMAGE" remote-control start --help 2>&1)
printf '%s\n' "$REMOTE_CONTROL_START_OUTPUT"
printf '%s' "$REMOTE_CONTROL_START_OUTPUT" | grep -F "Usage: codex remote-control start" >/dev/null

echo "==> codex app-server websocket help"
APP_SERVER_OUTPUT=$(docker run --rm --network=none "$IMAGE" app-server --help 2>&1)
printf '%s\n' "$APP_SERVER_OUTPUT"
printf '%s' "$APP_SERVER_OUTPUT" | grep -F -- "--listen <URL>" >/dev/null
printf '%s' "$APP_SERVER_OUTPUT" | grep -F -- "--ws-auth <MODE>" >/dev/null
printf '%s' "$APP_SERVER_OUTPUT" | grep -F -- "--ws-token-sha256 <HEX>" >/dev/null

echo "==> helper help"
HELP_OUTPUT=$(docker run --rm --network=none "$IMAGE" codex-bootstrap help 2>&1)
printf '%s\n' "$HELP_OUTPUT"
printf '%s' "$HELP_OUTPUT" | grep -F "Codex container helper" >/dev/null
printf '%s' "$HELP_OUTPUT" | grep -F "access-token-login" >/dev/null
