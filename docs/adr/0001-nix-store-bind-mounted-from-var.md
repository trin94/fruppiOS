# Nix store lives in /var/nix and is bind-mounted onto /nix

On a bootc system every toplevel directory except `/etc` and `/var` is part of the immutable image, so the `/nix` tree that Fedora's `nix-system` RPM lays out would be read-only and would be replaced on every update. We keep the real store under `/var/nix`, which bootc persists across updates and rollbacks, and bind-mount it onto `/nix` with a systemd mount unit ordered before the nix daemon. A symlink `/nix -> /var/nix` was rejected: Nix canonicalises store paths and a symlinked `/nix` is a known source of breakage.

## Consequences

- OS rollback does not roll back the user environment. Nix profiles, Home Manager generations, and GC roots stay at their current state.
- `/var/nix` is created by tmpfiles at boot, not by the image, so a fresh install starts with an empty store that the daemon initialises on first use.
- Moving the store elsewhere later means migrating data; this is why the location is recorded here.
