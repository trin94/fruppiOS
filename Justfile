bluebuild_image := "ghcr.io/blue-build/cli:v0.9.37"
prek := "prek@0.5.5"
recipe := "recipes/recipe.yml"

alias fmt := format

[private]
default:
    @just --list

# Build the recipe with the BlueBuild CLI container, driving the maintainer's podman over its socket
build:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user start podman.socket
    sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
    podman run --rm --pull missing \
        --security-opt label=disable \
        -v "{{ justfile_directory() }}:/bluebuild" \
        -w /bluebuild \
        -v "${sock}:/run/podman/podman.sock" \
        -e CONTAINER_HOST=unix:///run/podman/podman.sock \
        "{{ bluebuild_image }}" \
        bluebuild build --build-driver podman --run-driver podman "{{ recipe }}"

# Run the checks against a built image, for example localhost/fruppios:latest
test image:
    tests/test.sh "{{ image }}"

# Format and lint the whole repo with prek
format *args:
    uvx {{ prek }} --config .config/prek.toml run --all-files {{ args }}

# Bump the revision of every hook
update-git-hook-dependencies:
    uvx {{ prek }} --config .config/prek.toml update
