# obsd-gamemode - GameMode for OpenBSD

Set performance and quality-of-life settings for running more demanding games on OpenBSD. Inspired by [GameMode for Linux](https://github.com/FeralInteractive/gamemode). This is more limited in scope and doesn't reach into CPU governor or GPU performance tweaks.

This takes care of the following settings for the application:

- CPU to high performance mode (`apm -H`; also stops [obsdfreqd](https://git.sr.ht/~solene/obsdfreqd) if running)
- datasize limit high (typically to all physically available memory)
- high mesa shader cache size (should reduce stutter due to shader compilation)

One of the main advantages is that it saves the baseline settings prior to launch and returns to them after program execution is completed.

It also supports running as super user via doas(1) or sudo(1) and dropping privileges when launching the game. This allows it to adjust settings that would normally require root _without running the game as root_. **NOTE:** _This feature is a work-in-process, needs further review and validation, and **does come with higher security risks**._

## Usage

```
gamemoderun.sh command [args]
```

## Limitations

This is only for 1 concurrent game process, as it will end the performance settings (at least apm(1) settings) when any instance of this script exits.

Running multiple instances at the same time _can_ lead to settings conflicts and incorrect settings being restored. Other utilities which dynamically adjust the same settings (especially apm(1) and sysctl(1) `hw.perfpolicy`/`hw.setperf`, aside from the supported apmd(8) and obsdfreqd(1)) _will likely_ also result in settings conflicts.

## Possible future additions

- Debating about making a daemon, which would allow the following:
  - renice(8)/setpriority(2) to prioritize the game process
    - this can also be implemented with the new privdrop support
  - handling multiple games/programs being run in gamemode (would keep a list, and remain active until the last one has exited)
    - in the interim, maybe add a lock file in /tmp?
- Hybrid GPU handling via `DRI_PRIME`, if that works on OpenBSD (untested so far; may need xorg.conf tweaks)
