#!/usr/bin/env bash
# Checks a built image. A tier is a set of check functions sharing a prefix,
# each named after the checklist box it replaces. Every check runs, a summary
# prints at the end, and any failure makes the exit code non-zero.
set -uo pipefail

image="${1:?usage: test.sh <image>}"
failed=()
passed=()

in_image() {
    podman run --rm "$image" "$@"
}

static_lint() {
    in_image bootc container lint --fatal-warnings
}

run_tier() {
    local check
    for check in $(compgen -A function "$1_"); do
        echo "=== ${check}"
        if "$check"; then
            passed+=("$check")
        else
            failed+=("$check")
        fi
    done
}

run_tier static

echo
echo "=== summary: ${#passed[@]} passed, ${#failed[@]} failed"
for check in "${passed[@]}"; do echo "PASS ${check}"; done
for check in "${failed[@]}"; do echo "FAIL ${check}"; done
((${#failed[@]} == 0))
