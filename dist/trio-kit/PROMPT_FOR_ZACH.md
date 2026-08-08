# Prompt for Zach's Claude

Paste everything in the box below into a fresh Claude session on Zach's machine.

---

```
You're helping me (Zach) on a Kenshi 3-player co-op mod. Marsh builds it; I host
most sessions. Read this fully before acting.

Repo: https://github.com/LogoutUser/KenshiCoopTrio
Read COORDINATION.md and FRIEND_BRIEFING.md first — architecture, my role, and a
decoder table for every log line.

I am a SPOKE: diagnose and propose, never push main, never install a DLL built on
this machine. There's no toolchain here — source-and-log reasoning only.

=== FIRST: YOUR LAST ROUND OF WORK WAS MERGED ===

The fix you pushed on fix/load-xfer-pending-stale-name is now on main. Marsh
verified it against source before merging: driveLoadSync's host mid-session load
edge cleared g_savePending but not g_loadXferPending, so a load landing on a
queued transfer streamed the join the previous save. Your diagnosis was correct
and the patch was applied as written.

The way you worked is the reason it landed fast: captured before relaunching,
six log generations, observation separated from theory, a fix branch instead of
a push to main, and an explicit note that it was uncompiled. Keep doing exactly
that.

=== DO THESE, IN ORDER ===

1. UPDATE THE BUILD.
     git fetch origin && git reset --hard origin/main
     dist\trio-kit\INSTALL.cmd
   Then verify the installed DLL's SHA-256 against dist\trio-kit\PROVENANCE.txt
   and tell me plainly if they differ. Every build reports protocol v46, so a
   stale client connects with NO mismatch warning and just misbehaves.

   In the installer, never enter my own Steam ID as a peer. My config previously
   had me as steamPeer2; the mod opened a P2P tunnel to my own account and joins
   couldn't hold a slot. It's correct now (steamPeer = Evan only) — confirm it
   stays that way after reinstalling.

2. PUSH LOGS AFTER THE NEXT SESSION, good or bad. Run dist\trio-kit\SHARE_LOG.cmd
   BEFORE relaunching, answer "zach", and confirm the timestamped archives
   (KenshiCoop_host.log.<timestamp>.prev.log) were included.

=== TWO OF YOUR OPEN QUESTIONS ARE NOW ANSWERED ===

Your §3 — "XFER-ACK ok=0 recurs every session, and §1 doesn't explain most of
them". Correct, it didn't. The cause was a separate bug on the join side, found
from Evan's report and fixed on 2026-08-07: the commit swap pre-created its own
rename destination, and MoveFileEx refuses to rename a directory onto an
existing one (ERROR_ALREADY_EXISTS). It only triggered when the join already had
a save with the host's save name, so every DIVERGED transfer failed and every
MISSING one committed. Your ok=0 ACKs and Evan's XFER-FAILED lines are the same
events logged from opposite ends. Stop chasing that table; it should go quiet on
the current build. If it doesn't, that's important — say so.

Your §4 — "[3/3 players] with a peer connected id=2 when only Evan was
connecting". Diagnosed from your logs: it's a fast reconnect landing before the
host has timed out the previous connection.

  16:06:36.431  peer connected id=2  [3/3 players]
  16:06:44.178  peer disconnected id=1 [2/3 players]   <- 8s later
  17:17:37.839  peer connected id=2  [3/3 players]
  17:17:41.806  peer disconnected id=1 [2/3 players]   <- 4s later
  17:29:03.500  peer connected id=2  [3/3 players]
  17:29:05.134  peer disconnected id=1 [2/3 players]   <- 1.6s later

Evan's old slot is still occupied, so he gets the next free id and the count
briefly reads 3/3. In a duo this self-heals within seconds. In a TRIO it does
not: all three slots are already in use, so a quick reconnect finds no free slot
and the join fails outright. That is a strong candidate for "Evan can't join"
when all three of us are on, and it would look intermittent and unrelated to
whatever we changed last.

WORTH INVESTIGATING, and it's your kind of problem — host-side, visible in your
logs. The question: when a HELLO arrives from a peer already holding a slot,
should the host reclaim that slot rather than allocate a new one, and can the
two connections be matched reliably (Steam identity? ENet peer address?). Look
at NetLink.cpp's id allocation — it uses lowest-free-slot. If you find a clean
answer, push a fix/* branch with the log evidence, same as last time. Flag
anything you can't verify as unverified.

=== HOST-SPECIFIC THINGS THAT MATTER ===

- The host only pushes the world on a SAVE. If you're already in-game when a
  join connects, nothing transfers until you save — which looks exactly like a
  failed join from their side.
- Load the world you intend to play BEFORE anyone connects. Your stale-name bug
  is fixed, but switching saves mid-session is still the riskiest thing a host
  can do, and I'd rather confirm the fix in a clean session than test it live.
- You are the only one who sees host-side publish traffic. That makes you the
  right person for the one bug still open (below).

=== STILL OPEN — THE MID-SESSION VENDOR BUG ===

Evan's vendor stock disappears while playing and returns after a reload. This is
NOT the stale-world bug and is NOT fixed by the current build.

The lead, from Marsh's own host log: of 205 [inv] SEND lines, 81 carried
"items=0 hash=0", and three containers flipped from items>0 to items=0 across
the session. If the host publishes an empty snapshot over a container that
actually has stock, the join applies it and the vendor empties; a reload
restores it from the host's save.

What would confirm or kill it: in YOUR host log, find an [inv] SEND with items=0
for a container that demonstrably had stock moments earlier (an earlier SEND for
the same hand with items>0). Small counts going 1 -> 0 are ambiguous — someone
may simply have bought the item — so look for a container with several items
that publishes empty. Correlate with the moment Evan reports stock vanishing.

=== HOW TO WORK HERE ===

Capture before acting; Kenshi truncates logs on launch. Quote raw log lines with
timestamps, not summaries. Separate what was observed from what you infer, and
label the inference. Prefer a controlled test that changes ONE variable over any
amount of argument. Check the source rather than reasoning about what it
probably does. Report unproven things as unproven.

Start with step 1 and tell me whether the hashes match.
```

---

## Why this differs from Evan's prompt

Zach's instance already follows the protocol correctly and pushes logs with
archives, so this prompt doesn't re-teach any of that. It instead: confirms the
merge, closes two of its open questions with evidence, and hands it the two
things it is uniquely placed to work on — the host-side slot-reclaim question
and the vendor publish bug.
