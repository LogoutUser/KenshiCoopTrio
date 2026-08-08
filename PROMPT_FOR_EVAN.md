# Prompt for Evan's Claude

Paste everything in the box below into a fresh Claude session on Evan's machine.

---

```
You're helping me (Evan) on a Kenshi 3-player co-op mod. My friend Marsh builds
it; I play and report. Read this fully before acting.

Repo: https://github.com/LogoutUser/KenshiCoopTrio
Read COORDINATION.md and FRIEND_BRIEFING.md in the repo first — architecture,
my role, and a decoder table for every log line.

I am a SPOKE. That means: I diagnose locally and propose, I never push to main,
and I never install a DLL compiled on this machine. Only Marsh's build is
authoritative. There is no toolchain here anyway — reason from source and logs.

=== DO THESE THREE THINGS, IN THIS ORDER ===

1. CHECK MY GIT REMOTE FIRST. Run `git remote -v`. It must say
   LogoutUser/KenshiCoopTrio. Mine has previously pointed at my own fork, which
   silently breaks everything: pulls fetch nothing, my installed DLL stays
   frozen, and my pushed logs go somewhere nobody reads. If it names my account:
     git remote set-url origin https://github.com/LogoutUser/KenshiCoopTrio.git
     git fetch origin && git reset --hard origin/main

2. PUSH MY LOGS. This is the priority. My log branch on GitHub has not been
   updated since Aug 2, and Marsh has now fixed two bugs blind that my raw logs
   would have shown him hours earlier. Run:
     dist\trio-kit\SHARE_LOG.cmd
   It asks my name — answer "evan". It pushes to branch logs-evan and never
   touches main, and it restores my current branch afterwards. Let the script do
   the git work; do not improvise git commands, that has stranded people on a
   logs-* branch before.

   Push the ARCHIVES too, not just the current log. Recent builds keep several
   generations named KenshiCoop_join.log.<timestamp>.prev.log — those hold the
   sessions that already went wrong. The script's glob picks them up
   automatically; just confirm they were included and tell me how many.

   If the push is rejected, the script drops a zip on my Desktop. That's equally
   good — I'll send it over Discord.

3. UPDATE MY BUILD. After the logs are safely pushed (never before — installing
   doesn't wipe logs, but relaunching Kenshi does):
     git fetch origin && git reset --hard origin/main
     dist\trio-kit\INSTALL.cmd
   Then verify the installed DLL's SHA-256 against dist\trio-kit\PROVENANCE.txt
   and tell me plainly whether they match. Do not skip this. Every build reports
   protocol v46, so a stale client connects with NO mismatch warning and simply
   misbehaves — invisible NPCs, damage not landing, inventory resetting. Check
   the hash before believing any theory about a bug.

   In the installer, when it asks for Steam IDs: never enter my own. A recent
   session broke because a host had himself in his own peer list — the mod
   opened a P2P tunnel to his own account and joins couldn't hold a slot. The
   current installer detects this, but confirm the IDs are my FRIENDS'.

=== HOW TO WORK ON THIS PROJECT ===

CAPTURE BEFORE YOU ACT. Kenshi truncates its logs on every launch. Restarting,
reinstalling, and "just trying something" all destroy the evidence. If something
breaks mid-session, run SHARE_LOG.cmd BEFORE I relaunch — even if I'm impatient,
say so and hold me to it. Relogging is often my workaround for a bug, which
means my instinct actively destroys the proof.

SEPARATE OBSERVATION FROM INFERENCE. Report what I saw in plain terms ("mobs I
could see and hit were invisible to the host") as fact, and label anything about
causes as a guess. My last report inferred a cross-directory move as the cause;
the real bug was one line earlier. The inference being wrong cost nothing
BECAUSE it was labelled — the observations and the controlled test were what
actually fixed it.

CONTROLLED TESTS ARE THE HIGHEST-VALUE THING YOU CAN PRODUCE. My last report
changed one variable — whether a save folder existed — with the same build, same
host, same save name, seconds apart. That turned an open-ended bug into a
ten-minute fix. When you see a pattern, look for the single variable that flips
it and test that. A table of every attempt with its outcome beats any amount of
prose.

QUOTE RAW LOG LINES WITH TIMESTAMPS. Not summaries of them. Marsh greps for
exact strings; a paraphrase can't be searched and can't be trusted.

CHECK, DON'T ASSUME. Nearly every real bug here was found by reading a log or
grepping the source. Nearly every wrong turn came from reasoning about what the
code probably does. When a claim is verifiable in seconds, verify it.

SAY WHAT'S UNPROVEN. This mod is experimental and much of the 3-player path has
barely been exercised. A confident wrong answer costs an evening.

IF YOU FIND A FIX: confirm it from logs, then push a fix/<short-name> branch and
open a PR against main. Do not push main. Explain what evidence proves the bug
is real. Zach's instance did exactly this successfully — a one-line fix with the
log excerpt that proved it, and Marsh merged it after verifying against source.

=== WHERE THINGS STAND ===

Fixed in the current build and needing confirmation from my next session:
  - transfers failed whenever I already had a save with the host's name, so the
    host's world never reached my disk (this is why my items and inventory
    "reset" on relog, and why I saw mobs and damage the host couldn't — I was
    playing a stale local copy of a different world)
  - the host could load one save and stream me a different one

Still open, and NOT fixed by this build:
  - vendor stock disappearing mid-session and returning on reload. Suspected
    cause is the host publishing empty inventory snapshots over containers that
    have stock. If this still happens, capture the log at the moment it happens
    and look for [inv] APPLY lines with items=0 on a container I can see stock
    in — that would confirm it.

Start with step 1 and tell me what `git remote -v` says.
```

---

## Why this prompt is shaped the way it is

Evan's instance produced the best-instrumented report on the project — a
controlled A/B that isolated the trigger in one variable. The gap was never
analysis quality; it was that the **raw logs never reached the repo**, so two
bugs got fixed from a pasted summary when the underlying files would have been
faster and more certain.

So the prompt front-loads the mechanical steps (remote, push, hash) and puts the
working principles after — reinforcing what already worked rather than
retraining an instance that is doing well.
