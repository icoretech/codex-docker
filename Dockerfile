FROM alpine:3.23.3 AS downloader

ARG TARGETARCH
# renovate: datasource=github-releases depName=openai/codex versioning=regex:^rust-v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
ARG CODEX_RELEASE_TAG=rust-v0.152.0

RUN apk add --no-cache ca-certificates curl jq tar

RUN case "${TARGETARCH:-}" in \
      ""|amd64) \
        asset="codex-x86_64-unknown-linux-musl.tar.gz" \
        binary="codex-x86_64-unknown-linux-musl" \
        host_asset="codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz" \
        host_binary="codex-code-mode-host-x86_64-unknown-linux-musl" \
        ;; \
      arm64) \
        asset="codex-aarch64-unknown-linux-musl.tar.gz" \
        binary="codex-aarch64-unknown-linux-musl" \
        host_asset="codex-code-mode-host-aarch64-unknown-linux-musl.tar.gz" \
        host_binary="codex-code-mode-host-aarch64-unknown-linux-musl" \
        ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && release_url="https://api.github.com/repos/openai/codex/releases/tags/${CODEX_RELEASE_TAG}" \
 && curl -fsSL -H "Accept: application/vnd.github+json" "$release_url" -o /tmp/release.json \
 && digest="$(jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest' /tmp/release.json)" \
 && host_digest="$(jq -r --arg asset "$host_asset" '.assets[] | select(.name == $asset) | .digest' /tmp/release.json)" \
 && [ -n "$digest" ] \
 && [ "$digest" != "null" ] \
 && [ -n "$host_digest" ] \
 && [ "$host_digest" != "null" ] \
 && curl -fsSL "https://github.com/openai/codex/releases/download/${CODEX_RELEASE_TAG}/${asset}" -o /tmp/codex.tar.gz \
 && printf '%s  %s\n' "${digest#sha256:}" "/tmp/codex.tar.gz" > /tmp/codex.tar.gz.sha256 \
 && sha256sum -c /tmp/codex.tar.gz.sha256 \
 && tar -xzf /tmp/codex.tar.gz -C /tmp \
 && mv "/tmp/${binary}" /tmp/codex \
 && chmod +x /tmp/codex \
 && curl -fsSL "https://github.com/openai/codex/releases/download/${CODEX_RELEASE_TAG}/${host_asset}" -o /tmp/codex-code-mode-host.tar.gz \
 && printf '%s  %s\n' "${host_digest#sha256:}" "/tmp/codex-code-mode-host.tar.gz" > /tmp/codex-code-mode-host.tar.gz.sha256 \
 && sha256sum -c /tmp/codex-code-mode-host.tar.gz.sha256 \
 && tar -xzf /tmp/codex-code-mode-host.tar.gz -C /tmp \
 && mv "/tmp/${host_binary}" /tmp/codex-code-mode-host \
 && chmod +x /tmp/codex-code-mode-host

FROM alpine:3.23.3

RUN apk add --no-cache \
    bash \
    bubblewrap \
    ca-certificates \
    git \
    openssh-client \
    ripgrep \
 && adduser -D -h /home/codex codex \
 && mkdir -p /home/codex/.codex /workspace \
 && chown -R codex:codex /home/codex /workspace

LABEL org.opencontainers.image.source="https://github.com/icoretech/codex-docker" \
      org.opencontainers.image.description="Multi-arch OpenAI Codex CLI Docker image built from official upstream releases"

COPY --from=downloader /tmp/codex /usr/local/bin/codex
COPY --from=downloader /tmp/codex-code-mode-host /usr/local/bin/codex-code-mode-host
COPY scripts/codex-bootstrap /usr/local/bin/codex-bootstrap
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/codex /usr/local/bin/codex-code-mode-host /usr/local/bin/codex-bootstrap /usr/local/bin/docker-entrypoint.sh

USER codex
WORKDIR /workspace

ENV HOME=/home/codex
ENV CODEX_HOME=/home/codex/.codex

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
