# fruppiOS &nbsp; [![bluebuild build badge](https://github.com/trin94/fruppios/actions/workflows/build.yml/badge.svg)](https://github.com/trin94/fruppios/actions/workflows/build.yml)

A Fedora Atomic desktop image for one person who also administers the machine. Fedora's own `base-atomic` plus a niri session with Noctalia, a graphical greeter, a Nix daemon with a persistent store, and Flatpak with no remotes. Updates stage in the background and take effect at the next reboot.

Two layers:

- **Base system**: what the image ships. Packages, system configuration, enabled units. Replaced wholesale on every update. Every line of it is in `recipes/recipe.yml` and `files/`, nothing comes from a third-party base.
- **User environment**: what you add after first login. Flatpak remotes and apps, Nix profiles, Home Manager generations, dotfiles. Lives under `/var` and survives updates and rollback.

The image ships no browser, no editor, and no shell prompt. Those are user environment.

## Switch to it

From any Fedora Atomic install, Silverblue for example:

```bash
sudo bootc switch ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

The `44` tag follows Fedora 44 and rebuilds daily. Moving to the next Fedora release is another `bootc switch` to the next tag. No tag moves you across releases on its own.

Images are signed with [cosign](https://github.com/sigstore/cosign). Verify with the key in this repo:

```bash
cosign verify --key cosign.pub ghcr.io/trin94/fruppios:44
```

Coming from Silverblue, its `fedora` Flatpak remote stays in `/var`. Remove it with `sudo flatpak remote-delete --system fedora`. The image never adds a remote back.

## First login

Noctalia Greeter comes up on boot, no autologin. Login lands in niri with the Noctalia bar.

| Keys | Action |
| --- | --- |
| Super+T | Ptyxis terminal |
| Super+D | Noctalia launcher |
| Super+Alt+L | Lock |
| Super+Shift+/ | niri hotkey overlay |

The rest of the niri config is the upstream default. Nautilus, the GNOME file chooser and screen share portals, polkit prompts through Noctalia, keyring unlock at login, and lock on suspend work without setup. `~/Documents`, `~/Downloads`, and `~/Pictures` get created on first login.

## Flatpak

Flatpak is installed with no remotes at either scope, and the base system never adds, removes, or updates one. Add your own at user scope:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.mozilla.firefox
```

The launcher lists new apps without logging out. No update timer runs, `flatpak update --user` is yours. See [ADR-0002](docs/adr/0002-flatpak-ships-without-remotes.md).

## Nix

Nix runs through the system daemon. Flakes and `nix-command` work on first login in Ptyxis:

```bash
nix shell nixpkgs#hello --command hello
```

The image doesn't pin `nixpkgs`. Override the registry entry with `nix registry add nixpkgs <flake-reference>` if you want yours.

The store, database, profiles, and GC roots live under `/var/nix`, bind-mounted onto `/nix`. See [ADR-0001](docs/adr/0001-nix-store-bind-mounted-from-var.md).

## Home Manager

Activate your own standalone Home Manager flake as your account, without sudo:

```bash
nix run github:nix-community/home-manager -- switch --flake /path/to/config#your-configuration
```

Use the Home Manager branch matching your configuration's nixpkgs release. Open a new terminal after activation to use its CLI tools. `docs/fixtures/home-manager` is a minimal working example.

## Your own session

Noctalia runs as the `noctalia.service` user unit, bound to `graphical-session.target`. The base system enables it, you decide what happens to it:

```bash
systemctl --user mask noctalia.service     # no bar from the next login on
systemctl --user unmask noctalia.service   # bar is back
systemctl --user edit noctalia.service     # drop-in under ~/.config/systemd/user/
```

niri reads `~/.config/niri/config.kdl` and falls back to `/etc/niri/config.kdl`. Copy the shipped file and edit it, niri reloads it live. Don't spawn `noctalia` from there, that runs a second instance next to the unit. See [ADR-0003](docs/adr/0003-noctalia-runs-as-a-user-unit.md).

## Updates and rollback

`rpm-ostreed-automatic.timer` runs daily with `AutomaticUpdatePolicy=stage`. It downloads the newest `44` build and stages it. Nothing reboots on its own, bootc's apply-and-reboot timer is masked. The staged build takes effect at your next reboot.

```bash
sudo bootc status      # booted, staged, rollback
sudo bootc rollback    # boot the previous build next time
```

Rollback swaps the base system only. Flatpaks, the Nix store, Home Manager generations, and your home stay where they are.

## Building and testing

`just build` runs the BlueBuild CLI in a container against your podman socket. CI builds on every push and daily at 06:00 UTC, signs the image, and pushes it to GHCR.

Before a host install or a Fedora release bump, run [docs/vm-acceptance.md](docs/vm-acceptance.md) on a VM. Results go to [#8](https://github.com/trin94/fruppiOS/issues/8).
