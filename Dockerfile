FROM alpine:3.24.1 AS downloader

ARG TARGETARCH
# renovate: datasource=github-releases depName=openai/codex versioning=regex:^rust-v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
ARG CODEX_RELEASE_TAG=rust-v0.166.0

RUN apk add --no-cache ca-certificates curl jq tar

RUN case "${TARGETARCH:-}" in \
      ""|amd64) \
        target="x86_64-unknown-linux-musl" \
        ;; \
      arm64) \
        target="aarch64-unknown-linux-musl" \
        ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && asset="codex-package-${target}.tar.gz" \
 && release_url="https://api.github.com/repos/openai/codex/releases/tags/${CODEX_RELEASE_TAG}" \
 && curl -fsSL -H "Accept: application/vnd.github+json" "$release_url" -o /tmp/release.json \
 && digest="$(jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest' /tmp/release.json)" \
 && [ -n "$digest" ] \
 && [ "$digest" != "null" ] \
 && curl -fsSL "https://github.com/openai/codex/releases/download/${CODEX_RELEASE_TAG}/${asset}" -o /tmp/codex.tar.gz \
 && printf '%s  %s\n' "${digest#sha256:}" "/tmp/codex.tar.gz" > /tmp/codex.tar.gz.sha256 \
 && sha256sum -c /tmp/codex.tar.gz.sha256 \
 && mkdir -p /opt/codex \
 && tar -xzf /tmp/codex.tar.gz -C /opt/codex \
 && jq -e --arg version "${CODEX_RELEASE_TAG#rust-v}" --arg target "$target" \
      '.layoutVersion == 1 and .version == $version and .target == $target and .variant == "codex" and .entrypoint == "bin/codex" and .execServer == "bin/codex-exec-server" and .resourcesDir == "codex-resources" and .pathDir == "codex-path"' \
      /opt/codex/codex-package.json \
 && for executable in bin/codex bin/codex-code-mode-host bin/codex-exec-server codex-path/rg codex-resources/bwrap; do \
      test -x "/opt/codex/$executable" || exit 1; \
    done

FROM debian:13.7-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    bubblewrap \
    ca-certificates \
    git \
    openssh-client \
    ripgrep \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --home-dir /home/codex --shell /bin/sh --uid 1000 codex \
 && mkdir -p /home/codex/.codex /workspace \
 && chown -R codex:codex /home/codex /workspace

LABEL org.opencontainers.image.source="https://github.com/icoretech/codex-docker" \
      org.opencontainers.image.description="Multi-arch OpenAI Codex CLI Docker image built from official upstream releases"

COPY --from=downloader /opt/codex /opt/codex
COPY scripts/codex-bootstrap /usr/local/bin/codex-bootstrap
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ln -s /opt/codex/bin/codex /usr/local/bin/codex \
 && ln -s /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host \
 && ln -s /opt/codex/bin/codex-exec-server /usr/local/bin/codex-exec-server \
 && chmod +x /usr/local/bin/codex-bootstrap /usr/local/bin/docker-entrypoint.sh

USER codex
WORKDIR /workspace

ENV HOME=/home/codex
ENV CODEX_HOME=/home/codex/.codex

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
