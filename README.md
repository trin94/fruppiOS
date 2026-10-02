# fruppiOS &nbsp; [![bluebuild build badge](https://github.com/trin94/fruppios/actions/workflows/build.yml/badge.svg)](https://github.com/trin94/fruppios/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/trin94/fruppios:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/trin94/fruppios:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## Nix

Nix runs through the system daemon. Flakes and `nix-command` work on first login in Ptyxis:

```bash
nix shell nixpkgs#hello --command hello
```

The image doesn't pin `nixpkgs`. You can override the registry with `nix registry add nixpkgs <flake-reference>`.

To activate your own standalone Home Manager flake, run it as your account, without sudo:

```bash
nix run github:nix-community/home-manager -- switch --flake /path/to/config#your-configuration
```

Use the Home Manager branch matching your configuration's nixpkgs release. Open a new terminal after activation to use its CLI tools.

The store, database, profiles, and GC roots live under `/var/nix`, bind-mounted onto `/nix`. Reboots, image updates, and OS rollback preserve the user environment; OS rollback doesn't roll back Home Manager generations. See [ADR-0001](docs/adr/0001-nix-store-bind-mounted-from-var.md) and the [acceptance tracker](https://github.com/trin94/fruppiOS/issues/8).

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/trin94/fruppios
```
