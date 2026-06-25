# 🤖 Codex CLI Multiarch Docker Image

[![Publish](https://github.com/icoretech/codex-docker/actions/workflows/publish.yml/badge.svg)](https://github.com/icoretech/codex-docker/actions/workflows/publish.yml)
[![Codex image](https://img.shields.io/github/v/tag/openai/codex?filter=rust-v*&sort=semver&label=codex%20image&logo=docker)](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker)
[![GHCR](https://img.shields.io/badge/ghcr-codex--docker-blue?logo=docker)](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker)

This repository hosts an automated build system for creating 🐳 Docker images of the official [OpenAI Codex CLI](https://github.com/openai/codex).
The built AMD64/ARM64 Docker images are published to GHCR with semantic tagging that mirrors the upstream Codex release version.

## 📖 Overview

The build system pins an upstream Codex release tag in `Dockerfile` via `ARG CODEX_RELEASE_TAG` and downloads the official Linux musl release assets from `openai/codex`.
Version bumps are managed through Renovate pull requests, and the publish workflow tags the Docker image with the matching Codex CLI version.
Pull requests run the separate `Build` workflow for image validation and smoke tests before merge.

Image characteristics:

- multi-arch: `linux/amd64`, `linux/arm64`
- default runtime behaves like plain `codex`
- runs as a non-root user
- includes `bubblewrap` for Codex Linux sandboxing
- persistent config/auth/log state lives under `CODEX_HOME`
- includes an opt-in `codex-bootstrap` helper for login-oriented container flows

## 💡 Usage

Set a version once and reuse it in the examples below:

```bash
# renovate: datasource=github-releases depName=openai/codex extractVersion=^rust-v(?<version>.+)$
CODEX_VERSION=0.142.2
```

Pull the image:

```bash
docker pull ghcr.io/icoretech/codex-docker:${CODEX_VERSION}
docker pull ghcr.io/icoretech/codex-docker:latest
```

You can find available tags on the [GitHub Packages page](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker).
Use `${CODEX_VERSION}` for reproducible deployments and `latest` as a convenience tag for quick trials.

The image defaults to plain `codex`, so the caller decides what to run:

```bash
docker run --rm -it ghcr.io/icoretech/codex-docker:${CODEX_VERSION} --help
docker run --rm -it ghcr.io/icoretech/codex-docker:${CODEX_VERSION} exec --help
docker run --rm -i ghcr.io/icoretech/codex-docker:${CODEX_VERSION} mcp-server
docker run --rm -it ghcr.io/icoretech/codex-docker:${CODEX_VERSION} remote-control --help
```

Persist Codex state across runs by mounting `CODEX_HOME`:

```bash
mkdir -p ./.codex

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION}
```

Use the helper for login-oriented container flows:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY=sk-... \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} codex-bootstrap api-key-login

docker run --rm -it \
  -e CODEX_ACCESS_TOKEN=at-... \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} codex-bootstrap access-token-login

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} codex-bootstrap status
```

For trusted enterprise automation, Codex access tokens can also be provided
ephemerally without writing auth state:

```bash
docker run --rm -it \
  -e CODEX_ACCESS_TOKEN=at-... \
  -v "$PWD:/workspace" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} \
  exec --skip-git-repo-check --ephemeral -C /workspace "summarize this workspace"
```

Use Platform API keys for general API-backed automation. Use Codex access
tokens when a trusted script or private runner needs ChatGPT workspace identity,
ChatGPT-managed Codex entitlements, or enterprise workspace controls.

### Remote control and app-server

`codex remote-control` starts Codex's headless app-server path with remote
control enabled for remote Codex clients. The foreground command uses a private
local Unix socket internally; it does not publish the `4500` websocket port shown
by the separate app-server example below.

Use it after logging in with ChatGPT, device auth, or a Codex access token and
persisting `CODEX_HOME`:

```bash
mkdir -p ./.codex

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  -v "$PWD:/workspace" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} remote-control
```

For a local websocket app-server that another Codex CLI can attach to, choose an
explicit port and bind it deliberately. Loopback-only binding is the safest local
development default. Because the container listens on `0.0.0.0`, current Codex
requires websocket auth even when Docker publishes the port only on host
loopback:

```bash
CODEX_REMOTE_AUTH_TOKEN=codex-local-dev-token

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  -v "$PWD:/workspace" \
  -p 127.0.0.1:4500:4500 \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} \
  app-server --listen ws://0.0.0.0:4500 \
  --ws-auth capability-token \
  --ws-token-sha256 a06a3642fee0991ee64f032f46306795f2bdcdb5396d5c887b37b0b120220328

CODEX_REMOTE_AUTH_TOKEN="$CODEX_REMOTE_AUTH_TOKEN" \
  codex --remote ws://127.0.0.1:4500 \
  --remote-auth-token-env CODEX_REMOTE_AUTH_TOKEN
```

Do not expose unauthenticated websocket listeners on public interfaces. For real
shared or non-loopback listeners, prefer SSH port forwarding, TLS behind a
trusted proxy, or Codex websocket auth with a secret-backed
`--ws-token-file`/`--ws-token-sha256` or signed bearer tokens.

## 🧭 Compose Demo

A runnable Compose demo lives at `examples/compose.yml`. It is meant to show
real invocation patterns, not just a YAML skeleton.

Available profiles:

- `cli`: plain interactive `codex`
- `exec`: safe `codex exec` demo using `--skip-git-repo-check`, `--ephemeral`, and `-C /workspace`
- `mcp`: stdio `codex mcp-server`
- `remote-control`: headless `codex remote-control` with persisted `CODEX_HOME`
- `app-server-ws`: authenticated websocket `codex app-server --listen ws://0.0.0.0:4500` bound to `127.0.0.1:4500` on the host
- `native-login-api-key`: built-in `codex login --with-api-key`
- `native-login-access-token`: built-in `codex login --with-access-token`
- `native-login-device`: built-in `codex login --device-auth`
- `native-login-status`: built-in `codex login status`
- `helper-login-api-key`: `codex-bootstrap api-key-login`
- `helper-login-access-token`: `codex-bootstrap access-token-login`
- `helper-login-device`: `codex-bootstrap device-auth`
- `helper-status`: `codex-bootstrap status`

Basic examples:

```bash
docker compose -f examples/compose.yml --profile cli run --rm cli

docker compose -f examples/compose.yml --profile exec run --rm exec

docker compose -f examples/compose.yml --profile mcp run --rm -T mcp mcp-server --help

docker compose -f examples/compose.yml --profile remote-control run --rm remote-control remote-control --help

docker compose -f examples/compose.yml --profile app-server-ws up app-server-ws

CODEX_REMOTE_AUTH_TOKEN=codex-local-dev-token \
  codex --remote ws://127.0.0.1:4500 \
  --remote-auth-token-env CODEX_REMOTE_AUTH_TOKEN

printf '%s\n' "$OPENAI_API_KEY" | \
  docker compose -f examples/compose.yml --profile native-login-api-key run --rm -T native-login-api-key

printf '%s\n' "$CODEX_ACCESS_TOKEN" | \
  docker compose -f examples/compose.yml --profile native-login-access-token run --rm -T native-login-access-token

docker compose -f examples/compose.yml --profile native-login-device run --rm native-login-device

docker compose -f examples/compose.yml --profile helper-login-api-key run --rm helper-login-api-key

docker compose -f examples/compose.yml --profile helper-login-access-token run --rm helper-login-access-token
```

Notes:

- all profiles share the same named `codex_home` volume, so login state persists across runs
- `mcp-server` is stdio-only, so use `-T` when you want a clean non-TTY stream; drop `--help` when wiring it to a real MCP client
- `remote-control` is headless and long-running; it does not open the `4500` websocket port shown by the separate `app-server-ws` profile
- `app-server-ws` binds container port `4500` to host loopback only and uses the demo capability token `codex-local-dev-token`; replace it with a real secret for anything shared
- `native-login-api-key` and `native-login-access-token` read secrets from stdin
- `helper-login-api-key` reads `OPENAI_API_KEY` or `CODEX_OPENAI_API_KEY` from the environment, while `helper-login-access-token` reads `CODEX_ACCESS_TOKEN`
- the `exec` profile intentionally demonstrates the common container flags you usually want outside a checked-out Git repo
- set `CODEX_IMAGE=codex-docker:local` if you want to exercise a locally built image with the same Compose file
- `examples/workspace/` is bind-mounted as `/workspace`; put a real repo there before replacing the demo `exec --help` with an actual prompt

## 🧪 Local Verification

```bash
docker build -t codex-docker:local .
IMAGE=codex-docker:local ./scripts/smoke-test.sh
act pull_request --container-architecture linux/amd64 -W .github/workflows/build.yml
```

## 📄 License

The Docker image packaging in this repository is provided as project automation around the upstream Codex CLI.
Please review the upstream [OpenAI Codex repository](https://github.com/openai/codex) and its license/terms before redistributing or deploying the packaged software.
