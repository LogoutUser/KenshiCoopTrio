# Status

**It builds.** `KenshiCoop.dll` compiles clean with the VC++ 2010 (v100) x64
toolset and packages into a kit. **It has not yet been play-tested** — no
three-player session has been run.

| | |
|---|---|
| Compiles | yes — Release\|x64, PE32+, zero errors |
| Packaged | yes — `dist/KenshiCoopTrio-kit.zip` |
| Play-tested | **no** |

## What's done

The two-player mod was studied in full (~48,000 lines), every place the "two"
assumption is welded in was identified, and the trio changes are implemented:
the host-side relay, per-owner teardown and channel state, the multi-peer Steam
tunnel, lowest-free player ids, and a roster protocol. See
[docs/TRIO_ARCHITECTURE.md](docs/TRIO_ARCHITECTURE.md).

The toolchain is scripted end-to-end
([scripts/setup_toolchain.ps1](scripts/setup_toolchain.ps1)), the KenshiLib
defects that block a VC10 build are captured as reproducible patches
([third_party/kenshilib/](third_party/kenshilib/)), and the friend-facing
installer is written with its Kenshi auto-detection verified.

Notably, **none of the build failures were in the trio code** — they were
MSBuild/toolset wiring and two genuine KenshiLib header defects. The C++
compiled clean on its first real attempt.

## What's untested

Everything about actually playing. The code has never had three clients
connected to it. Specifically unproven:

- the relay delivering join-authored state between two joins
- per-owner teardown when one of three players disconnects
- the multi-peer Steam tunnel carrying two joins at once
- N-way speed arbitration and the save-ACK gate

Upstream's own status is "expect desyncs and crashes" **for two players**. A
third multiplies what can diverge. Treat the first sessions as testing, and save
often.

## Still not built

**The three-squad game start.** Authored in the Forgotten Construction Set (a
GUI tool, already in your Kenshi folder). Workaround: start any game and split
your units into three squad tabs before anyone connects — ownership follows tab
order, host = tab 1.

**Per-peer camera hints.** `peerCam_`/`peerCamMs_` are still scalars, so
host-side interest management follows whichever join reported last. Bounded: it
costs performance near a distant third player, it does not desync state.

**The test scenarios.** `src/plugin/test/` encodes two-player expectations
throughout; the automated harness will not validate a trio session as-is.

## Test in this order

Do not skip to three players.

1. **Two players.** Confirm this build is no worse than upstream. If duo is
   broken here, the trio changes are not the cause and you will waste hours.
2. **Three, standing still**, same location — each screen should show two other
   squads. Check the host log says `2 tunnel peer(s)` and `[3/3 players]`.
3. **Three, moving apart**, then combat, then trading, then saving.
4. **Disconnect test.** Have player 3 quit; players 1 and 2 must keep playing
   with squads intact. This exercises the most dangerous upstream assumption — a
   global teardown that would have despawned everyone's squads — and is the
   single most valuable thing to confirm.

Logs: `<Kenshi>\KenshiCoop_*.log`. The useful lines are
`peer connected id=N [n/3 players]`, `roster JOIN/LEAVE`,
`[leave] owner=N scoped sweep:`, and `[speed] SET ... (my=… p1=… p2=…)`.

## Rebuilding from scratch

```bash
powershell -ExecutionPolicy Bypass -File scripts\setup_toolchain.ps1
```

(That one needs Administrator.) Then follow
[third_party/kenshilib/README.md](third_party/kenshilib/README.md) for the
dependency checkout and patches, and:

```bash
cmd /c scripts\build_plugin.cmd Release
```

```bash
powershell -ExecutionPolicy Bypass -File scripts\make_trio_kit.ps1
```
