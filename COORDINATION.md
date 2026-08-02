# Coordination protocol

How the three of us — and our AI instances — work on this without stepping on
each other. Modelled on the Wired Verdict operating agreement, with one
deliberate difference: this is **hub-and-spoke, not a peer hive.**

---

## Authority

**Marsh's instance is the primary authority.** It holds the build, the toolchain
and the history of every fix, and it is the only one that writes to `main`.

Evan's and Zach's instances are **spokes**. They diagnose locally, gather
evidence, and propose — they do not land changes.

This is not a hierarchy for its own sake. Only one machine in this group can
compile the plugin (VC++ 2010 v100 + patched KenshiLib), and every client must
run a byte-identical DLL or the protocol check refuses the connection. A single
writer is what keeps "everyone is on the same build" true by construction
instead of by hope.

```
              ┌──────────────────────┐
              │   MARSH (primary)    │  builds · owns main · ships the kit
              │   - toolchain        │
              │   - authority on     │
              │     what ships       │
              └───────┬──────────────┘
                      │  main (protected)
        ┌─────────────┴─────────────┐
        │                           │
   ┌────▼─────┐               ┌─────▼────┐
   │  EVAN    │               │  ZACH    │   spokes
   │ logs-evan│               │ logs-zach│   evidence + proposals
   └──────────┘               └──────────┘
```

---

## Branch rules

| Branch | Who writes | Purpose |
|---|---|---|
| `main` | **Marsh only** | the shipped build + source. Protected. |
| `logs-evan` | Evan | session logs, pushed by `SHARE_LOG.cmd` |
| `logs-zach` | Zach | session logs, pushed by `SHARE_LOG.cmd` |
| `fix/*` | anyone | a proposed change — opens a PR, Marsh merges |

Nothing reaches `main` without going through Marsh. `SHARE_LOG.cmd` pushes to a
per-player log branch precisely so sharing evidence can never disturb the build.

---

## What a spoke instance should do

**Diagnose locally, escalate with evidence.** The logs are rich enough to answer
most questions without guessing — `FRIEND_BRIEFING.md` has the decoder table.

When something breaks:

1. Run `SHARE_LOG.cmd` **before relaunching** — Kenshi truncates its logs on
   every launch, and a restart destroys the session. This has already cost
   three separate diagnoses.
2. Say what you observed in plain terms ("mobs went invisible when they ran up
   to Evan"), not a theory. The observation is the durable part; theories are
   cheap to regenerate.
3. If you have a fix, push a `fix/*` branch and open a PR. Do not push `main`.

**Do not install a DLL you compiled yourself.** Only Marsh's build is
authoritative; a locally-built one will differ and the connection will be
refused, or worse, silently diverge.

## What the primary instance owes the spokes

- A build that matches `PROVENANCE.txt`
- An honest `STATUS.md` — what works, what is unproven, what is known broken
- A reason, not just an instruction, when it asks for something

---

## Ground rules for all instances

**Check, don't assume.** Nearly every real bug tonight was found by reading a
log or grepping the source, and nearly every wrong turn came from reasoning
about what the code probably did. When a claim can be verified in seconds,
verify it.

**Report what is unproven as unproven.** This mod is experimental and much of it
has never been exercised with three players. A confident wrong answer costs an
evening.

**Preserve evidence before acting.** Restarting, reinstalling and "trying
something" all destroy state. Capture first.

**Same build or no session.** If a connection is refused with
`protocol mismatch`, compare SHA-256s from `PROVENANCE.txt` before theorising.

---

## Licence

AGPL-3.0, inherited from [nhoral/KenshiCoop](https://github.com/nhoral/KenshiCoop).
Anyone handed a compiled DLL is entitled to the source; keeping this repo public
and the link attached satisfies that.
