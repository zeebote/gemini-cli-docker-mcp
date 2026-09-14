#!/usr/bin/env python3

import argparse
import copy
import os
import re
from pathlib import Path

import yaml


TEMPLATE_PATTERN = re.compile(r"^\{\{\s*([^{}]+?)\s*\}\}$")


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True)
    parser.add_argument("--expected-profile-id")
    parser.add_argument("--mcp-home", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--secrets-file", required=True)
    return parser.parse_args()


def read_environment(path):
    values = {}
    with Path(path).open(encoding="utf-8") as environment_file:
        for line_number, raw_line in enumerate(environment_file, start=1):
            line = raw_line.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:]
            if "=" not in line:
                raise ValueError(
                    f"Invalid environment assignment on line {line_number}."
                )
            name, value = line.split("=", 1)
            name = name.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.\-/]*", name):
                raise ValueError(
                    f"Invalid environment name on line {line_number}: {name}"
                )
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            if "\n" in value or "\r" in value:
                raise ValueError(f"Multiline value on line {line_number}.")
            values[name] = value
    return values


def merge_mapping(destination, source):
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(destination.get(key), dict):
            merge_mapping(destination[key], value)
        else:
            destination[key] = copy.deepcopy(value)


def set_nested_value(destination, dotted_key, value):
    keys = dotted_key.split(".")
    current = destination
    for key in keys[:-1]:
        current = current.setdefault(key, {})
        if not isinstance(current, dict):
            raise ValueError(f"Configuration path is not an object: {dotted_key}")
    current[keys[-1]] = value


def write_yaml(path, value):
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8") as output_file:
        yaml.safe_dump(value, output_file, sort_keys=False)


def write_secrets(path, values):
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(
        destination,
        os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
        0o600,
    )
    with os.fdopen(descriptor, "w", encoding="utf-8") as output_file:
        for name in sorted(values):
            output_file.write(f"{name}={values[name]}\n")
    destination.chmod(0o600)


def build_runtime(profile, environment):
    registry = {}
    configuration = {}
    secrets = {
        name: value
        for name, value in environment.items()
        if "." in name or "/" in name
    }
    server_names = []

    for profile_server in profile.get("servers", []):
        snapshot = profile_server.get("snapshot", {}).get("server")
        if not isinstance(snapshot, dict):
            raise ValueError("Every profile server must contain a server snapshot.")

        server = copy.deepcopy(snapshot)
        server_name = server.get("name")
        if not isinstance(server_name, str) or not server_name:
            raise ValueError("Every profile server snapshot must have a name.")

        server_names.append(server_name)
        server.pop("name", None)

        server_configuration = profile_server.get("config", {})
        if server_configuration:
            destination = configuration.setdefault(server_name, {})
            merge_mapping(destination, server_configuration)

        for secret in server.get("secrets", []):
            secret_name = secret.get("name")
            environment_name = secret.get("env")
            if not secret_name or not environment_name:
                continue
            secrets[secret_name] = environment.get(environment_name, "")

        oauth = server.get("oauth", {})
        oauth_from_environment = False
        for provider in oauth.get("providers", []):
            secret_name = provider.get("secret")
            environment_name = provider.get("env")
            if secret_name and environment_name and environment_name in environment:
                secrets[secret_name] = environment[environment_name]
                oauth_from_environment = True
        if oauth_from_environment:
            server.pop("oauth", None)

        for environment_entry in server.get("env", []):
            environment_name = environment_entry.get("name")
            configured_value = environment_entry.get("value")
            if environment_name not in environment:
                continue
            if not isinstance(configured_value, str):
                continue
            template_match = TEMPLATE_PATTERN.fullmatch(configured_value)
            if template_match:
                set_nested_value(
                    configuration,
                    template_match.group(1),
                    environment[environment_name],
                )

        registry[server_name] = server

    kubernetes_config_path = os.environ.get("KUBERNETES_CONFIG_PATH")
    if kubernetes_config_path:
        set_nested_value(
            configuration,
            "kubernetes.config_path",
            kubernetes_config_path,
        )

    return registry, configuration, secrets, server_names


def main():
    arguments = parse_arguments()
    environment = read_environment(arguments.environment)

    with Path(arguments.profile).open(encoding="utf-8") as profile_file:
        profile = yaml.safe_load(profile_file)
    if not isinstance(profile, dict):
        raise ValueError("The Docker MCP profile must be a YAML object.")

    profile_id = profile.get("id")
    if arguments.expected_profile_id and profile_id != arguments.expected_profile_id:
        raise ValueError(
            f"Expected profile {arguments.expected_profile_id}, found {profile_id}."
        )

    registry, configuration, secrets, server_names = build_runtime(
        profile,
        environment,
    )
    if not server_names:
        raise ValueError("The Docker MCP profile does not contain any servers.")

    mcp_home = Path(arguments.mcp_home)
    write_yaml(mcp_home / "catalogs" / "profile.yaml", {"registry": registry})
    write_yaml(mcp_home / "config.yaml", configuration)
    (mcp_home / "servers").write_text(
        ",".join(server_names),
        encoding="utf-8",
    )
    write_secrets(arguments.secrets_file, secrets)


if __name__ == "__main__":
    main()
