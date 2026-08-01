# Status — read this first

**This fork has never been compiled and never been run.** There is no
`KenshiCoop.dll` in this repository that supports three players. You cannot
currently install this and play trio Kenshi tonight.

That is not a hedge, so here is exactly what is and isn't true.

## What is real

The two-player mod was studied properly: ~48,000 lines of C++ across the wire
protocol, the ENet transport, the replicator and the save orchestrator. The
findings are in [docs/TRIO_ARCHITECTURE.md](docs/TRIO_ARCHITECTURE.md) and they
are specific — every two-player assumption in the codebase is identified, with
file and mechanism.

Source changes implementing the trio core are written and committed:

- the host-side relay that fans join-authored state to other joins
- per-owner teardown, so one player leaving doesn't despawn the others' squads
- per-owner speed votes, sequence guards, and save ACK ledger
- lowest-free player-id allocation and a roster announce protocol

The design is sound and the diff is small and reviewable — around 400 lines
against a 48,000-line codebase, because the upstream architecture is
owner-tagged and generalises well.

## What is not real

**It has not been compiled.** No C++ compiler exists on the machine this was
written on — not the required Visual C++ 2010 toolset, not any other. The code
has been hand-reviewed (that review caught a genuine packet leak in the new
rejection path, which is fixed) but hand-review is not a build. Expect
compile errors on first attempt.

**It has not been tested.** Testing needs three copies of Kenshi, three Steam
accounts and three machines or VMs.

**The three-squad game start does not exist.** It has to be authored in the
Forgotten Construction Set, a GUI tool. Workaround below.

**"All glitches ironed out" is not achievable.** Upstream ships with "expect
desyncs and crashes" as a stated limitation *for two players*. A third player
multiplies the state that can diverge. Anyone promising you a glitch-free build
of this is guessing.

## Why nothing could be built here

| Requirement | Status |
|---|---|
| Kenshi 1.0.65 | not installed |
| Visual C++ 2010 (v100) x64 toolset | not installed |
| Windows SDK 7.1 | not installed |
| MSBuild / VS Build Tools | not installed |
| KenshiLib + deps (~500 MB, external) | not vendored — fetched separately |
| ENet source | not vendored — fetched separately |
| Forgotten Construction Set | ships with Kenshi; not installed |

The v100 requirement is not optional or a legacy preference. Kenshi 1.0.65 was
built with it, and KenshiLib plugins share the game's C++ runtime and ABI. A
DLL built with a modern toolset will crash the game.

## What to do next

### 1. Install the toolchain

Someone with a Windows machine needs:

- **Kenshi 1.0.65** (Steam)
- **[RE_Kenshi](https://www.nexusmods.com/kenshi/mods/847) 0.3.1+** — the mod
  loader this plugin runs under
- **Windows SDK 7.1** + the **VC2010 SP1 compiler update (KB2519277)** — this
  provides the v100 x64 compiler without a full VS2010 install
- **VS2022 Build Tools** — for a modern `MSBuild.exe`

Then fetch the dependencies the repo does not vendor:

```bash
git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps third_party/KenshiLib_deps
git clone https://github.com/lsalzman/enet third_party/enet/enet
```

Apply the two ENet patches in `third_party/enet/patches/` (see
`third_party/enet/README.md`) — they are required for C89 compatibility with
the 2010 compiler.

### 2. Build

```bash
cmd //c scripts/build_plugin.cmd Release
```

Expect this to fail the first time and to need a few rounds of fixing. The new
code uses `std::map`/`std::set`/`std::vector` in C++98 style (no `auto`, no
range-for) to match the existing codebase, but it has never been through a
compiler.

### 3. Get three squads without the game start

Until a "Wanderer x3" start exists, start any game, then in-game split your
units into **three squad tabs** before anyone connects. Ownership follows tab
rank: host gets tab 1, first join tab 2, second join tab 3.

### 4. Test incrementally

Do not start with three players. In order:

1. **Two players first.** Confirm this fork is no worse than upstream. If duo
   is broken here, the trio changes are not the cause and must be found first.
2. **Three players, standing still**, in the same location. Watch each log for
   `roster JOIN`, and confirm each client sees two other squads.
3. **Three players moving apart**, then combat, then trading, then saving.
4. **Disconnect tests** — this is where the fork's scoped-teardown changes
   actually get exercised. Have player 3 quit and confirm players 1 and 2 keep
   playing with their squads intact. That single test covers the most dangerous
   upstream assumption.

Logs are at `<Kenshi>\KenshiCoop_*.log`. The new code logs
`[leave] owner=N scoped sweep:` and `[speed] SET ... (my=… p1=… p2=…)`, which
are the two most useful lines for diagnosing a trio session.

## Honest expectation

The relay design is the right one and the diff is small enough to review in an
afternoon. But between here and three friends actually playing there is a
compile-fix cycle, a real chance of engine-level surprises the study could not
predict, and the game-start work. That is a project measured in evenings, not
one prompt — and it needs someone with the game installed.
