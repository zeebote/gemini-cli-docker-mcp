FROM docker.io/docker/mcp-gateway:v2@sha256:54dd518ee51b5c4641b02ddd4790b88cc0dafa59d76b6d07bc441d896a23bbea AS mcp_gateway

FROM node:24.20.0-alpine3.24@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf AS builder

ARG GEMINI_CLI_VERSION=0.59.0

RUN apk add --no-cache \
        g++ \
        make \
        python3 \
    && npm install --global \
        --omit=dev \
        --no-audit \
        --no-fund \
        "@google/gemini-cli@${GEMINI_CLI_VERSION}" \
    && gemini --version \
    && npm cache clean --force

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

LABEL org.opencontainers.image.title="Gemini CLI with Docker MCP"
LABEL org.opencontainers.image.description="Hardened Gemini CLI with a runtime-configured Docker MCP Gateway"

RUN apk upgrade --no-cache \
    && apk add --no-cache \
        bash \
        ca-certificates \
        docker-cli \
        git \
        libstdc++ \
        openssh-client \
        py3-yaml \
        python3 \
        su-exec \
        tini \
    && addgroup -g 1000 gemini \
    && adduser -D -H -h /home/gemini -u 1000 -G gemini -s /bin/sh gemini \
    && mkdir -p \
        /etc/gemini-cli \
        /home/gemini/.docker/mcp \
        /home/gemini/.gemini \
        /home/gemini/workspace \
        /usr/local/lib/docker/cli-plugins \
    && chown -R gemini:gemini /home/gemini

COPY --from=builder /usr/local/bin/node /usr/local/bin/node
COPY --from=builder \
    /usr/local/lib/node_modules/@google/gemini-cli \
    /opt/gemini-cli
COPY --from=mcp_gateway /docker-mcp /usr/local/bin/docker-mcp
COPY etc/gemini-cli/settings.json /etc/gemini-cli/settings.json
COPY bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY bin/docker-mcp-gateway.sh /usr/local/bin/docker-mcp-gateway.sh
COPY bin/prepare-mcp-runtime.py /usr/local/bin/prepare-mcp-runtime.py

RUN ln -s /usr/local/bin/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp \
    && chmod 0444 /etc/gemini-cli/settings.json \
    && chmod 0555 \
        /usr/local/bin/docker-entrypoint.sh \
        /usr/local/bin/docker-mcp \
        /usr/local/bin/docker-mcp-gateway.sh \
        /usr/local/bin/prepare-mcp-runtime.py

ENV DEBUG=false \
    DOCKER_MCP_HOME=/home/gemini/.docker/mcp \
    DOCKER_MCP_ENV_FILE=/run/gemini-mcp/profile.env \
    DOCKER_MCP_IN_CONTAINER=1 \
    DOCKER_MCP_PROFILE_FILE=/run/gemini-mcp/profile.yaml \
    DOCKER_MCP_PROFILE_ID=dev_workflow \
    GEMINI_CLI_SYSTEM_SETTINGS_PATH=/etc/gemini-cli/settings.json \
    HOME=/home/gemini \
    NODE_ENV=production \
    PATH="/usr/local/bin:${PATH}" \
    SHELL=/bin/bash \
    XDG_CACHE_HOME=/tmp/gemini-cache

USER gemini:gemini

WORKDIR /home/gemini/workspace

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
