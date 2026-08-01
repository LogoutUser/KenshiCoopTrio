# Trio support: how duo works, and what has to change

This document is the engineering study behind this fork. It explains how
upstream [KenshiCoop](https://github.com/nhoral/KenshiCoop) achieves two-player
co-op, exactly where the "two" is welded in, and what a third player requires.

**Status: the changes described in "What this fork changes" are written but have
never been compiled or run.** See [STATUS.md](STATUS.md) before you plan around
any of it.

---

## 1. How upstream duo works

Kenshi is a single-player, single-threaded game with no networking of any kind.
KenshiCoop is not a data mod — it is a **C++ DLL injected via RE_Kenshi /
KenshiLib** that hooks the engine's main loop and mutates game state directly.
There is no server build of Kenshi, so co-op is achieved by running two ordinary
copies of the game and continuously forcing them to agree.

### The shape of it

```
  HOST (authority)                          JOIN
  ┌────────────────────┐                    ┌────────────────────┐
  │ Kenshi.exe         │                    │ Kenshi.exe         │
  │  └ KenshiCoop.dll  │◄──── ENet/UDP ────►│  └ KenshiCoop.dll  │
  │     main-loop hook │   (Steam P2P or    │     main-loop hook │
  └────────────────────┘    direct UDP)     └────────────────────┘
     owns squad tab 0                          owns squad tab 1
     owns ALL world NPCs                       drives copies of the rest
```

Each player runs a full simulation. Neither is a thin client. The mod's whole
job is to keep two independently-simulating worlds from drifting apart.

### The four ideas that make it work

**1. Ownership partitioned by squad tab.** Each player *owns* one squad tab and
simulates it locally with no interference. Your own units respond to your orders
instantly — there is no input latency, because there is no remote authority over
them. Ownership is the axis everything else hangs off.

**2. The host owns the world.** NPCs, factions, weather, the game clock,
research, production machines, doors, prices. Anything not in a player's squad
is host-authoritative. This avoids the hardest problem in the design — two
engines independently resolving the same NPC's AI and diverging — by declaring
one of them right.

**3. Owner-tagged state, applied by rule.** Every packet carries the `ownerId`
of the player who authored it. Receivers never ask "am I host?" to decide what
to do; they ask "do I own this?" A body you own, you simulate. A body you don't,
you *drive* — its transform is interpolated from the owner's 20 Hz stream and
its local AI is suppressed. This is why the codebase generalises as well as it
does: authority is data, not a branch.

**4. Layered channels for layered truth.** Roughly thirty distinct sync
channels, split by what failure means:

| Channel | Rate | Reliability | Carries |
|---|---|---|---|
| `PKT_ENTITY_BATCH` | 20 Hz | unreliable | squad transforms, animation |
| `PKT_EVENT` | on change | reliable | KO, death, revive, recruit, squad moves |
| `PKT_MEDICAL` / `PKT_STATS` | gated | reliable | vitals, skills, hunger |
| `PKT_INV_SNAPSHOT` / `PKT_INV_XFER` | on change | reliable | containers, trades |
| `PKT_WORLD_DROP` / `PKT_WORLD_PICKUP` | on event | reliable | item conservation |
| `PKT_BUILD_*` | on change | reliable | construction |
| `PKT_SAVE_*` / `PKT_LOAD_*` | on save | reliable | whole-save streaming |
| `PKT_SPEED_REQ` / `PKT_SPEED_SET` | on change | reliable | consensus game speed |

Position loss is invisible (another sample lands in 50 ms) so it rides
unreliable. A missed death is permanent divergence, so it rides reliable.

### Two details worth calling out

**Consensus game speed.** Kenshi is pausable and runs at up to 3x. Two players
cannot disagree about time. Every speed click is a *vote*; the host arbitrates
`min(all votes)`, capped at 1x while anyone is fighting, and broadcasts the
result. Anyone can pause; everyone must agree to speed up.

**Save streaming.** Saves are not merged. The host's save folder is streamed to
the join in ~4 KB chunks over the reliable channel, staged in a temporary
directory, CRC-verified per file, then atomically committed. The join's own
saving is suppressed while connected. One world, one authority, copied.

---

## 2. Where "two" is welded in

Upstream is explicit about the limit. `NetLink.cpp` rejected a third player
outright:

```cpp
// TWO-PLAYER ASSUMPTION (step-6 guard): the sync model is host + ONE join.
// Join-authored events/inventory/conservation intents reach only the host and
// are NOT relayed to other joins, and OWNER_ID_ALL sweeps assume a single peer.
// A third player connects at the wire level but will silently desync.
if (id >= 2) { netErr("3+ players unsupported: ..."); }
```

The good news is what is *not* on that list. The wire protocol is owner-tagged
throughout, the ENet host already allocates 8 peer slots, host-authored packets
already go out via `enet_host_broadcast`, and the replicator's state is held in
`std::map`s keyed by owner or by engine hand. The architecture was built
general; a few specific places took the shortcut.

Here is the complete list of what actually breaks, in severity order.

### B1 — No peer-to-peer relay *(critical)*

The star topology means the host is the only peer everyone can reach. Upstream
*consumes* a join's packet and stops. With three players, join A's squad
positions, drops, trades, deaths and vitals never reach join B. B sees A's
squad frozen at spawn, or not at all, while the host sees both correctly.

This is the blocker. Everything else is a consequence or a detail.

### B2 — Teardown is global *(critical)*

```cpp
// Runs once per leave batch (we support a single peer).
if (!leaves.empty()) { g_repl.clearPeerReplicationState(gw); ... }
```

`clearPeerReplicationState` despawns **every** proxy and resets **every**
session map. With one join that is exactly right. With two, the moment either
one disconnects, the surviving player's squad is despawned on the other
clients and the shared maps reset mid-session. One player rage-quitting takes
the other two down with them.

### B3 — Single-peer scalars

Several pieces of per-peer state are scalars that silently hold only the last
writer:

- `speedPeerReq_` / `speedPeerCombat_` — join B's speed vote **overwrites**
  join A's. The consensus rule collapses; a player's pause is silently dropped.
- `speedSeqSeen_` — one stale-packet guard shared by all senders. Each client
  runs an independent `seq` counter, so A's and B's packets suppress each
  other at random.
- `savexfer` ACK state — B's commit ACK overwrites A's. The host concludes the
  save landed when only one of two copies actually committed.
- `peerCam_` / `peerCamMs_` — one camera anchor, so host-side interest
  management follows only whichever join reported last.

### B4 — Monotonic player ids

`u32 id = nextId++;` never reuses a slot. Since `ownerId` doubles as the squad
tab rank, a player who drops and reconnects is handed rank 2, then 3 — past the
end of a 3-tab game start. Under duo the `id >= 2` guard masked this.

### B5 — Epoch map cleared wholesale

`epochSeen_.clear()` on any connect or disconnect wipes the session-epoch gate
for *all* owners, so a surviving join's in-flight batches look like a fresh
session.

### B6 — Two-squad game start

The bundled "Multiplayer (Wanderer x2)" start creates two squads. A trio needs
three. This is game data authored in the Forgotten Construction Set, not code.

---

## 3. What this fork changes

Protocol version 45 → **46**. Not wire-compatible with upstream; all three
players must run the same build.

### The relay (fixes B1)

The central change, and deliberately the smallest one that could work. On the
host, in the receive ladder, before local consumption:

```cpp
if (isHost_ && packetRelayClass(type) == RELAY_OTHERS) {
    relayToOthers(ev.peer, ev.packet->data, ev.packet->dataLength,
                  ev.channelID, ev.channelID == CH_RELIABLE);
}
```

**Verbatim** is the load-bearing word. Every join-authored packet already
carries its author's `ownerId`, so a relayed copy needs no rewriting — join B
applies precisely the authority rule it would have applied if A had been the
host's partner. A receiver cannot distinguish a relayed packet from a direct
one and needs no new code path. That is what keeps this a *transport* change
instead of a rewrite of thirty sync channels.

`packetRelayClass()` (in `Wire.h`) sorts every packet type into:

- **`RELAY_OTHERS`** — owner-authoritative state. Fan out to all other joins.
  Entity batches, events, inventory, world items, conservation intents,
  medical, stats, builds, combat hits.
- **`RELAY_HOSTONLY`** — the host arbitrates and authors its own packet with
  the verdict. Speed votes, save/load orchestration, spawn queries. Relaying
  raw votes would let joins apply each other's unarbitrated requests.
- **`RELAY_NONE`** — transport handshake, or host-authored (already
  broadcast).

Unknown types default to `RELAY_NONE`; nothing is blind-forwarded.

### Scoped teardown (fixes B2)

New `Replicator::clearPeerReplicationStateFor(gw, ownerId)` despawns only the
departing player's proxies and drops only their channel state. Because `Key` is
an engine hand and carries no owner, a `keyOwner_` index records the author of
each driven key at ingest.

`Plugin.cpp` now tracks a live roster (`std::set<u32> g_peerIds`) and only
falls back to the full reset when the **last** peer is gone. Join save
suppression likewise lifts only when truly solo — otherwise two clients could
write divergent saves of the same world.

### Per-owner state (fixes B3)

`speedPeerReq_`, `speedPeerCombat_` and `speedSeqSeen_` become
`std::map<u32, …>`. Arbitration folds `min()` / `any()` over the whole roster,
and a departing player's vote is erased so their pause cannot freeze the
survivors forever. The save-ACK ledger becomes per-owner with a real
`allAcked(xferId, expect)` gate.

### Roster protocol (fixes B2, B5)

New `PKT_PEER_JOIN` / `PKT_PEER_LEAVE`. A join previously had no way to learn
that a *sibling* existed or left — its only teardown signal was losing the host.
The host now announces roster changes, ids are allocated **lowest-free** so a
reconnecting player reclaims their own squad tab (fixes B4), and `epochSeen_` is
erased per-owner instead of wholesale (fixes B5).

---

## 4. What is NOT done

**The three-squad game start (B6).** Not written. It is authored in the
Forgotten Construction Set (`forgotten construction set.exe`, ships with
Kenshi) — a GUI tool, not a scriptable format. Workaround: use any save and
split your units into three squad tabs in-game before going online.

**Camera-hint per-peer state.** `peerCam_`/`peerCamMs_` are still scalars. The
consequence is bounded — host-side interest management follows whichever join
reported last — so it degrades performance near a distant third player rather
than desyncing state.

**Squad-rank partition beyond 2 tabs.** `OwnRanks`/tab-latching logic was read
but not modified. It infers ownership from tab rank and is the most likely
place for a third player's units to be mis-assigned.

**Every test scenario.** `src/plugin/test/` encodes two-player expectations
throughout (`ctx.isHost ? 1u : 0u` as "the peer's rank"). The harness will not
validate a trio session as-is.

**Compilation and testing.** Nothing here has been built or run. See
[STATUS.md](STATUS.md).
