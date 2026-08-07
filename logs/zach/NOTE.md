# Zach, HOST sessions 11:58 – 18:07 (2026-08-07)

Duo run, Zach hosting, Evan joining. Marsh not in the session.

Build: `3A12C929…`, matches `PROVENANCE.txt` on `main`. Config is
`role=host, transport=steam, steamPeer=76561198346257175` (Evan only) —
the self-peer `steamPeer2` is gone, so the churn fault Marsh identified is
not in play here. Captured before relaunching; six log generations included.

---

## Observation

Evan's two characters stood frozen on Zach's screen while moving normally on
Evan's own. Both nameplates rendered stacked at one point (`[Eva]nhad`).
Plain terms, no theory: **on the host, the join's units did not move.**

## What the log shows

### 1. A mid-session save switch streams the WRONG save

```
17:11:16.071  [load] GO->join id=19 name='duo 4'
17:11:16.507  [load] NACK id=19 name='duo 4'          -> pending = 'duo 4'
17:11:40.266  [load] LOCAL-LOAD name='DUO 3'
17:11:40.281  [load] GO->join id=20 name='DUO 3'      -> pending NOT cleared
17:11:52.004  [load] WORLD-RELOAD swapMs=56687
17:11:52.004  [load] starting fallback transfer name='duo 4'
17:11:52.004  [save] XFER-BEGIN id=19 name='duo 4' files=208 bytes=17800021
```

The host loaded `DUO 3` and streamed Evan `duo 4`. From that point the join
held a world the host was not running.

`Plugin.cpp` mid-session load edge already does `savexfer::abortAll()` and
`g_savePending.clear()` under the comment *"A load supersedes any in-flight
save coordination"* — but does not clear `g_loadXferPending`, which holds a
save **name** captured from the previous NACK and clears only when the
transfer actually starts (gated on `gameplayLive`). A load edge inside that
window leaves the old name armed. The stale-NACK guard compares `loadId` and
cannot catch it: the name is already stored.

Proposed fix on `fix/load-xfer-pending-stale-name` — one line plus comment.
**Not compiled or run**; this spoke has no toolchain and the constitution
forbids installing a self-built DLL. Source-and-log reasoning only.

### 2. Inbound replication for the join's units then stopped for 54 minutes

No `[stats] RECV` and no `[interp]` targets for hands `1,1962646528` and
`2,818237312` between **17:12:02 and 18:06:46**. Other channels stayed alive
(`[inv] APPLY`, `[event] RECV`, `[carry] RECV`, `[cam] hints recv`), so the
tunnel was up the whole time — it is specifically the peer-unit state that
went quiet. That is the freeze the screenshot shows.

Whether this is a direct consequence of the world mismatch in §1 or a second
fault cannot be told from the host log alone. **Evan's join log for this
session would settle it and has not been captured.**

### 3. Transfer failure is not rare — it recurs every session

`XFER-ACK ok=0 files=0 bytes=0` across all six generations today:

| session | first ACK | later ACKs |
|---|---|---|
| 11:58 | 11:59:20 `ok=1` | 12:03:30 `ok=0`, 12:11:47 `ok=0` |
| 12:14 | 12:14:57 `ok=1` | 12:24:57 `ok=0` |
| 13:41 | 13:42:43 `ok=1` | 13:49:20 `ok=0` |
| 15:40 | 15:40:54 `ok=0` | 15:41:44 `ok=0`, 15:43:52 `ok=1`, 15:52:21 `ok=0` |
| 15:53 | 15:53:34 `ok=0` | 15:55:36 `ok=1`, 16:05:02 `ok=0` |
| 17:39 | 17:40:05 `ok=1` | 17:51:02 `ok=1`, 17:52:04 `ok=0`, 18:02:05 `ok=0`, 18:05:00 `ok=0`, 18:06:38 `ok=1` |

A transfer generally succeeds shortly after connect and fails later in the
session. §1 explains the 17:51 failure specifically. It does **not** explain
the others, several of which have no intervening save switch. Treat §1 as one
cause, not the cause.

### 4. Two peers connected during two sessions

`12:14:33` and `13:42:17` both reach `[3/3 players]` with a `peer connected
id=2`, then both peers drop within ~15 s. Only Evan was meant to be
connecting. Unexplained; flagging it rather than theorising.

---

## Suggested reading order

1. `17:11:40`–`17:11:52` — the save switch and the mismatched transfer
2. `Plugin.cpp` mid-session load edge — the missing `g_loadXferPending.clear()`
3. the ACK table above — the failures §1 does not account for

## Workaround until a build lands

Do not switch saves mid-session. Load the save you intend to play **before**
the join connects, and do not load a different one while connected. The stale
name can only fire when a load edge lands on a queued transfer.

*Prepared by Zach's instance (spoke). Proposal only — no change to `main`.*
