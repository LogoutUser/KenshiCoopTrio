# Setup — everything you have to do

Ordered by who does what. **One person** does Parts A–C once and sends the
result to the other two; **all three** do Part D.

Before starting, read [STATUS.md](STATUS.md): the code in this repo has never
been compiled. Part B is where you find out what still needs fixing.

---

## Part A — The build machine (one person, once)

Whoever has the most patience does this. It needs a Windows machine with Kenshi
installed. It does **not** need to be the person who hosts.

### A1. Install the toolchain

| What | Where | Why |
|---|---|---|
| Kenshi **1.0.65** | Steam | must match; the plugin hooks exact engine addresses |
| **Windows SDK 7.1** | [MS download](https://www.microsoft.com/en-us/download/details.aspx?id=8279) | provides the VC++ 2010 x64 compiler |
| **VC2010 SP1 compiler update (KB2519277)** | [MS download](https://www.microsoft.com/en-us/download/details.aspx?id=4422) | fixes the x64 compiler the SDK ships broken |
| **VS2022 Build Tools** | [MS download](https://visualstudio.microsoft.com/downloads/) | just for a modern `MSBuild.exe` |
| **Git** | [git-scm.com](https://git-scm.com/) | to clone dependencies |

The 2010 toolset is **not optional and not nostalgia**. Kenshi 1.0.65 was built
with it, and KenshiLib plugins share the game's C++ runtime and ABI. A DLL built
with a modern toolset will crash the game on load.

> **Install order matters.** SDK 7.1 first, then KB2519277. If SDK 7.1 refuses
> to install, it is almost always because a newer VC++ 2010 Redistributable is
> already present — uninstall the x86 and x64 2010 redists, install the SDK,
> then reinstall them. `tools/uninstall_redists.ps1` and
> `tools/reinstall_redists.ps1` in this repo do exactly that.

### A2. Get the source and its dependencies

```bash
git clone https://github.com/<you>/KenshiCoopTrio.git
cd KenshiCoopTrio
git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps third_party/KenshiLib_deps
git clone https://github.com/lsalzman/enet third_party/enet/enet
```

Then apply both ENet patches (they are required — the 2010 compiler is C89 and
rejects stock ENet, and patch 2 adds the socket hooks the Steam tunnel needs):

```bash
git -C third_party/enet/enet apply ../patches/0001-enet-c89-for-loops.patch
git -C third_party/enet/enet apply ../patches/0002-enet-socket-hooks.patch
```

### A3. Build

```bash
cmd //c scripts/build_plugin.cmd Release
```

**Expect this to fail the first time.** The trio changes have never been through
a compiler. They are written in the same C++98 style as the rest of the codebase
(no `auto`, no range-for, `std::map`/`std::set`/`std::vector` only), but that is
a discipline, not a guarantee. Errors will be in these files:

`Wire.h` · `NetLink.cpp/.h` · `SteamP2P.cpp/.h` · `Replicator.h` ·
`ReplicatorCore.cpp` · `ReplicatorChannels.cpp` · `SaveXfer.cpp/.h` ·
`Plugin.cpp` · `Config.cpp/.h`

Output lands at `src/plugin/x64/Release/KenshiCoop.dll`.

### A4. Send the build to the others

Zip **`KenshiCoop.dll`** plus `dist/kit/mod/KenshiCoop.mod` and
`dist/kit/mod/RE_Kenshi.json`. All three of you must run **the same build** —
the protocol version check (now v46) will refuse a mismatch, which is a feature.

Because this is AGPL, whoever you hand a DLL to must be able to get the source.
Keeping the repo public covers that.

---

## Part B — Fix what the build finds (one person)

This is the part I could not do for you and the part most likely to take real
time. Work through the compiler errors, then commit the fixes so the others
aren't rebuilding blind.

If it builds but misbehaves, the logs are at `<Kenshi>\KenshiCoop_*.log`. Three
lines matter most for a trio session:

- `peer connected id=N [n/3 players]` — the roster is forming correctly
- `roster JOIN id=N` / `roster LEAVE id=N` — joins are learning about each other
- `[leave] owner=N scoped sweep:` — a disconnect swept **only** that player

If you see `session full` when only two people are connected, someone's client
did not release its slot on a previous disconnect.

---

## Part C — The three-squad start (one person)

Not written, and it is not code — it is game data authored in the **Forgotten
Construction Set** (`forgotten construction set.exe`, in your Kenshi folder).

**You can skip this entirely.** The workaround is simpler and works today:

> Start any game as normal. Before anyone connects, open the squad UI and split
> your units into **three squad tabs**. Ownership follows tab order — host gets
> tab 1, first join tab 2, second join tab 3.

If you do want a proper start later, the upstream two-player one was contributed
as [PR #15](https://github.com/nhoral/KenshiCoop/pull/15) and is the model to
copy.

---

## Part D — Every player, every session

### D1. One-time, on each machine

1. **Kenshi 1.0.65**, set to **windowed** (Options → Video → uncheck Full
   Screen). The plugin's overlay and input hooks assume windowed.
2. **[RE_Kenshi 0.3.1+](https://www.nexusmods.com/kenshi/mods/847)** — the free
   Nexus mod that loads the plugin.
3. Copy the `KenshiCoop` folder into `<Kenshi>\mods\` so you end up with
   `<Kenshi>\mods\KenshiCoop\KenshiCoop.dll`.
   Default Steam path: `C:\Program Files (x86)\Steam\steamapps\common\Kenshi\mods\`
4. Launch Kenshi, enable **KenshiCoop** in the Mods menu.
5. **Steam running and online** — not offline mode. This is the whole network
   setup; there is no port forwarding and no IP addresses.

### D2. Swap Steam IDs — three ways, not two

This is the part that changes for trio, and the easiest thing to get wrong.

Press **F2** in game to open the co-op panel. Each player clicks **"Copy my
Steam ID"** and sends it to the others.

- **Host** needs **both** joins' IDs.
- **Each join** needs **only the host's** ID.

Joins do *not* need each other's IDs — the host relays between them. That relay
is the central thing this fork adds.

The F2 panel has one paste slot, so the host sets the second join in the config
file at `<Kenshi>\mods\KenshiCoop\coop_config.json`:

```json
{
  "transport": "steam",
  "steamPeer":  "76561198000000001",
  "steamPeer2": "76561198000000002"
}
```

`steamPeer` is the first join, `steamPeer2` the second. Joins leave
`steamPeer2` out entirely.

### D3. Connect

1. **Host:** load your save (or start a new game and split into three tabs),
   set **Role: HOST**, toggle **Connection: ONLINE**.
2. **Joins:** from the **main menu** — no save needed — set **Role: JOIN**,
   toggle **Connection: ONLINE**. The host streams its world to you.
3. Watch for `[steam] transport=steam armed, 2 tunnel peer(s)` on the host. If
   it says `1 tunnel peer(s)`, `steamPeer2` didn't take and the third player
   will never connect.

### D4. Test in this order — do not skip to three

1. **Two players.** Confirm this build is no worse than upstream. If duo is
   broken here, the trio changes are not the cause and you'll waste hours.
2. **Three players standing still**, same location. Each screen should show two
   other squads.
3. **Three moving apart**, then combat, then trading, then saving.
4. **Disconnect test — the important one.** Have player 3 quit. Players 1 and 2
   must keep playing with their squads intact. That single test exercises the
   most dangerous upstream assumption (a global teardown that would have
   despawned everyone's squads) and is the thing most worth confirming.

---

## If it goes wrong

| Symptom | Cause |
|---|---|
| "The co-op plugin has not started" | RE_Kenshi didn't load it — check `<Kenshi>\RE_Kenshi_log.txt` for `KenshiCoop` |
| "protocol mismatch" | someone is on a different build; all three need the same DLL |
| Third player never connects | host's `steamPeer2` not set — check the tunnel-peer count in the log |
| `dropping packets from unexpected peer` | that SteamID isn't in the host's config |
| One player quits, others break | the scoped-teardown path failed; grab the `[leave]` lines |
| Game speed stuck at 1x | someone is in combat, or a departed player's pause vote wasn't cleared |

## Honest expectation

Between here and three friends playing there is a compile-fix cycle, a real
chance of engine-level surprises no amount of source reading predicts, and the
squad-tab setup. Budget a few evenings, not an afternoon — and start with two
players.
