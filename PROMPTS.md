# What to ask your Claude

Copy-paste these. Each one is written so a fresh Claude — one that knows nothing
about this project — can orient itself and act.

---

## 1. First time: install the mod

```
I'm setting up a Kenshi co-op mod my friend built. Please install it for me.

Repo: https://github.com/LogoutUser/KenshiCoopTrio

Do this:
1. Clone it somewhere sensible
2. Read FRIEND_BRIEFING.md in the repo root — that's your full context for this
   project, including the architecture and what every log line means
3. Check whether I have RE_Kenshi installed; if not, tell me (I have to run that
   installer myself, it modifies the game)
4. Run dist\trio-kit\INSTALL.cmd — the Steam IDs are pre-filled, I just press Enter
5. Verify my DLL's SHA-256 matches dist\trio-kit\PROVENANCE.txt and tell me if it
   doesn't

I'm on Windows. Kenshi is installed through Steam.
```

## 2. Getting a new build

```
My friend pushed a new build of the Kenshi co-op mod. Please update me:
git pull in the repo, then run dist\trio-kit\INSTALL.cmd, then confirm my
installed DLL's SHA-256 matches PROVENANCE.txt.
```

Worth insisting on the hash check. Everyone must run a byte-identical DLL or
the connection is refused, and "someone quietly didn't update" is the single
most common cause of a session that won't start.

## 3. Something broke

**Do this before you relaunch.** Kenshi wipes its logs on every launch, so
restarting destroys the evidence — that has already cost three separate
diagnoses on this project.

```
Something went wrong in our Kenshi co-op session. DO NOT let me restart the
game yet.

1. Run dist\trio-kit\SHARE_LOG.cmd to capture the logs first
2. Then read my KenshiCoop_join.log (in the Kenshi folder) and tell me what
   you see. FRIEND_BRIEFING.md has a table of what each log line means.

What I observed: <describe it plainly — "my hits did nothing to enemies",
"NPCs vanished when I got near", "game froze when X">
```

Describe **what you saw**, not what you think caused it. The observation is the
durable part; theories are cheap to regenerate and expensive to un-believe.

## 4. Diagnosing on your own

```
Read FRIEND_BRIEFING.md in this repo first — it has the architecture and the
log-line decoder. Then look at my KenshiCoop_join.log and tell me:

- did the plugin load, and on which build
- did I connect, and what player id did I get
- is my melee damage being reported to the host ([combat] / [dmg] lines)
- anything that looks wrong

Check the log rather than reasoning about what the code probably does — nearly
every real bug on this project was found by reading a log, and nearly every
wrong turn came from assuming.
```

## 5. If you think you've found a fix

```
I think I've found a bug in the Kenshi co-op mod. Read COORDINATION.md first —
I'm a "spoke", so I don't push to main. Help me:

1. Confirm it from the logs, not from guesswork
2. Push a fix/<short-name> branch and open a PR against main
3. Write the PR so it explains what evidence proves the bug is real
```

**Never install a DLL you compiled yourself.** Only Marsh's build is
authoritative — a locally built one won't match, and the session will either
refuse to connect or silently diverge, which is much worse.

---

## Things worth telling your Claude up front

- **This mod is experimental.** Three-player support is new and much of it has
  never been exercised. Unproven things should be reported as unproven.
- **Preserve evidence before acting.** Restarting, reinstalling and "just trying
  something" all destroy state. Capture first.
- **The logs are unusually informative.** Most questions here are answerable
  from a log line rather than from inference.

---

## 6. Sending your log to Marsh

The most useful thing you can do after a bad session. Ask for this **before**
relaunching:

```
We just played a Kenshi co-op session and I need to send my log to Marsh.
Do NOT let me restart Kenshi first — the game wipes its logs on launch.

Run: dist\trio-kit\SHARE_LOG.cmd

It'll ask my name (evan or zach). It pushes to a logs-<name> branch on
GitHub, or drops a zip on my Desktop if the push doesn't go through.

Then read my KenshiCoop_join.log and tell me what you see — especially any
line starting with [hitdbg]. FRIEND_BRIEFING.md explains what they mean.
```

**Let the script do the git work.** It pushes to a per-player branch and never
touches `main`, and it restores whatever branch you were on afterwards. An
assistant improvising `git` commands here can strand you on a logs-* branch,
which makes your next `git pull` look broken for reasons you'd never connect
back to this.

If the push is rejected, that just means the repo invite hasn't been accepted —
the Desktop zip it falls back to is equally good, send it over Discord.
