#!/bin/sh

set -eu

servers_file="${DOCKER_MCP_HOME}/servers"
if [ ! -s "${servers_file}" ]; then
    echo "Docker MCP server list is empty: ${servers_file}" >&2
    exit 1
fi

set -- gateway run \
    --block-secrets \
    --catalog profile.yaml \
    --config "${DOCKER_MCP_HOME}/config.yaml" \
    --cpus "${DOCKER_MCP_SERVER_CPUS:-1}" \
    --memory "${DOCKER_MCP_SERVER_MEMORY:-2Gb}" \
    --secrets /run/secrets/mcp_secret \
    --servers "$(cat "${servers_file}")" \
    --verify-signatures \
    --watch

if [ "${DOCKER_MCP_DRY_RUN:-false}" = "true" ]; then
    set -- "$@" --dry-run
fi

if [ "${DOCKER_MCP_DEBUG:-false}" = "true" ]; then
    log_file="${DOCKER_MCP_LOG_FILE:-${HOME}/.gemini/docker-mcp-gateway.log}"
    exec /usr/local/bin/docker-mcp "$@" 2>>"${log_file}"
fi

exec /usr/local/bin/docker-mcp "$@" 2>/dev/null
