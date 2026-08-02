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
pushes them to a branch called `logs-<your name>` — **not** to `main`. Marsh owns
`main`; your logs never touch it, so sharing evidence can't disturb the shipped
build. If the push fails it drops a zip on your Desktop for Discord instead.

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

See **[PROMPTS.md](PROMPTS.md)** for exact copy-paste prompts, or paste
**`FRIEND_BRIEFING.md`** into Claude as your first message.
It carries the architecture, what every log line means, and every trap hit so
far, so it starts where we are instead of from scratch.

---

## Who lands changes

**Marsh's side owns `main`.** Only his machine can compile the plugin (it needs
the VC++ 2010 toolchain and a patched KenshiLib), and every client has to run a
byte-identical DLL or the connection is refused — so a single writer is what
keeps "we're all on the same build" true by construction.

Your side diagnoses and proposes. If you have a fix, push a `fix/*` branch and
open a PR; don't push `main`. **Don't install a DLL you compiled yourself** —
it won't match, and the session will either refuse to connect or silently
diverge.

Full protocol: [COORDINATION.md](COORDINATION.md).
