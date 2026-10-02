# Noctalia runs as a systemd user unit, not from the niri config

The base system ships `noctalia.service` as a user unit bound to `graphical-session.target` and enables it globally. niri's own `niri-session` starts that target on login and stops it on logout, so Noctalia starts with the session and ends with it without the niri config knowing about it. Starting Noctalia with `spawn-at-startup` in the shipped niri config was rejected: the desktop owner could only turn it off by replacing the whole config file, and logout would leave it to niri to kill.

## Consequences

- `systemctl --user mask noctalia.service` keeps Noctalia off across logins; `unmask` brings it back. A drop-in under `~/.config/systemd/user/` overrides the shipped unit.
- A niri config in the user environment that also spawns `noctalia` runs a second instance. The shipped config does not spawn it.
- The unit stops when `graphical-session.target` stops, so a crashed niri takes Noctalia down with it, and relogin starts both again.
