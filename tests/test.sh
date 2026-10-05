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

# expect <what> <expected> <found>
expect() {
    [[ "$3" == "$2" ]] && return
    echo "${1}: expected '${2}', found '${3}'"
    return 1
}

static_lint() {
    in_image bootc container lint --fatal-warnings
}

static_fedora() {
    local ok=0
    expect "fedora release" 44 "$(in_image rpm -E '%fedora')" || ok=1
    expect "terra.repo in /etc/yum.repos.d" absent \
        "$(in_image sh -c 'test -e /etc/yum.repos.d/terra.repo && echo present || echo absent')" || ok=1
    return "$ok"
}

static_update_policy() {
    local ok=0
    expect "rpm-ostreed.conf" AutomaticUpdatePolicy=stage \
        "$(in_image grep '^AutomaticUpdatePolicy=' /etc/rpm-ostreed.conf)" || ok=1
    expect rpm-ostreed-automatic.timer enabled "$(in_image systemctl is-enabled rpm-ostreed-automatic.timer)" || ok=1
    expect bootc-fetch-apply-updates.timer masked "$(in_image systemctl is-enabled bootc-fetch-apply-updates.timer)" || ok=1
    return "$ok"
}

static_nix_socket() {
    local ok=0 path
    expect nix.mount enabled "$(in_image systemctl is-enabled nix.mount)" || ok=1
    expect nix-daemon.socket enabled "$(in_image systemctl is-enabled nix-daemon.socket)" || ok=1
    for path in /nix/var/nix/daemon-socket/socket /var/nix/var/nix/daemon-socket/socket; do
        expect "file context type of ${path}" var_run_t \
            "$(in_image matchpathcon -n "$path" | cut -d: -f3)" || ok=1
    done
    return "$ok"
}

static_inotify() {
    local ok=0 key
    for key in fs.inotify.max_user_watches=1048576 fs.inotify.max_user_instances=1024; do
        # the last assignment across all sysctl.d files is the one that applies at boot
        expect "${key%=*}" "${key#*=}" "$(in_image /usr/lib/systemd/systemd-sysctl --cat-config |
            sed -n "s/^${key%=*} *= *//p" | tail -n 1)" || ok=1
    done
    return "$ok"
}

static_first_steps() {
    local ok=0
    expect "global fruppios-first-steps.service" enabled \
        "$(in_image systemctl --global is-enabled fruppios-first-steps.service)" || ok=1
    expect "mode of first-steps.txt" 644 "$(in_image stat -c '%a' /usr/share/doc/fruppios/first-steps.txt)" || ok=1
    return "$ok"
}

static_greeter() {
    expect greetd.service enabled "$(in_image systemctl is-enabled greetd.service)"
}

static_login() {
    expect "global noctalia.service" enabled "$(in_image systemctl --global is-enabled noctalia.service)"
}

static_no_remotes() {
    local ok=0 pkg
    expect "system flatpak remotes" "" "$(in_image flatpak remotes --system --show-disabled)" || ok=1
    expect flatpak-add-fedora-repos.service masked \
        "$(in_image systemctl is-enabled flatpak-add-fedora-repos.service)" || ok=1
    for pkg in fedora-flathub-remote fedora-third-party; do
        expect "package ${pkg}" absent "$(in_image rpm -q --quiet "$pkg" && echo present || echo absent)" || ok=1
    done
    return "$ok"
}

static_packages() {
    local ok=0 pkg
    for pkg in firefox firefox-langpacks alacritty fuzzel swaylock waybar; do
        expect "package ${pkg}" absent "$(in_image rpm -q --quiet "$pkg" && echo present || echo absent)" || ok=1
    done
    for pkg in nix nix-daemon greetd niri noctalia; do
        expect "package ${pkg}" present "$(in_image rpm -q --quiet "$pkg" && echo present || echo absent)" || ok=1
    done
    return "$ok"
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
