# Briefing for a helper AI — KenshiCoopTrio

**How to use this:** paste this whole file into Claude (or any capable assistant)
as your first message, followed by what you're trying to do. It front-loads
everything that was learned the hard way building this mod, so your assistant
starts where we finished instead of guessing.

---

## What this is

**KenshiCoopTrio** — three-player co-op for Kenshi. A fork of
[nhoral/KenshiCoop](https://github.com/nhoral/KenshiCoop) (two players).
Source: <https://github.com/LogoutUser/KenshiCoopTrio>

It is **not** a data mod. It's a C++ DLL injected via RE_Kenshi/KenshiLib that
hooks Kenshi's main loop. Kenshi has no multiplayer and no server build, so
co-op works by running N full copies of the game and continuously forcing them
to agree.

**Status: builds and runs; NOT play-tested with three people.** Upstream's own
status is "expect desyncs and crashes" for *two* players. Treat early sessions
as testing. Save often.

---

## How the sync model works (enough to debug it)

Four ideas carry the whole design:

1. **Ownership is partitioned by squad tab.** Each player *owns* one squad tab
   and simulates it locally with zero input latency. Host = tab 1, joins = tabs
   2 and 3. `ownerId` doubles as the squad-tab rank.
2. **The host owns the world** — all NPCs, factions, weather, clock, research,
   production, doors, prices. Anything not in a player's squad.
3. **Every packet is owner-tagged.** Receivers never ask "am I host?", they ask
   "do I own this?" A body you own you simulate; one you don't you *drive*
   (transform interpolated from the owner's 20 Hz stream, local AI suppressed).
4. **~30 channels split by what failure costs.** Positions ride unreliable UDP
   at 20 Hz (a lost one is invisible). Deaths, inventory, trades, saves ride
   reliable (a lost one is permanent divergence).

### What this fork added over upstream

Upstream hard-refused a third player. The fixes, in case behaviour looks odd:

- **Host-side relay** *(the core change)*. In a star topology only the host can
  reach everyone. Upstream consumed a join's packet and stopped, so join A's
  state never reached join B. The host now re-broadcasts join-authored packets
  to other joins **verbatim** — each packet already carries its author's
  `ownerId`, so receivers need no new code path.
- **Per-owner teardown.** Upstream despawned *every* proxy on *any* disconnect.
  With three players that meant one person quitting despawned the other two's
  squads. Now scoped per departing owner; full reset only when the last peer goes.
- **Per-owner speed votes / sequence guards / save-ACK ledger.** These were
  single variables, so one join silently overwrote another's.
- **Multi-peer Steam tunnel.** The tunnel held ONE peer and ignored the
  destination address. Now a peer table with a fake address per slot
  (1.0.0.1, 1.0.0.2, …).
- **Lowest-free player ids** (upstream used `nextId++`, so a reconnecting player
  got a rank past the end of a 3-tab start).

**Wire protocol is v46 and is NOT compatible with upstream v45.** All three
players must run the *same DLL* — compare the SHA-256 in `PROVENANCE.txt`.

---

## Installing (what a player actually does)

1. **RE_Kenshi** — <https://github.com/BFrizzleFoShizzle/RE_Kenshi/releases/latest>
   Free, and it's what loads the plugin. Nothing works without it.
2. Unzip the kit, double-click **`INSTALL.cmd`**. It finds Kenshi via the Steam
   registry + `libraryfolders.vdf`, copies the mod to
   `<Kenshi>\mods\KenshiCoop\`, and writes `coop_config.json`.
3. Enable **KenshiCoop** in Kenshi's Mods menu.
4. Steam must be **running and online** (not offline mode).

### The Steam ID swap — the step people get wrong

- The **HOST** needs **both** joins' SteamID64s.
- Each **JOIN** needs **only the host's**.
- Joins do **not** need each other's — the host relays between them.

The F2 panel has one paste slot, so the host sets the second join in
`<Kenshi>\mods\KenshiCoop\coop_config.json`:

```json
{
    "transport": "steam",
    "steamPeer":  "<join 1 SteamID64>",
    "steamPeer2": "<join 2 SteamID64>",
    "port": 27800
}
```

Joins omit `steamPeer2` entirely. Get your own ID from the F2 panel
("Copy my Steam ID") — that's authoritative for whichever Steam account is
actually logged in.

### Three squads

There is **no three-squad game start** (that needs the Forgotten Construction
Set, a GUI tool). Workaround: start any game and split units into **three squad
tabs** before anyone connects. Ownership follows tab order.

### Connecting

- Host: load the save, F2 → Role **HOST** → Connection **ONLINE**.
- Joins: from the **main menu** (no save needed), F2 → Role **JOIN** → **ONLINE**.
  The host streams its world over automatically.

---

## Kenshi version + launching (non-obvious)

RE_Kenshi targets **1.0.65**. On **1.0.68** its installer uses Google's
Courgette to binary-patch a 1.0.65 build at:

```
<Kenshi>\RE_Kenshi\Kenshi_x64.exe
```

It leaves the original `kenshi_x64.exe` **untouched** — verified by SHA-256.
The desktop `RE_Kenshi` shortcut launches the patched exe with the working
directory set to the **Kenshi root** (not the `RE_Kenshi` subfolder) — that
matters, or it won't find `Plugins_x64.cfg`, `data/`, or `mods/`.

Confirm a correct install:
- `KenshiLib.dll`, `RE_Kenshi.dll`, `CompressToolsLib.dll` in the Kenshi root
- `Plugin=RE_Kenshi` in `Plugins_x64.cfg`
- window title reads **"Kenshi 1.0.65 - x64"**

### Windowed mode — do it properly

The mod needs windowed (not exclusive fullscreen). In `<Kenshi>\kenshi.cfg`:

```
Full Screen=No
Border=Default
Video Mode=1600 x 900 @ 32-bit colour
```

**Do not use `Border=None` at exactly the screen resolution.** That triggers
Windows fullscreen-optimisation behaviour and the window minimises whenever it
loses focus — which is constant in co-op (Discord, Steam, alt-tab), and Ogre
stalls initialisation while minimised. A slightly-smaller bordered window is
strictly better here.

---

## Debugging

Logs live in the Kenshi folder:

- `KenshiCoop_host.log` / `KenshiCoop_join.log` — the mod
- `RE_Kenshi_log.txt` — whether the plugin was loaded at all

### Lines that matter

| Line | Means |
|---|---|
| `KenshiCoop loaded!` + `proto=v46` | plugin is in, correct protocol |
| `transport=steam` | config took (default is `udp`) |
| `[steam] id=… loggedOn=1` | Steam reachable; this is your own ID |
| `2 tunnel peer(s)` | host armed for BOTH joins — only appears on going ONLINE |
| `peer connected id=N [n/3 players]` | roster forming |
| `roster JOIN/LEAVE id=N` | joins learning about each other |
| `[leave] owner=N scoped sweep:` | a disconnect swept ONLY that player |
| `[speed] SET … (my=… p1=… p2=…)` | whole speed vote set |
| `CAPS … =1` | engine hooks resolved (all should be 1) |

### Common failures

| Symptom | Cause |
|---|---|
| "co-op plugin has not started" | RE_Kenshi didn't load it — check `RE_Kenshi_log.txt` |
| "protocol mismatch" | different builds; compare DLL SHA-256 |
| third player never connects | host's `steamPeer2` missing — log says `1 tunnel peer(s)` |
| `dropping packets from unexpected peer` | that SteamID isn't in the host's config |
| one player quits, others break | scoped-teardown failure — grab the `[leave]` lines |
| speed stuck at 1x | someone's in combat, or a departed player's pause vote persisted |
| game stalls at ~136 MB RAM | window is minimised; Ogre halts init while minimised |

### Test order — do not skip to three

1. **Two players first.** If duo is broken, the trio changes aren't the cause.
2. Three standing still, same spot — each screen should show two other squads.
3. Three moving apart → combat → trading → saving.
4. **Disconnect test:** player 3 quits; players 1 and 2 must keep playing with
   squads intact. This is the most valuable single test — it exercises the
   upstream bug that would otherwise take all three down together.

---

## Building from source (only if you're rebuilding the DLL)

Kenshi 1.0.65 was built with **Visual C++ 2010**, and KenshiLib plugins share
the game's C++ runtime and ABI. **A DLL built with a modern toolset will crash
the game.** The v100 requirement is not negotiable.

`scripts/setup_toolchain.ps1` (run as Administrator) automates this. What it
does and why each step exists:

1. Windows SDK 7.1 carries the v100 x64 compiler, but **refuses to install
   while a newer VC++ 2010 redistributable is present** — so those get removed
   first, then reinstalled at the end.
   **Kenshi itself imports `MSVCR100.dll`/`MSVCP100.dll` and ships no local
   copy, so Kenshi will not launch during that window.** The restore lives in a
   `finally` block so a failed run still leaves the game playable. If it ever
   goes wrong: `winget install Microsoft.VCRedist.2010.x64 Microsoft.VCRedist.2010.x86`.
2. SDK 7.1 warns that .NET Framework 4 is "pre-release" on modern Windows —
   **false positive, click OK.** It only skips managed components; the native
   C++ compilers install fine.
3. KB2519277 restores the x64 compiler. Microsoft's direct links are dead; the
   URL must be pulled from the download page's "download manually" link.

Then per `third_party/kenshilib/README.md`: clone the deps, **`git checkout
e75769b`** (KenshiLib 0.3.0 — 0.4.0 moved `CombatClass.h` somewhere its own
includes stop resolving), apply the patch, extract Boost. Then:

```
cmd /c scripts\build_plugin.cmd Release
powershell -ExecutionPolicy Bypass -File scripts\make_trio_kit.ps1
```

### Build gotchas already solved in the scripts

- `$(VCTargetsPath)` resolves to VS2022's `VC\v170`, which only exists with the
  C++ workload. Not needed — override to the v100-era targets in
  `%ProgramFiles(x86)%\MSBuild\Microsoft.Cpp\v4.0`.
- In `cmd`, that path contains `(x86)`; inside a parenthesised `IF` block the
  `)` terminates the block. Use single-line `IF`s.
- A trailing `\` before a closing quote escapes the quote and swallows the rest
  of the command line. Pass `"...\v4.0\\"`.
- The v100 targets default `TargetFrameworkVersion` to v4.0, so MSBuild demands
  .NET reference assemblies (MSB3644) for a *native* DLL. Stub
  `_TargetFrameworkDirectories` and `_FullFrameworkReferenceAssemblyPaths`
  rather than installing a developer pack.
- **KenshiLib itself doesn't compile under VC10**: `BuildingDesignation` is
  declared identically in both `Platoon.h` and `Building/Building.h` (C2011),
  and `CraftingItem` is forward-declared but held by value in a `std::deque`
  member (C2027). Both are fixed by the patch file. The `CraftingItem`
  stand-in is layout-safe — `sizeof(std::deque<T>)` doesn't depend on `T`, and
  KenshiLib's own offset comments (`0x498` → `0x4C8` = 48 bytes) confirm it.

---

## How to be useful here

- **Don't guess about state — check it.** Read the logs, hash the DLLs, look at
  the actual config. Almost every problem above is diagnosable from a log line.
- **Say when something is unverified.** This mod is unproven with three
  players; a confident wrong answer costs an evening.
- **Two players before three, always.**
- Licence is **AGPL-3.0**: if you pass a compiled DLL to someone, the source has
  to go with it. Keeping the repo link attached covers that.
