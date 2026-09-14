#!/bin/sh

set -eu
umask 077

user_id="${DEFAULT_UID:-1000}"
group_id="${DEFAULT_GID:-1000}"
profile_id="${DOCKER_MCP_PROFILE_ID:-devops}"
profile_file="${DOCKER_MCP_PROFILE_FILE:-/run/gemini-mcp/devops-profile.yaml}"
environment_file="${DOCKER_MCP_ENV_FILE:-/run/gemini-mcp/profile.env}"
secrets_file="/run/secrets/mcp_secret"

case "${user_id}:${group_id}" in
    *[!0-9:]* | 0:* | *:0)
        echo "DEFAULT_UID and DEFAULT_GID must be nonzero numeric values." >&2
        exit 1
        ;;
esac

if [ ! -r "${profile_file}" ]; then
    echo "Docker MCP profile is not readable: ${profile_file}" >&2
    exit 1
fi

if [ ! -r "${environment_file}" ]; then
    echo "Docker MCP environment file is not readable: ${environment_file}" >&2
    exit 1
fi

if [ ! -S /var/run/docker.sock ]; then
    echo "Docker socket is not mounted at /var/run/docker.sock." >&2
    exit 1
fi

if ! getent group "${group_id}" >/dev/null 2>&1; then
    addgroup -g "${group_id}" "gemini-${group_id}"
fi

if ! getent passwd "${user_id}" >/dev/null 2>&1; then
    group_name="$(getent group "${group_id}" | cut -d: -f1)"
    adduser \
        -D \
        -H \
        -h "${HOME}" \
        -u "${user_id}" \
        -G "${group_name}" \
        -s /bin/sh \
        "gemini-${user_id}"
fi

socket_group_id="$(stat -c %g /var/run/docker.sock)"
runtime_identity="${user_id}:${socket_group_id}"

mkdir -p /run/secrets
chown "${user_id}:${group_id}" "${HOME}"
chown -R "${user_id}:${socket_group_id}" "${HOME}/.docker"
chown "${user_id}:${socket_group_id}" /run/secrets
su-exec "${runtime_identity}" \
    mkdir -p "${HOME}/.docker/mcp/catalogs"

su-exec "${runtime_identity}" \
    /usr/local/bin/prepare-mcp-runtime.py \
    --environment "${environment_file}" \
    --expected-profile-id "${profile_id}" \
    --mcp-home "${HOME}/.docker/mcp" \
    --profile "${profile_file}" \
    --secrets-file "${secrets_file}"

if [ "${DEBUG:-false}" = "true" ]; then
    echo "Prepared file-based Docker MCP configuration from ${profile_file}."
    echo "Starting Gemini CLI as UID ${user_id}, GID ${socket_group_id}."
fi

exec su-exec "${runtime_identity}" \
    node /opt/gemini-cli/bundle/gemini.js "$@"
