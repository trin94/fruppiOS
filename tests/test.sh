#!/usr/bin/env bash
# Checks a built image. A tier is a set of check functions sharing a prefix,
# each named after the checklist box it replaces. Every check runs, a summary
# prints at the end, and any failure makes the exit code non-zero.
set -uo pipefail

image="${1:?usage: test.sh <image>}"
vm="fruppios-test-$$"
failed=()
passed=()
skipped=()

in_image() {
    podman run --rm "$image" "$@"
}

in_vm() {
    bcvk libvirt ssh "$vm" -- "$@"
}

static_lint() {
    in_image bootc container lint --fatal-warnings
}

boot_no_failed_units() {
    local units unit broken=()
    units=$(in_vm systemctl --failed --no-legend --plain) || return
    [[ -n $units ]] || return 0
    mapfile -t units < <(awk '{print $1}' <<<"$units")
    for unit in "${units[@]}"; do
        in_vm journalctl --boot --no-pager --unit "$unit"
        if [[ $unit == mcelog.service ]]; then
            # hardware error logging, it fails in the VM on some CI runners and not on others
            echo "ignored ${unit}, it depends on the VM's CPU"
        else
            broken+=("$unit")
        fi
    done
    ((${#broken[@]} == 0)) || { echo "failed units: ${broken[*]}"; return 1; }
}

missing_vm_tools() {
    local tool
    for tool in bcvk virsh; do
        command -v "$tool" >/dev/null || echo "$tool"
    done
    [[ -r /dev/kvm && -w /dev/kvm ]] || echo /dev/kvm
}

# bcvk installs from containers-storage and can't resolve a manifest list,
# podman resolves it to the image for this platform
start_vm() {
    local platform_image
    platform_image=$(podman image inspect --format '{{index .RepoTags 0}}' "$image") || return
    bcvk libvirt run --name "$vm" --replace --detach --ssh-wait \
        --filesystem btrfs --disk-size 30G "$platform_image"
}

stop_vm() {
    bcvk libvirt rm --force "$vm" >/dev/null 2>&1
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

missing=$(missing_vm_tools)
if [[ -n $missing ]]; then
    echo "boot tier needs: ${missing//$'\n'/ }"
    if [[ ${CI:-} == true ]]; then
        failed+=(boot_prerequisites)
    else
        echo "install with: rpm-ostree install bcvk libvirt-daemon-kvm libvirt-client"
        skipped+=(boot)
    fi
else
    trap stop_vm EXIT
    trap 'exit 130' INT TERM
    echo "=== starting VM ${vm}"
    if start_vm; then
        run_tier boot
    else
        failed+=(boot_vm_start)
    fi
fi

echo
echo "=== summary: ${#passed[@]} passed, ${#failed[@]} failed, ${#skipped[@]} skipped"
for check in "${passed[@]}"; do echo "PASS ${check}"; done
for check in "${failed[@]}"; do echo "FAIL ${check}"; done
for tier in "${skipped[@]}"; do echo "SKIPPED ${tier} tier"; done
((${#failed[@]} == 0))
