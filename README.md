# obsd-gamemode - GameMode for OpenBSD

Set performance and quality-of-life settings for running more demanding games on OpenBSD. Inspired by [GameMode for Linux](https://github.com/FeralInteractive/gamemode). This is more limited in scope and doesn't reach into CPU governor or GPU performance tweaks.

This takes care of the following settings for the application:
- CPU to high performance mode (`apm -H`)
- datasize limit high (typically to all physically available memory)
- high mesa shader cache size (should reduce stutter due to shader compilation)
- disable X11 screensaver/DPMS while running

One of the main advantages is that it saves the baseline settings prior to launch and returns to them after program execution is completed.

## Usage

```
gamemoderun.sh command [args]
```

## Limitations

This is only for 1 concurrent game process, as it will end the performance settings (at least apm(1) settings) when any instance of this script exits.

May or may not work with [obsdfreqd](https://git.sr.ht/~solene/obsdfreqd).

## Possible future additions

- Debating about making a daemon, which would allow the following:
  - renice(8)/setpriority(2) to prioritize the game process
  - handling multiple games/programs being run in gamemode (would keep a list, and remain active until the last one has exited)
- Hybrid GPU handling via `DRI_PRIME`, if that works on OpenBSD (untested so far; may need xorg.conf tweaks)
- add wayland support (screensaver/DPMS management)
