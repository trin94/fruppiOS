# VM acceptance

Two passes, both by hand, each in one sitting.

- **Fresh pass**, sections 1 to 11: a fresh Silverblue 44 VM switches to the image. Run it before the install on your machine and before any change to login, mounts, or updates.
- **Upgrade pass**, section 13: a VM that already runs the image with a populated user environment moves to the next Fedora release. Run it at every major bump, after the new tag passed the fresh pass. The first one comes with the 45 bump.

Every box has to be ticked at the end, except the ones in [Not in the VM](#12-not-in-the-vm). Record the pass in the issue that asked for it, with this table and the four `bootc status` dumps.

| Record | |
| --- | --- |
| Date | |
| Build A digest | |
| Build B digest | |

Setup:

- Silverblue 44 VM, fresh install, 3D acceleration on.
- A disposable USB disk you can attach to the VM.
- Optional: an SMB share the VM can reach, see section 4.
- One test account, `nix-test`. The Home Manager fixture expects that name.

Commands marked **admin** run as the account you created in the Silverblue installer. Everything else runs as `nix-test`, which is in `wheel` like the desktop owner's account will be.

## 1. Switch

**admin**, the same steps the README gives:

```bash
sudo bootc switch ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

After the reboot, **admin**:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

- [ ] **Signed**: the second switch succeeds. The policy and key it checks against come from the image.

After the reboot, **admin**:

```bash
sudo bootc status --json > ~/build-a.json
sudo bootc status
sudo flatpak remote-delete --system fedora           # Silverblue leftovers, VM state only
sudo flatpak remote-delete --system fedora-testing
sudo useradd --create-home nix-test
sudo passwd nix-test
sudo usermod -aG wheel nix-test
rpm -E '%fedora'
ls /etc/yum.repos.d
grep AutomaticUpdatePolicy /etc/rpm-ostreed.conf
systemctl is-enabled rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer
systemctl is-active rpm-ostreed-automatic.timer
systemctl list-timers rpm-ostreed-automatic.timer
systemctl is-active nix.mount nix-daemon.socket
ls -Z /nix/var/nix/daemon-socket/
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances
```

- [ ] **Switch**: `bootc status` shows build A booted with `signature: containerPolicy`. Write the digest into the table above.
- [ ] **Fedora**: `rpm -E '%fedora'` prints `44`. `/etc/yum.repos.d` has no `terra.repo`.
- [ ] **Update policy**: `AutomaticUpdatePolicy=stage`, staging timer `enabled` and `active`, bootc timer `masked`.
- [ ] **Boot check**: `list-timers` shows the next run about 10 minutes after boot. Once it fired, `systemctl show rpm-ostreed-automatic.service -p Result` is `success` and the boot ID is unchanged.
- [ ] **Nix socket**: `nix.mount` and `nix-daemon.socket` are `active`. The socket is labeled `var_run_t`.
- [ ] **inotify**: watches `1048576`, instances `1024`.

## 2. Session

Log in as `nix-test` through the greeter.

- [ ] **Greeter**: shows on boot, no autologin.
- [ ] **Login**: lands in niri with the Noctalia bar.
- [ ] **User dirs**: `ls ~/Documents ~/Downloads ~/Pictures` exist. `systemctl --user status xdg-user-dirs.service` shows it ran.
- [ ] **Bindings**: Super+T opens Ptyxis, Super+D the launcher, Super+Alt+L locks and the password unlocks.
- [ ] **One Noctalia**: `pgrep -a -u "$(id -u)" -x noctalia` shows one process. No second polkit agent or locker.
- [ ] **Logout**: after logout, `pgrep -a -u nix-test -x noctalia` (**admin**, other TTY) prints nothing. Login starts it again.
- [ ] **Mask**: `systemctl --user mask noctalia.service`, relogin, no bar. `systemctl --user unmask noctalia.service`, relogin, bar is back.

Override the niri config and add a binding:

```bash
mkdir -p ~/.config/niri
cp /etc/niri/config.kdl ~/.config/niri/config.kdl
sed -i 's|^    Mod+T hotkey-overlay-title|    Mod+Return { spawn "kitty"; }\n    Mod+T hotkey-overlay-title|' ~/.config/niri/config.kdl
```

- [ ] **niri override**: niri picks up the file without relogin. Super+Return opens kitty. Super+T still opens Ptyxis.

Delete `~/.config/niri` afterwards.

## 3. Flatpak

```bash
flatpak remotes --system --show-disabled
flatpak remotes --user --show-disabled
echo "$XDG_DATA_DIRS"
systemctl --user show-environment | grep '^XDG_DATA_DIRS='
```

- [ ] **No remotes**: both `flatpak remotes` calls print nothing. Without `--show-disabled` a disabled `fedora-testing` would hide.
- [ ] **Data dirs**: `XDG_DATA_DIRS` starts with `~/.local/share/flatpak/exports/share` in the shell and in the user manager.

Open the launcher once and close it. Then:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.gnome.Calculator org.mozilla.firefox
```

- [ ] **Launcher**: without relogin, the launcher lists Calculator and starts it. `flatpak ps` lists it.

Do a calculation and close Calculator, so it has app data.

## 4. Desktop

- [ ] **File chooser**: Ctrl+O in Firefox opens the GNOME file chooser, and the selected file opens.
- [ ] **Screen share**: <https://webrtc.github.io/samples/src/content/getusermedia/getdisplaymedia/> in Firefox shows the niri source picker and a live screen, not a black frame.
- [ ] **Polkit**: `pkexec --disable-internal-agent /usr/bin/id -u` shows one Noctalia prompt and prints `0`.
- [ ] **Trash**: move a file to Trash in Nautilus and restore it.
- [ ] **USB**: attach the USB disk, mount it in Nautilus, browse it, eject it.
- [ ] **Volume**: Noctalia volume and mute change `wpctl get-volume @DEFAULT_AUDIO_SINK@`.
- [ ] **Network**: Noctalia network controls change `nmcli connection show --active`.
- [ ] **Brightness**: Noctalia brightness changes `brightnessctl get`. Skip if the VM has no backlight device, then it's host-only.
- [ ] **Power profile**: switch the profile in Noctalia. `busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile` shows the new one and `tuned-adm active` agrees.

Mount an archive through gvfs:

```bash
printf 'fruppiOS\n' > ~/hello.txt
python3 -m zipfile -c ~/test.zip ~/hello.txt
gio mount 'archive://file%3A%2F%2F%2Fhome%2Fnix-test%2Ftest.zip'
ls "/run/user/$(id -u)/gvfs/"
```

- [ ] **Archive**: `ls` shows the archive as a folder and Nautilus lists it in the sidebar.
- [ ] **Flatpak via FUSE**: Ctrl+O in Firefox, browse to the mount, `hello.txt` opens. `flatpak run --filesystem=xdg-run/gvfs --command=ls org.mozilla.firefox "/run/user/$(id -u)/gvfs/"` lists the mount.
- [ ] **SMB**: Nautilus, Other Locations, `smb://<host>/<share>` mounts and a file opens. Needs a share the VM can reach. Skip if you have none, then it's host-only.

Power:

- [ ] **Suspend**: `systemctl suspend`, resume lands on the lock screen, the password unlocks it. Same for Noctalia's Lock and Suspend action.
- [ ] **Idle**: no extra idle daemon running, idle settings at Noctalia defaults.

## 5. Nix

```bash
nix shell nixpkgs#hello --command hello
nix registry list | grep nixpkgs
nix shell nixpkgs#xeyes --command xeyes
```

- [ ] **First nix shell**: prints `Hello, world!` without any setup or sudo.
- [ ] **Registry**: `nixpkgs` entry has no pinned revision.
- [ ] **X11**: xeyes opens a window under niri.

```bash
nix shell nixpkgs#git --command git clone https://github.com/trin94/fruppiOS.git ~/fruppios
cd ~/fruppios
nix run github:nix-community/home-manager/release-26.05 -- switch --flake ./docs/fixtures/home-manager#nix-test
```

- [ ] **Home Manager**: activation works without sudo.
- [ ] **PATH**: in a new terminal, `hello` works and `home-manager generations` lists the generation.

## 6. Baseline

Save the state that has to survive, and a script to compare against it:

```bash
readlink -f "$(command -v hello)" > ~/nix-hello-path
printf 'fruppiOS marker\n' > ~/marker
flatpak remotes --user --columns=name,url > ~/flatpak-remotes
flatpak list --user --app --columns=application,active > ~/flatpak-apps
find ~/.var/app/org.gnome.Calculator -type f -exec sha256sum {} + | sort > ~/flatpak-data
printf 'fruppios-acceptance\n' | secret-tool store --label='fruppiOS acceptance' fruppios-check desktop-integration

cat > ~/check.sh <<'EOF'
set -ex
hello
home-manager generations
test "$(readlink -f "$(command -v hello)")" = "$(cat ~/nix-hello-path)"
cat ~/marker
nix shell nixpkgs#hello --command hello
diff ~/flatpak-remotes <(flatpak remotes --user --columns=name,url)
diff ~/flatpak-apps <(flatpak list --user --app --columns=application,active)
diff ~/flatpak-data <(find ~/.var/app/org.gnome.Calculator -type f -exec sha256sum {} + | sort)
EOF
wc -l ~/flatpak-remotes ~/flatpak-apps
bash ~/check.sh
```

- [ ] **Baseline**: `flatpak-remotes` has one line, `flatpak-apps` two. `check.sh` passes right away.

## 7. Cold boot

Power the VM off, start it, log in as `nix-test`.

- [ ] **Keyring**: no "Unlock Login Keyring" dialog. `secret-tool lookup fruppios-check desktop-integration` prints the fixture without a prompt.
- [ ] **Persistence**: `bash ~/check.sh` passes.

Power the VM off and snapshot it, named after build A's digest. The [upgrade pass](#13-upgrade-pass) starts from this snapshot. Snapshot before 8 to 10, they change state the upgrade pass needs intact.

## 8. Staged update

Publish build B from your machine: `gh workflow run build.yml -R trin94/fruppiOS`. Wait for CI. Don't use `bootc upgrade` in the VM.

**admin**

```bash
cat /proc/sys/kernel/random/boot_id > ~/boot-id
sudo systemctl start rpm-ostreed-automatic.service
systemctl show rpm-ostreed-automatic.service -p Result -p ExecMainStatus
sudo bootc status --json > ~/staged-b.json
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat ~/boot-id)" && echo same boot
```

- [ ] **Staged, no reboot**: result `success`, B's digest staged, A still booted, `same boot` printed. Write B's digest into the table.

**admin**: `sudo systemctl reboot`, then `sudo bootc status --json > ~/booted-b.json`.

- [ ] **Activation**: B booted, `rpm -E '%fedora'` prints `44`.
- [ ] **Persistence**: `bash ~/check.sh` passes as `nix-test`.

## 9. Rollback

**admin**

```bash
sudo systemctl stop rpm-ostreed-automatic.timer
sudo bootc rollback
sudo systemctl reboot
```

The stop doesn't survive the reboot. The timer comes back one hour after boot, long enough for one sitting.

After the reboot, **admin**: `sudo bootc status --json > ~/rollback-a.json`.

- [ ] **Rollback**: A booted again, `rpm -E '%fedora'` prints `44`.
- [ ] **User env unchanged**: `bash ~/check.sh` passes as `nix-test`.

## 10. Removed remote

```bash
flatpak uninstall --user -y --all
flatpak remote-delete --user flathub
```

Reboot, log in as `nix-test`.

- [ ] **Stays removed**: `flatpak remotes --system --show-disabled` and `flatpak remotes --user --show-disabled` print nothing.

## 11. Record

Attach `build-a.json`, `staged-b.json`, `booted-b.json`, `rollback-a.json` and the output of anything that failed to the issue. No secrets or password hashes.

## 12. Not in the VM

These need hardware the VM doesn't have. They move to [#9](https://github.com/trin94/fruppiOS/issues/9) and run on the installed machine. Also anything you skipped above for the same reason.

- [ ] **DDC**: `ddcutil detect` lists the external monitor and Noctalia brightness changes it.
- [ ] **MTP**: attach a phone in file-transfer mode. Nautilus shows it in the sidebar, `gio mount -l | grep mtp` lists it.
- [ ] **Controller**: plug in a gamepad after a graphical login. `getfacl /dev/hidraw*` shows the user ACL. Steam (`flatpak install --user flathub com.valvesoftware.Steam`) lists it under Settings, Controller.
- [ ] **Not a joystick**: plug in a device from the blacklist, a Wacom tablet or Logitech keyboard. `ls /dev/input/js*` shows no node for it and `udevadm info /dev/input/eventN | grep ID_INPUT_JOYSTICK` is empty. **admin**: `sudo ausearch -m avc -c rm` prints nothing.

## 13. Upgrade pass

Start from the snapshot taken in section 7: the old release, user environment in place, `check.sh` passing. The new tag has already passed the fresh pass. Replace `44` and `45` with the old and new release.

| Record | |
| --- | --- |
| Date | |
| Old release digest | |
| New release digest | |

### Catch up on the old release

The snapshot may be months old. Bring it to the newest build of its release first, so the switch tests the bump and nothing else.

**admin**

```bash
sudo systemctl start rpm-ostreed-automatic.service
systemctl show rpm-ostreed-automatic.service -p Result -p ExecMainStatus
sudo systemctl reboot
```

After the reboot, **admin**:

```bash
sudo bootc status --json > ~/upgrade-old.json
sudo bootc upgrade --check
getent passwd greetd > ~/ids-44
getent group nixbld >> ~/ids-44
sudo ostree admin config-diff > ~/etc-diff-44
```

- [ ] **Old release current**: staging result `success`, `upgrade --check` finds nothing newer. Write the digest into the table.
- [ ] **Baseline holds**: `bash ~/check.sh` passes as `nix-test`.

### Switch

**admin**

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/trin94/fruppios:45
sudo bootc status --json > ~/upgrade-staged.json
sudo systemctl reboot
```

After the reboot, **admin**:

```bash
sudo bootc status --json > ~/upgrade-new.json
rpm -E '%fedora'
ls /etc/yum.repos.d
grep AutomaticUpdatePolicy /etc/rpm-ostreed.conf
systemctl is-enabled rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer
systemctl is-active rpm-ostreed-automatic.timer nix.mount nix-daemon.socket
ls -Z /nix/var/nix/daemon-socket/
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances
systemctl --failed
sudo ausearch -m avc -ts boot
flatpak remotes --system --show-disabled
{ getent passwd greetd; getent group nixbld; } | diff ~/ids-44 -
sudo find /var/nix -maxdepth 3 \( -nouser -o -nogroup \) | head
sudo ostree admin config-diff | diff ~/etc-diff-44 -
```

- [ ] **Switched**: `45` booted, `bootc status` tracks the `45` tag with `signature: containerPolicy`. Write the digest into the table.
- [ ] **Base system**: the section 1 checks hold on the new release. No `terra.repo`, policy `stage`, timers `enabled`, `active` and `masked`, `nix.mount` and socket `active`, socket `var_run_t`, inotify `1048576` and `1024`.
- [ ] **Clean boot**: `systemctl --failed` lists 0 units, `ausearch` prints `<no matches>`.
- [ ] **No remotes**: `flatpak remotes` prints nothing. A bump is when Fedora may move remote seeding to another package, see ADR-0002.
- [ ] **IDs**: the `getent` diff is empty, `find` prints nothing. Dynamic UIDs can come out in a different order on the new image, and `/var/nix` keeps the old numbers. tmpfiles resets the owner of `/var/nix/store` itself on every boot, so `stat` on it proves nothing.
- [ ] **/etc**: the `config-diff` diff is empty. A new line means a file changed on 44 now shadows a changed default on 45.

### User environment

Log in as `nix-test`.

```bash
nix --version
bash ~/check.sh
secret-tool lookup fruppios-check desktop-integration
gio mount 'archive://file%3A%2F%2F%2Fhome%2Fnix-test%2Ftest.zip'
ls "/run/user/$(id -u)/gvfs/"
```

- [ ] **Session**: greeter, niri with the Noctalia bar, Super+T, Super+D, Super+Alt+L, as in section 2.
- [ ] **Nix**: `check.sh` passes. Note the `nix --version` output. A newer daemon may migrate the store database on first contact, and this is the check that it still reads.
- [ ] **Keyring**: no unlock dialog, lookup prints the fixture.
- [ ] **Flatpak**: the launcher lists Calculator and starts it. Firefox starts, Ctrl+O shows the GNOME file chooser.
- [ ] **Archive**: `ls` shows the archive as a folder. The recipe carries a bump note for `gvfs-archive`, this is where it shows.
- [ ] **Polkit**: `pkexec --disable-internal-agent /usr/bin/id -u` shows one Noctalia prompt and prints `0`.
- [ ] **Suspend**: `systemctl suspend`, resume lands on the lock screen, the password unlocks it.

### Staging follows the new tag

**admin**

```bash
sudo systemctl start rpm-ostreed-automatic.service
systemctl show rpm-ostreed-automatic.service -p Result -p ExecMainStatus
sudo bootc status
```

- [ ] **Staging**: result `success`. Whatever is staged, if anything, is a `45` build.

### Rollback across releases

**admin**

```bash
sudo systemctl stop rpm-ostreed-automatic.timer
sudo bootc rollback
sudo systemctl reboot
```

Each deployment keeps its own `/etc`. Anything written to `/etc` while on 45, a Wi-Fi profile, a changed password, an enabled unit, is gone on 44. Invisible in a wired VM, visible on a laptop.

After the reboot, `rpm -E '%fedora'` as **admin**, `bash ~/check.sh` as `nix-test`.

- [ ] **Rolled back**: `44` booted.
- [ ] **User env**: `check.sh` passes. If only the `nix` lines fail, the old daemon can't read the migrated store database. Record that as a limit of rollback after a bump, not as a regression.

Roll forward again, **admin**:

```bash
sudo bootc rollback
sudo systemctl reboot
```

- [ ] **Forward**: `45` booted, `check.sh` passes as `nix-test`.

Power the VM off and snapshot it. This snapshot replaces the one from section 7 and starts the next upgrade pass.

### Record

Attach `upgrade-old.json`, `upgrade-staged.json`, `upgrade-new.json`, `ids-44`, `etc-diff-44`, the `nix --version` output, and the output of anything that failed to the issue with the table above.

## If something fails

Collect before changing anything:

| Area | Commands |
| --- | --- |
| Nix | `systemctl status nix.mount nix-daemon.socket nix-daemon.service`, `findmnt /nix`, `ls -Z /nix/var/nix/daemon-socket/`, `sudo ausearch -m avc -ts boot`, `journalctl -b -u nix.mount -u nix-daemon.service` |
| Portals | `journalctl --user -b -u xdg-desktop-portal.service -u xdg-desktop-portal-gnome.service` |
| Keyring | `sudo journalctl -b \| grep -Ei 'gkr-pam\|gnome-keyring'`, `cat /etc/pam.d/greetd` |
| Updates | `sudo journalctl -b -u rpm-ostreed-automatic.service`, `sudo bootc status` |
| gvfs | `journalctl --user -b -u gvfs-daemon.service`, `gio mount -l` |
| Bump | `rpm-ostree status`, `sudo journalctl -b -u nix-daemon.service`, `sudo journalctl -b -p err`, `rpm -qa \| sort > ~/rpms-45` and diff against the same list from the old release |
