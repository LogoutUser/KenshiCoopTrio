# Status

**It works.** Three players connected on 2026-08-01 with zero errors in the
session log.

| | |
|---|---|
| Compiles | yes — Release\|x64, PE32+, zero errors |
| Packaged | yes — `dist/KenshiCoopTrio-kit.zip` |
| 3-player session | **yes** — `[3/3 players]`, protocol v46 |
| Sustained play | not yet — first session was ~1 minute |

### What the first session proved

```
[steam] tunnel peer=…175 slot=0 addr=1.0.0.1
[steam] tunnel peer=…332 slot=1 addr=1.0.0.2
[steam] transport=steam armed, 2 tunnel peer(s)
[net] peer connected id=1 (proto v46) [2/3 players]
[net] peer connected id=2 (proto v46) [3/3 players]
[event] RECV id=5 ev=6 owner=2 …
[speed] SET mult=1.00 (my=1.00 p2=1.00)   ← id=1 gone, p2 retained
[speed] SET mult=1.00 (my=1.00)           ← id=2 gone, clean
```

- **Multi-peer Steam tunnel** — two peers, distinct fake addresses. Without
  this a third player is unreachable over the default transport.
- **Lowest-free id allocation** and the `[n/3 players]` roster counter.
- **Per-owner speed votes** — `p2=1.00` is a second join's vote surviving
  alongside the first, which a scalar could not represent.
- **Scoped teardown** — each departure erased only that owner's vote. Upstream
  wiped all peer state on any disconnect.

### The relay is proven (2026-08-02)

**The fork's central claim now has direct evidence.** Zach (id=2) reported
**88 events tagged `owner=1`** in his join log — Evan's state arriving on his
machine. Neither join can reach the other directly; the only path between them
is the host-side relay. Upstream would have shown zero.

Also confirmed in a ~24 minute three-player session:

- **N-way save ACK gate** — a 4.7 MB / 48 file save transfer acknowledged by
  both joins, gated correctly:
  `XFER-ACK owner=2 (1/2 joins)` → `owner=1 (2/2 joins)` → `all joins hold this
  save`. Upstream's scalar would have declared success after the first, leaving
  one player on a stale world silently.
- **Per-join interest anchors** — `[cam] hints recv n=2 p1=… p2=…`
- **Per-owner speed votes** — `(my=5.00 p1=5.00 p2=5.00)`, and votes correctly
  erased as each player left.

### Still unproven / broken

- **Join-dealt damage does not reach the host.** Three sessions, zero
  `[combat] HIT RECV`. Not caused by the visibility bug (fixed, and it did not
  help). `[hitdbg]` instrumentation was added to localise which of five stages
  drops it; needs one join-side log to settle.
- **Crash ~24 min into a heavy three-way fight** (build `6819BE2B`, which
  predates the dangling-pointer fix in `F9F6C637`). Unattributed — the log has
  not been read yet.
- Sustained play beyond ~25 minutes.

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
