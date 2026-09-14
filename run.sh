#!/usr/bin/env bash

set -euo pipefail

readonly script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly image="${GEMINI_DOCKER_IMAGE:-zeebote/gemini-cli-docker-mcp:latest}"
readonly docker_socket="${DOCKER_HOST_SOCKET:-${HOME}/.docker/run/docker.sock}"
workspace="${GEMINI_WORKSPACE:-${HOME}/gemini/workspace}"

expand_home_directory() {
    case "$1" in
        "~")
            printf '%s\n' "${HOME}"
            ;;
        "~/"*)
            printf '%s/%s\n' "${HOME}" "${1#\~/}"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

profile_file="${DOCKER_MCP_PROFILE_FILE:-${script_directory}/profile.yaml}"
environment_file="${DOCKER_MCP_ENV_FILE:-${script_directory}/profile.env}"
gemini_directory="${GEMINI_HOST_DIR:-${script_directory}/.gemini}"
profile_id="${DOCKER_MCP_PROFILE_ID:-}"
debug="${DOCKER_MCP_DEBUG:-false}"

while (($# > 0)); do
    case "$1" in
        --debug)
            debug=true
            shift
            ;;
        debug=*)
            debug="${1#debug=}"
            shift
            ;;
        profile_file=*)
            profile_file="$(expand_home_directory "${1#profile_file=}")"
            shift
            ;;
        environment_file=*)
            environment_file="$(expand_home_directory "${1#environment_file=}")"
            shift
            ;;
        enviroment_file=*)
            echo "Warning: use environment_file instead of enviroment_file." >&2
            environment_file="$(expand_home_directory "${1#enviroment_file=}")"
            shift
            ;;
        gemini_directory=*)
            gemini_directory="$(expand_home_directory "${1#gemini_directory=}")"
            shift
            ;;
        profile_id=*)
            profile_id="${1#profile_id=}"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

case "${debug}" in
    true | false)
        ;;
    *)
        echo "debug must be true or false." >&2
        exit 1
        ;;
esac

readonly profile_file
readonly environment_file
readonly gemini_directory
readonly debug

if [[ ! -r "${profile_file}" ]]; then
    echo "Docker MCP profile is not readable: ${profile_file}" >&2
    exit 1
fi

if [[ ! -r "${environment_file}" ]]; then
    echo "Docker MCP environment file is not readable: ${environment_file}" >&2
    exit 1
fi

if [[ -z "${profile_id}" ]]; then
    profile_id="$(
        awk '
            /^id:[[:space:]]*/ {
                sub(/^id:[[:space:]]*/, "")
                gsub(/^["\047]|["\047]$/, "")
                print
                exit
            }
        ' "${profile_file}"
    )"
fi

if [[ -z "${profile_id}" ]]; then
    echo "Docker MCP profile ID is missing from ${profile_file}." >&2
    exit 1
fi

readonly profile_id

if [[ ! -S "${docker_socket}" ]]; then
    echo "Docker socket not found: ${docker_socket}" >&2
    exit 1
fi

mkdir -p "${gemini_directory}" "${workspace}"

tty_arguments=()
if [[ -t 0 && -t 1 ]]; then
    tty_arguments=(-it)
else
    tty_arguments=(-i)
fi

exec docker run \
    "${tty_arguments[@]}" \
    --rm \
    --cap-drop=ALL \
    --cap-add=CHOWN \
    --cap-add=SETGID \
    --cap-add=SETUID \
    --security-opt=no-new-privileges \
    --pids-limit=256 \
    --user=0:0 \
    --volume="${workspace}:/home/gemini/workspace" \
    --volume="${gemini_directory}:/home/gemini/.gemini" \
    --volume="${profile_file}:/run/gemini-mcp/profile.yaml:ro" \
    --volume="${environment_file}:/run/gemini-mcp/profile.env:ro" \
    --volume="${docker_socket}:/var/run/docker.sock" \
    --env="DEFAULT_UID=$(id -u)" \
    --env="DEFAULT_GID=$(id -g)" \
    --env="TERM=${TERM:-xterm-256color}" \
    --env="COLORTERM=${COLORTERM:-truecolor}" \
    --env="DOCKER_MCP_PROFILE_ID=${profile_id}" \
    --env="DOCKER_MCP_DEBUG=${debug}" \
    "${image}" \
    "$@"
