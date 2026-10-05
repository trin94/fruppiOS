# fruppiOS

A Fedora Atomic desktop image for one person who also administers the machine. Ships a minimal niri desktop and the tools to build a user environment on top; personal configuration stays outside the image.

## Language

**Desktop owner**:
The single person who logs into the machine and administers it.
_Avoid_: User, admin, maintainer (maintainer is the person building the image, which may be the same human but a different role)

**Base system**:
Everything delivered by the image: packages, system configuration, enabled units. Replaced wholesale on update.
_Avoid_: OS, rootfs, host

**User environment**:
Everything the desktop owner adds after first login: Flatpak remotes and apps, Nix profiles, Home Manager generations, dotfiles. Survives image updates and OS rollback.
_Avoid_: Dotfiles, home, personal config

**Desktop defaults**:
The upstream niri and Noctalia behavior as shipped, plus the small integration changes needed so terminal, launcher, and lock work out of the box.
_Avoid_: Theme, rice, customization
