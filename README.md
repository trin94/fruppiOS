# fruppiOS [![bluebuild build badge](https://github.com/trin94/fruppios/actions/workflows/build.yml/badge.svg)](https://github.com/trin94/fruppios/actions/workflows/build.yml)

> [!WARNING]
> fruppiOS is in very early development. Expect breaking changes.
> Use it at your own risk.

## Contents

- [Philosophy](#philosophy)
- [Quickstart](#quickstart)
- [Pre-installed apps](#pre-installed-apps)
- [Desktop defaults](#desktop-defaults)
- [Flatpak](#flatpak)
- [Nix](#nix)
- [Your own session](#your-own-session)
- [Updates and rollback](#updates-and-rollback)
- [Building](#building)
- [Possible additions](#possible-additions)
- [Acknowledgements](#acknowledgements)

## Philosophy

fruppiOS is a Fedora Atomic desktop image for one person on their own machine.
The image owns the base system: the desktop, system packages, and system
configuration. You own what you add on top: apps, tools, and personal
configuration. Your additions survive base system updates and rollback.

The desktop stays close to upstream defaults. Install GUI apps with Flatpak
and terminal tools with Nix.

**The base system updates itself and applies the update when you reboot.
Flatpak apps don't. You update those yourself.**

## Quickstart

You need an existing Fedora Atomic installation, such as Silverblue.
Keep these steps open somewhere else. fruppiOS has no browser until you
install one.

### 1. Switch to fruppiOS

Your current installation doesn't have the fruppiOS signing key yet, so this
first switch can't verify the image. The key comes with fruppiOS.

```bash
sudo bootc switch ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

### 2. Enable image verification

Log in and press **Super+T** to open the Ptyxis terminal. Switch again, this
time with signature verification. All later updates are verified.

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

Use the `44` tag, not `latest`. `44` stays on Fedora 44 and is rebuilt daily.
`latest` moves to the next Fedora release when the recipe does.

### 3. Install a browser

After the second reboot, log in and open the terminal again. Each account gets
`~/fruppiOS-first-steps.txt` on first login. Run the browser commands from that
file. They add Flathub and install Firefox.

Press **Super+D** to open the launcher and start Firefox. New apps show up
without logging out.

The file also has a few setup reminders. Delete it when you're done. It won't
come back.

Coming from Silverblue? Its Flatpak remotes are still there. See
[Flatpak](#flatpak) to remove them.

## Pre-installed apps

The image is based on Fedora's `base-atomic`. Some packages, Noctalia among
them, come from the Terra repository.

| App or component | Role |
| --- | --- |
| niri | Wayland desktop |
| Noctalia | Desktop bar, launcher, and lock screen |
| Noctalia Greeter | Login screen |
| Ptyxis | Default terminal |
| Kitty | Alternative terminal |
| Nautilus | File manager |
| Flatpak | GUI app manager |
| Nix | Package manager for terminal tools |

There's no browser.

## Desktop defaults

On boot you get Noctalia Greeter. There's no autologin. After login, niri
starts with the Noctalia bar.

| Keys | Action |
| --- | --- |
| Super+T | Ptyxis terminal |
| Super+D | Noctalia launcher |
| Super+Alt+L | Lock |
| Super+Shift+/ | niri hotkey overlay |

The rest of the niri configuration is the upstream default.

The image also sets up:

- GNOME portals for the file chooser and screen sharing
- polkit prompts through Noctalia
- keyring unlock at login
- lock on suspend
- the standard home directories on first login, through `xdg-user-dirs`

## Flatpak

Install more GUI apps with Flatpak. The image ships without remotes, so you
choose where your apps come from.

A switch keeps your existing remotes and apps. If you came from Silverblue and
don't want its Fedora remotes, remove them:

```bash
flatpak remote-delete --system fedora
flatpak remote-delete --system fedora-testing
```

Flatpak apps don't update automatically. Update them yourself:

```bash
flatpak update -y
```

## Nix

Nix runs through the system daemon. Flakes and `nix-command` are already
enabled, so there's nothing to install. To learn Nix, start with the official
[First steps guide](https://nix.dev/tutorials/first-steps/).

Nix keeps its store, database, profiles, and garbage collection roots under
`/var/nix`, outside the base system. The image bind-mounts that directory onto
`/nix`, so Nix sees its usual paths.

Base system updates and rollback don't touch your Nix profiles. You update
them yourself. The image doesn't pin `nixpkgs`.

## Your own session

### niri

niri uses `~/.config/niri/config.kdl` if it exists, and `/etc/niri/config.kdl`
otherwise. If you don't have your own file yet, start from the shipped one:

```bash
mkdir -p ~/.config/niri
cp /etc/niri/config.kdl ~/.config/niri/config.kdl
```

Edit the copy. niri reloads it live. Changes to the image's default won't
replace your file.

### Noctalia

Noctalia runs as the systemd user unit `noctalia.service`, tied to
`graphical-session.target`. It starts when you log in and stops when the
session ends. The image enables the unit. To turn it off or change it for your
account without touching the niri configuration:

```bash
systemctl --user mask noctalia.service     # no bar from the next login on
systemctl --user unmask noctalia.service   # bar is back
systemctl --user edit noctalia.service     # drop-in under ~/.config/systemd/user/
```

Don't also start `noctalia` from your niri configuration. You'd get a second
instance next to the unit.

## Updates and rollback

### Automatic base system updates

`rpm-ostreed-automatic.timer` runs 10 minutes after boot and then daily, with
`AutomaticUpdatePolicy=stage`. It downloads the newest build of your tag and
stages it for your next reboot.

Nothing reboots on its own. The image masks bootc's apply-and-reboot timer.
Automatic updates only cover the base system, not Flatpak apps or Nix
profiles.

Check the current deployments:

```bash
sudo bootc status      # booted, staged, rollback
```

### Rollback

To boot the previous base system next time:

```bash
sudo bootc rollback
sudo systemctl reboot
```

Rollback only swaps the base system. Your home directory, Flatpak apps, and
the Nix store live under `/var` and stay as they are. Rollback isn't a backup
of them.

Two things to know:

- Each deployment has its own `/etc`. If you add a Wi-Fi profile or change a
  password after an update, rolling back brings back the old settings.
- Across major releases, a newer Nix daemon may migrate its database to a
  format an older daemon can't read.

### Fedora releases and signatures

To move to a new Fedora release, run
`bootc switch --enforce-container-sigpolicy` with its numbered tag, then
reboot.

CI signs every published image with [cosign](https://github.com/sigstore/cosign).
To verify an image yourself, use `cosign.pub` from this repository:

```bash
cosign verify --key cosign.pub ghcr.io/trin94/fruppios:44
```

## Building

You need `just` and Podman. From a checkout of this repository:

```bash
just build
```

This starts your systemd user Podman socket and runs the BlueBuild CLI in a
container against it. The build uses `recipes/recipe.yml` and the files under
`files/`.

`just build` doesn't run the checks. Run them against a built image:

```bash
just test localhost/fruppios:latest
```

Every check runs, even after one fails. At the end you get a summary of what
failed and a non-zero exit code.

To format and lint the repository, you also need `uv`:

```bash
just format
```

### CI

- Builds on code pushes and daily at 06:00 UTC.
  Markdown-only pushes don't trigger a build.
- Runs `just test` on every build.
- On the default branch, if every check passes, pushes the image to GHCR and
  signs it. It then pulls the published image with the image's own signature
  policy.
- On other branches, builds and tests but doesn't publish.
- Runs `just format` on every push in its own workflow.
  A failing lint doesn't stop publishing.

## Possible additions

Neither works today. I won't build them myself, but contributions are welcome:

- **Homebrew** as another way to install terminal tools.
- **GUI apps through Nix**, including the desktop integration they need.

## Acknowledgements

fruppiOS mostly glues existing projects together with an image recipe and a
few integration changes.

Thanks to the people behind:

- [Fedora Atomic](https://fedoraproject.org/atomic-desktops/),
  [bootc](https://bootc.dev/bootc/), and
  [rpm-ostree](https://coreos.github.io/rpm-ostree/) for the base system
  and update tools.
- [BlueBuild](https://blue-build.org/) for the image build tooling.
- [niri](https://github.com/niri-wm/niri) and
  [Noctalia](https://noctalia.dev/) for the desktop.
- [Nix](https://nix.dev/) and [Flatpak](https://flatpak.org/) for the tools
  to build the user environment.
- [Terra](https://terrapkg.com/) for the packages it provides.
