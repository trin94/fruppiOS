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

fruppiOS is a Fedora Atomic desktop image for one person who runs their
own machine. The image owns the base system. You own the user environment.

The image provides a working desktop and manages the base components and
system configuration. You choose and manage the apps, tools, and personal
configuration you add. Your user environment survives base system updates
and rollback.

The desktop stays close to upstream defaults. Use Flatpak for added GUI apps
and Nix for terminal tools.

**Base system updates stage automatically and take effect when you reboot.
Flatpak apps don't update automatically.** You manage those separately.

## Quickstart

Start from an existing Fedora Atomic installation, such as Silverblue.
Keep these steps available during the switch: fruppiOS has no browser until
you install one.

### 1. Switch to fruppiOS

The first switch is unverified. Your current installation doesn't yet have
the image's signing policy and key. They arrive with fruppiOS.

```bash
sudo bootc switch ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

### 2. Enable image verification

Log in through Noctalia Greeter and press **Super+T** to open Ptyxis.
Now switch again and enable signature verification. Later base system
updates stay verified.

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/trin94/fruppios:44
sudo systemctl reboot
```

The `44` tag stays on Fedora 44 and gets daily rebuilds. Use it rather than `latest`,
which moves to the next Fedora release when the recipe changes.

### 3. Install a browser

After the second reboot, log in and open Ptyxis with **Super+T**.
On first login, each account gets `~/fruppiOS-first-steps.txt`. Run the browser
installation commands from that file to add Flathub and install Firefox.

Press **Super+D** to open the Noctalia launcher and start Firefox.
New apps appear without logging out.

The file also has a few setup reminders. Delete it when you're done.
It stays deleted.

If you switched from Silverblue, its existing system Flatpak remotes remain. The
[Flatpak section](#flatpak) explains how to remove them.

## Pre-installed apps

The image builds on Fedora's `base-atomic`. Some packages, including Noctalia,
come from the Terra repository.

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

There's no browser or prompt framework. You choose those yourself.

## Desktop defaults

Noctalia Greeter comes up on boot. There's no autologin. Logging in starts
niri with the Noctalia bar.

| Keys | Action |
| --- | --- |
| Super+T | Ptyxis terminal |
| Super+D | Noctalia launcher |
| Super+Alt+L | Lock |
| Super+Shift+/ | niri hotkey overlay |

The rest of the niri configuration follows the upstream default.

The image sets up the GNOME file chooser and screen-sharing portals.
It also sets up polkit prompts through Noctalia, keyring unlock at login,
and lock on suspend. `xdg-user-dirs` creates the standard home directories
on first login.

## Flatpak

Flatpak is the supported way to install more GUI apps.
The image ships without remotes. You choose where your apps come from.

Existing remotes and apps survive a switch. If you came from Silverblue,
remove its Fedora remotes if you don't want them:

```bash
flatpak remote-delete --system fedora
flatpak remote-delete --system fedora-testing
```

The image won't add them back or change your chosen remotes.

**Flatpak apps don't update automatically.** Run this yourself:

```bash
flatpak update -y
```

## Nix

For Nix usage, follow the official
[First steps guide](https://nix.dev/tutorials/first-steps/).

Nix runs through the system daemon, with flakes and `nix-command` already
enabled. You don't need a separate installation.

The store, database, profiles, and garbage collection roots live under
`/var/nix`, outside the replaceable base system. The image bind-mounts that
directory onto `/nix`. Nix sees its usual paths while your tools and profiles
survive base system updates and rollback.

You manage profile updates. Base system updates don't update your Nix
profiles, and rollback doesn't restore older ones. The image doesn't
pin `nixpkgs`.

## Your own session

### niri

niri reads `~/.config/niri/config.kdl` if it exists.
Otherwise, it reads `/etc/niri/config.kdl`.
If you don't already have your own file, start with the shipped configuration:

```bash
mkdir -p ~/.config/niri
cp /etc/niri/config.kdl ~/.config/niri/config.kdl
```

Edit the copy. niri reloads it live.
Once you have a user configuration, changes to the image's default won't
replace it.

### Noctalia

Noctalia runs as the `noctalia.service` systemd user unit, tied to
`graphical-session.target`. It starts on graphical login and stops when
the session ends. Running it as a separate unit lets you turn it off or
change it without replacing the niri configuration.

The base system enables the unit. You can override that for your account:

```bash
systemctl --user mask noctalia.service     # no bar from the next login on
systemctl --user unmask noctalia.service   # bar is back
systemctl --user edit noctalia.service     # drop-in under ~/.config/systemd/user/
```

Masking takes effect from the next login. `edit` creates a drop-in under
`~/.config/systemd/user/`. Don't also start `noctalia` from your niri configuration.
That starts a second instance alongside the unit.

## Updates and rollback

### Automatic base system updates

`rpm-ostreed-automatic.timer` runs 10 minutes after boot and then daily, with
`AutomaticUpdatePolicy=stage`. It downloads the newest build for your
selected tag and stages it. The staged build takes effect at your next reboot.

Nothing reboots on its own. The image masks bootc's apply-and-reboot timer.
Automatic updates cover only the base system, not your Flatpak apps
or Nix profiles.

Check the current deployments:

```bash
sudo bootc status      # booted, staged, rollback
```

### Rollback

To select the previous base system for the next boot:

```bash
sudo bootc rollback    # boot the previous build next time
sudo systemctl reboot
```

Your home directory and other user data live under `/var`.
Rollback swaps the base system only. Flatpak apps, the Nix store,
and your home directory stay as they are.
It isn't a backup of the user environment.

Each deployment keeps its own `/etc`. If you add a Wi-Fi profile or change
a password on a newer deployment, rolling back brings back the older
deployment's settings. Across major releases, a newer Nix daemon may also migrate
the persistent database to a format an older daemon can't read. Keeping the
store doesn't guarantee compatibility with every older image.

### Fedora releases and signatures

Stay on a numbered tag such as `44` to stay on that Fedora release.
`latest` follows the recipe and moves to the next release when the recipe does.
To upgrade to a new Fedora release, run
`bootc switch --enforce-container-sigpolicy` with its numbered image tag,
then reboot.

CI signs published images with [cosign](https://github.com/sigstore/cosign).
If you have cosign installed, you can also verify an image yourself with
`cosign.pub` from this repository:

```bash
cosign verify --key cosign.pub ghcr.io/trin94/fruppios:44
```

## Building

From a checkout of this repository, with `just` and Podman installed:

```bash
just build
```

This starts your systemd user Podman socket and runs the BlueBuild CLI in
a container against it. The build uses `recipes/recipe.yml` and the
configuration under `files/`.

CI builds on code pushes, pull requests, and daily at 06:00 UTC.
Markdown-only pushes don't trigger a build. CI signs published images
and pushes them to GHCR.

## Possible additions

I'm open to adding these, but I won't implement them myself.
Contributions are welcome. Neither is supported today:

- **Homebrew** as another way to install terminal tools.
- **GUI apps through Nix**, including the desktop integration they need.

## Acknowledgements

fruppiOS mostly pieces together existing projects. The original work here
is small: an image recipe and a few integration changes.

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
