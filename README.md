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

Pull the image:

```bash
docker pull ghcr.io/icoretech/codex-docker:<tag>
```

Replace `<tag>` with a Codex CLI version such as `0.111.0`.

You can find available tags on the [GitHub Packages page](https://github.com/icoretech/codex-docker/pkgs/container/codex-docker).

The image defaults to plain `codex`, so the caller decides what to run:

```bash
docker run --rm -it ghcr.io/icoretech/codex-docker:0.111.0 --help
docker run --rm -it ghcr.io/icoretech/codex-docker:0.111.0 exec --help
docker run --rm -i ghcr.io/icoretech/codex-docker:0.111.0 mcp-server
```

Persist Codex state across runs by mounting `CODEX_HOME`:

```bash
mkdir -p ./.codex

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:0.111.0
```

Use the helper for login-oriented container flows:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY=sk-... \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:0.111.0 codex-bootstrap api-key-login

docker run --rm -it \
  -e CODEX_HOME=/home/codex/.codex \
  -v "$PWD/.codex:/home/codex/.codex" \
  ghcr.io/icoretech/codex-docker:0.111.0 codex-bootstrap status
```

## 🧪 Local Verification

```bash
docker build -t codex-docker:local .
IMAGE=codex-docker:local ./scripts/smoke-test.sh
act pull_request --container-architecture linux/amd64 -W .github/workflows/build.yml
```

## 📄 License

The Docker image packaging in this repository is provided as project automation around the upstream Codex CLI.
Please review the upstream [OpenAI Codex repository](https://github.com/openai/codex) and its license/terms before redistributing or deploying the packaged software.
