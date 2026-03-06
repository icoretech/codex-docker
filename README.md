# 🤖 Codex CLI Multiarch Docker Image

[![Build](https://github.com/icoretech/codex-docker/actions/workflows/build.yml/badge.svg)](https://github.com/icoretech/codex-docker/actions/workflows/build.yml)
[![Publish](https://github.com/icoretech/codex-docker/actions/workflows/publish.yml/badge.svg)](https://github.com/icoretech/codex-docker/actions/workflows/publish.yml)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](https://app.renovatebot.com/dashboard#github/icoretech/codex-docker)
[![GHCR](https://img.shields.io/badge/ghcr-codex--docker-blue?logo=docker)](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker)

This repository hosts an automated build system for creating 🐳 Docker images of the official [OpenAI Codex CLI](https://github.com/openai/codex).
The built AMD64/ARM64 Docker images are published to GHCR with semantic tagging that mirrors the upstream Codex release version.

## 📖 Overview

The build system pins an upstream Codex release tag in `Dockerfile` via `ARG CODEX_RELEASE_TAG` and downloads the official Linux musl release assets from `openai/codex`.
Version bumps are managed through Renovate pull requests, and the publish workflow tags the Docker image with the matching Codex CLI version.

Image characteristics:

- multi-arch: `linux/amd64`, `linux/arm64`
- default runtime behaves like plain `codex`
- runs as a non-root user
- persistent config/auth/log state lives under `CODEX_HOME`
- includes an opt-in `codex-bootstrap` helper for login-oriented container flows

## 💡 Usage

Set a version once and reuse it in the examples below:

```bash
# renovate: datasource=github-releases depName=openai/codex extractVersion=^rust-v(?<version>.+)$
CODEX_VERSION=0.111.0
```

Pull the image:

```bash
docker pull ghcr.io/icoretech/codex-docker:${CODEX_VERSION}
```

You can find available tags on the [GitHub Packages page](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker).

The image defaults to plain `codex`, so the caller decides what to run:

```bash
docker run --rm -it ghcr.io/icoretech/codex-docker:${CODEX_VERSION} --help
docker run --rm -it ghcr.io/icoretech/codex-docker:${CODEX_VERSION} exec --help
docker run --rm -i ghcr.io/icoretech/codex-docker:${CODEX_VERSION} mcp-server
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
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:${CODEX_VERSION} codex-bootstrap status
```

## 🧭 Compose Demo

A runnable Compose demo lives at `examples/compose.yml`. It is meant to show
real invocation patterns, not just a YAML skeleton.

Available profiles:

- `cli`: plain interactive `codex`
- `exec`: safe `codex exec` demo using `--skip-git-repo-check`, `--ephemeral`, and `-C /workspace`
- `mcp`: stdio `codex mcp-server`
- `native-login-api-key`: built-in `codex login --with-api-key`
- `native-login-device`: built-in `codex login --device-auth`
- `native-login-status`: built-in `codex login status`
- `helper-login-api-key`: `codex-bootstrap api-key-login`
- `helper-login-device`: `codex-bootstrap device-auth`
- `helper-status`: `codex-bootstrap status`

Basic examples:

```bash
docker compose -f examples/compose.yml --profile cli run --rm cli

docker compose -f examples/compose.yml --profile exec run --rm exec

docker compose -f examples/compose.yml --profile mcp run --rm -T mcp mcp-server --help

printf '%s\n' "$OPENAI_API_KEY" | \
  docker compose -f examples/compose.yml --profile native-login-api-key run --rm -T native-login-api-key

docker compose -f examples/compose.yml --profile native-login-device run --rm native-login-device

docker compose -f examples/compose.yml --profile helper-login-api-key run --rm helper-login-api-key
```

Notes:

- all profiles share the same named `codex_home` volume, so login state persists across runs
- `mcp-server` is stdio-only, so use `-T` when you want a clean non-TTY stream; drop `--help` when wiring it to a real MCP client
- `native-login-api-key` reads the key from stdin, while `helper-login-api-key` reads `OPENAI_API_KEY` or `CODEX_OPENAI_API_KEY` from the environment
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
