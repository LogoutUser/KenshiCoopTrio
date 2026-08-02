# Evan / Zach — start here

Paste this whole file to your Claude, or just follow it yourself. Three steps.

---

## 1. Get the mod (once)

```bash
git clone https://github.com/LogoutUser/KenshiCoopTrio.git
```

The compiled mod is committed, so a clone gives you everything — no zip to chase.

## 2. Install it

Run **`dist\trio-kit\INSTALL.cmd`**.

It finds Kenshi through the Steam registry, copies the mod in, and asks two
questions. **Marsh's Steam ID is pre-filled — just press Enter.**

You also need **RE_Kenshi** first (free, it's what loads the mod):
<https://github.com/BFrizzleFoShizzle/RE_Kenshi/releases/latest>

Then launch Kenshi with the **RE_Kenshi** desktop shortcut (not the Steam one —
that skips the mod loader), and enable **KenshiCoop** in the Mods menu.

## 3. Whenever Marsh says there's a fix

```bash
git pull
```

Then re-run `dist\trio-kit\INSTALL.cmd`. That's it.

**All three of you must be on the same build**, or you'll get
`protocol mismatch` at connect. `dist/trio-kit/PROVENANCE.txt` carries the
SHA-256 — compare it if a connection is refused.

---

## When something goes wrong — this matters

Kenshi **wipes its logs on every launch**. Restarting destroys the evidence of
whatever just broke. That has already cost us three separate diagnoses.

So before you relaunch, run:

```
dist\trio-kit\SHARE_LOG.cmd
```

It collects your mod log, the RE_Kenshi log, your config and your DLL hash, and
pushes them to `logs/<your name>/` in the repo (you both have write access), so
they can be read directly. If the push fails it drops a zip on your Desktop for
Discord instead.

**Run it before restarting, not after.**

---

## Connecting

- **Marsh hosts.** He needs both your Steam IDs; you each need only his.
  You do *not* need each other's — the host relays between you.
- Join from the **main menu**, no save needed. Press **F2**, set Role **JOIN**,
  toggle Connection **ONLINE**. His world streams to you.
- You each control your own squad tab: Marsh tab 1, Evan tab 2, Zach tab 3.

## Known state

Working: connecting, movement, inventory, trading between squads, carrying
bodies, medical, game-speed consensus.

Recently fixed (make sure you have the latest): a crash from a buffer overflow,
and NPCs being invisible when players split up.

Still unproven: whether your melee damage reaches the host's world NPCs. If you
swing at something and nothing happens, that's the open bug — run
`SHARE_LOG.cmd` and say so.

This is experimental. **Save often.**

---

## Want your own Claude helping you?

Paste **`FRIEND_BRIEFING.md`** (repo root) into Claude as your first message.
It carries the architecture, what every log line means, and every trap hit so
far, so it starts where we are instead of from scratch.
