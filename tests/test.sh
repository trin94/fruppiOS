#!/usr/bin/env bash
# Checks a built image. A tier is a set of check functions sharing a prefix,
# each named after the checklist box it replaces. Every check runs, a summary
# prints at the end, and any failure makes the exit code non-zero.
set -uo pipefail

image="${1:?usage: test.sh <image>}"
vm="fruppios-test-$$"
account=fruppi-test
failed=()
passed=()
skipped=()

in_image() {
    podman run --rm "$image" "$@"
}

in_vm() {
    bcvk libvirt ssh "$vm" -- "$@"
}

# a login shell over ssh is a real login, it starts the account's user manager,
# and it starts in the account's home
as_account() {
    bcvk libvirt ssh --user "$account" "$vm" -- bash -lc "$*"
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

boot_no_avc_denials() {
    local denials
    # ausearch exits 1 both for no matches and for errors, its output tells them apart
    denials=$(in_vm sh -c 'ausearch --message AVC,USER_AVC,SELINUX_ERR --start boot 2>&1 || true')
    [[ $denials == "<no matches>" ]] && return
    echo "$denials"
    return 1
}

boot_nix_socket() {
    local ok=0
    expect nix.mount active "$(in_vm systemctl is-active nix.mount)" || ok=1
    expect nix-daemon.socket active "$(in_vm systemctl is-active nix-daemon.socket)" || ok=1
    expect "label type of the daemon socket" var_run_t \
        "$(in_vm stat -c %C /nix/var/nix/daemon-socket/socket | cut -d: -f3)" || ok=1
    return "$ok"
}

boot_inotify() {
    local ok=0
    expect fs.inotify.max_user_watches 1048576 "$(in_vm sysctl -n fs.inotify.max_user_watches)" || ok=1
    expect fs.inotify.max_user_instances 1024 "$(in_vm sysctl -n fs.inotify.max_user_instances)" || ok=1
    return "$ok"
}

boot_update_policy() {
    local ok=0
    expect rpm-ostreed-automatic.timer enabled "$(in_vm systemctl is-enabled rpm-ostreed-automatic.timer)" || ok=1
    expect rpm-ostreed-automatic.timer active "$(in_vm systemctl is-active rpm-ostreed-automatic.timer)" || ok=1
    return "$ok"
}

boot_greeter() {
    expect greetd.service active "$(in_vm systemctl is-active greetd.service)"
}

boot_no_remotes() {
    expect "system flatpak remotes" "" "$(in_vm flatpak remotes --system --show-disabled)"
}

boot_first_steps_new_account() {
    local ok=0 file uid
    for file in fruppiOS-first-steps.txt .local/state/fruppios/first-steps; do
        expect "~${account}/${file}" present "$(as_account test -f "$file" && echo present || echo absent)" || ok=1
    done
    # every ssh login so far started the user manager again, the unit still ran only once.
    # root's ssh logins start a user manager too, so the unit also runs for root
    uid=$(in_vm id -u "$account")
    expect "successful runs of fruppios-first-steps.service" 1 "$(in_vm journalctl --boot --output cat \
        "_UID=${uid}" USER_UNIT=fruppios-first-steps.service | grep -c '^Finished ')" || ok=1
    return "$ok"
}

# goes to cache.nixos.org, so a failure gets a second try before it counts
nix_hello() {
    expect "nix shell nixpkgs#hello" "Hello, world!" "$(as_account nix shell nixpkgs#hello --command hello)" &&
        return
    echo "retrying once"
    expect "nix shell nixpkgs#hello" "Hello, world!" "$(as_account nix shell nixpkgs#hello --command hello)"
}

boot_first_nix_shell() {
    nix_hello
}

reboot_persistence() {
    local ok=0 hello
    hello=$(as_account cat nix-hello-path)
    expect "${hello}/bin/hello" "Hello, world!" "$(as_account "${hello}/bin/hello")" || ok=1
    expect "~${account}/marker" "fruppiOS marker" "$(as_account cat marker)" || ok=1
    nix_hello || ok=1
    return "$ok"
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

# an unprivileged account that logs in with root's bcvk key and hasn't logged in yet
add_account() {
    in_vm useradd --create-home "$account" &&
        in_vm sh -c "install -d -m 700 -o ${account} -g ${account} ~${account}/.ssh &&
            install -m 600 -o ${account} -g ${account} /root/.ssh/authorized_keys ~${account}/.ssh/ &&
            restorecon -R ~${account}/.ssh"
}

# leaves a marker and the store path of hello in the account's home for the
# reboot checks, then reboots the installed disk and waits for the new boot
restart_vm() {
    local before after
    as_account 'printf "fruppiOS marker\n" >marker'
    as_account 'nix build --no-link --print-out-paths nixpkgs#hello >nix-hello-path' ||
        as_account 'nix build --no-link --print-out-paths nixpkgs#hello >nix-hello-path'
    before=$(in_vm cat /proc/sys/kernel/random/boot_id) || return
    # the ssh connection drops with the reboot
    in_vm systemctl reboot >/dev/null 2>&1 || true
    # each ssh waits up to a minute for the VM to answer, the boot ID tells the new boot from the old one
    for _ in 1 2 3 4 5; do
        after=$(in_vm cat /proc/sys/kernel/random/boot_id)
        [[ -n $after && $after != "$before" ]] && return
        sleep 10
    done
    echo "VM didn't come back after the reboot"
    return 1
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
    if ! start_vm; then
        failed+=(boot_vm_start)
    elif ! add_account; then
        failed+=(boot_account)
    else
        run_tier boot
        echo "=== rebooting VM ${vm}"
        if restart_vm; then
            run_tier reboot
        else
            failed+=(reboot_vm)
        fi
    fi
fi

echo
echo "=== summary: ${#passed[@]} passed, ${#failed[@]} failed, ${#skipped[@]} skipped"
for check in "${passed[@]}"; do echo "PASS ${check}"; done
for check in "${failed[@]}"; do echo "FAIL ${check}"; done
for tier in "${skipped[@]}"; do echo "SKIPPED ${tier} tier"; done
((${#failed[@]} == 0))
