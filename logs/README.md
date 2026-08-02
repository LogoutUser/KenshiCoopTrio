# Logs

Drop-off point for session logs so they can be diagnosed.

Run `SHARE_LOG.cmd` from the kit **before relaunching Kenshi** - the game
truncates `KenshiCoop_*.log` on every launch, so restarting destroys the
session you wanted looked at.

One folder per player (`logs/evan`, `logs/zach`, `logs/marsh`). Each carries the
mod log, the RE_Kenshi log, `coop_config.json`, and a `BUILD.txt` with the
DLL SHA-256 - mismatched builds explain a whole class of problems on their own.
