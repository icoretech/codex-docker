FROM alpine:3.23.3 AS downloader

ARG TARGETARCH
# renovate: datasource=github-releases depName=openai/codex versioning=regex:^rust-v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
ARG CODEX_RELEASE_TAG=rust-v0.125.0

RUN apk add --no-cache ca-certificates curl jq tar

RUN case "${TARGETARCH:-}" in \
      ""|amd64) asset="codex-x86_64-unknown-linux-musl.tar.gz"; binary="codex-x86_64-unknown-linux-musl" ;; \
      arm64) asset="codex-aarch64-unknown-linux-musl.tar.gz"; binary="codex-aarch64-unknown-linux-musl" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && release_url="https://api.github.com/repos/openai/codex/releases/tags/${CODEX_RELEASE_TAG}" \
 && curl -fsSL -H "Accept: application/vnd.github+json" "$release_url" -o /tmp/release.json \
 && digest="$(jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest' /tmp/release.json)" \
 && [ -n "$digest" ] \
 && [ "$digest" != "null" ] \
 && curl -fsSL "https://github.com/openai/codex/releases/download/${CODEX_RELEASE_TAG}/${asset}" -o /tmp/codex.tar.gz \
 && printf '%s  %s\n' "${digest#sha256:}" "/tmp/codex.tar.gz" > /tmp/codex.tar.gz.sha256 \
 && sha256sum -c /tmp/codex.tar.gz.sha256 \
 && tar -xzf /tmp/codex.tar.gz -C /tmp \
 && mv "/tmp/${binary}" /tmp/codex \
 && chmod +x /tmp/codex

FROM alpine:3.23.3

RUN apk add --no-cache \
    bash \
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
COPY scripts/codex-bootstrap /usr/local/bin/codex-bootstrap
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/codex /usr/local/bin/codex-bootstrap /usr/local/bin/docker-entrypoint.sh

USER codex
WORKDIR /workspace

ENV HOME=/home/codex
ENV CODEX_HOME=/home/codex/.codex

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
