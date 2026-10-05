# Flatpak ships without remotes and the base system never adds one

Flatpak sources are part of the user environment, so the base system ships the `flatpak` RPM and nothing that configures a remote. Fedora's `base-atomic` seeds remotes in two places: the `fedora-flathub-remote` and `fedora-third-party` packages carry the filtered Flathub remote and its opt-in, and the `flatpak` RPM ships `flatpak-add-fedora-repos.service`, a preset-enabled oneshot that adds the `fedora` and `fedora-testing` remotes on first boot. We remove the two packages and mask the unit. Disabling the unit was rejected: a first boot without `/etc/machine-id` runs `systemctl preset-all`, which re-enables a disabled unit but leaves a mask alone.

## Consequences

- `flatpak remotes` is empty at system and user scope until the desktop owner adds one, which they do at user scope.
- The unit's marker `/var/lib/flatpak/.fedora-initialized` is never created, so unmasking it later adds the Fedora remotes on the next boot.
- If Fedora moves remote seeding to another package or unit, the base system picks it up silently. The CI check `boot_no_remotes`, which runs `flatpak remotes` after the first boot of every build, is what catches that.
