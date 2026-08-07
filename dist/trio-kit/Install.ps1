# KenshiCoopTrio installer.
#
# Finds Kenshi (via Steam's library list, or asks), copies the mod in, and
# writes the co-op config. Safe to re-run - it overwrites its own files and
# touches nothing else.
#
# Run via INSTALL.cmd (double-click). No admin needed: Steam's game folders are
# writable by the owning user.

$ErrorActionPreference = 'Stop'
$kitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "  [ok]   $m"   -ForegroundColor Green }
function Warn($m) { Write-Host "  [warn] $m"   -ForegroundColor Yellow }
function Fail($m) { Write-Host "  [FAIL] $m"   -ForegroundColor Red }

Say ""
Say "=============================================="
Say "  KenshiCoopTrio - three-player co-op for Kenshi"
Say "=============================================="
Say ""

# ---- 1. Locate Kenshi -------------------------------------------------------
# Steam can install games to several drives; libraryfolders.vdf lists them all.
function Find-Kenshi {
    $steam = $null
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam','HKCU:\SOFTWARE\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $k -ErrorAction Stop).InstallPath
            if ($p) { $steam = $p; break }
        } catch { }
    }
    if (-not $steam) { $steam = 'C:\Program Files (x86)\Steam' }

    $roots = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in (Get-Content $vdf)) {
            if ($line -match '"path"\s+"(.+?)"') {
                $roots += $Matches[1].Replace('\\','\')
            }
        }
    }
    foreach ($r in ($roots | Select-Object -Unique)) {
        $cand = Join-Path $r 'steamapps\common\Kenshi'
        if (Test-Path (Join-Path $cand 'kenshi_x64.exe')) { return $cand }
    }
    return $null
}

Say "[1/4] Looking for Kenshi..."
$kenshi = Find-Kenshi
if (-not $kenshi) {
    Warn "Couldn't find Kenshi automatically."
    Say ""
    Say "  Paste your Kenshi folder path (the one containing kenshi_x64.exe):"
    $kenshi = (Read-Host "  Path").Trim('"')
    if (-not (Test-Path (Join-Path $kenshi 'kenshi_x64.exe'))) {
        Fail "No kenshi_x64.exe there. Nothing was changed."
        Read-Host "Press Enter to close"; exit 1
    }
}
Ok "Kenshi: $kenshi"

# ---- 2. RE_Kenshi check -----------------------------------------------------
# The plugin is loaded BY RE_Kenshi; without it nothing happens at all, so this
# is worth failing loudly on rather than letting someone launch and wonder.
Say ""
Say "[2/4] Checking RE_Kenshi..."
$cfg = Join-Path $kenshi 'Plugins_x64.cfg'
$hasRe = (Test-Path (Join-Path $kenshi 'KenshiLib.dll')) -or
         ((Test-Path $cfg) -and (Select-String -Path $cfg -Pattern 'RE_Kenshi' -Quiet))
if ($hasRe) {
    Ok "RE_Kenshi is installed."
} else {
    Warn "RE_Kenshi NOT found - the co-op mod cannot load without it."
    Say ""
    Say "    Get it here (free), install it, then run this again:"
    Say "    https://github.com/BFrizzleFoShizzle/RE_Kenshi/releases/latest"
    Say ""
    $go = Read-Host "  Continue installing anyway? (y/N)"
    if ($go -ne 'y') { Say "  Stopped. Nothing was changed."; Read-Host "Press Enter to close"; exit 1 }
}

# ---- 3. Copy the mod --------------------------------------------------------
Say ""
Say "[3/4] Installing the mod..."
$src = Join-Path $kitRoot 'KenshiCoop'
$dll = Join-Path $src 'KenshiCoop.dll'
if (-not (Test-Path $dll)) {
    Fail "KenshiCoop.dll is missing from this kit."
    Say "      This kit was packaged without a compiled plugin - see BUILD.md"
    Say "      in the repo. Nothing was changed."
    Read-Host "Press Enter to close"; exit 1
}
$modsDir = Join-Path $kenshi 'mods'
$dest    = Join-Path $modsDir 'KenshiCoop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
Ok "Copied to $dest"

# ---- 4. Config --------------------------------------------------------------
Say ""
Say "[4/4] Co-op config..."
Say ""
Say "  Who are you in this session?"
Say "    1) HOST  (you need BOTH friends' Steam IDs)"
Say "    2) JOIN  (you need only the HOST's Steam ID)"
$role = Read-Host "  Choose 1 or 2"

# Pre-filled for THIS group so nobody has to retype a 17-digit number. Press
# Enter to accept, or paste a different ID to override.
$DEFAULT_HOST = '76561199417484463'   # Marsh
$DEFAULT_P1   = '76561198346257175'   # Evan
$DEFAULT_P2   = '76561199025713332'   # Zach

# Who is running this installer? A peer list must NEVER contain your own ID.
# Field evidence 2026-08-06: Zach installed as HOST, accepted the pre-filled
# defaults, and got himself as steamPeer2 - the plugin then opened a Steam P2P
# tunnel to his own account. The session churned ("peer connected id=1" twice,
# then "peer left id=1") and Evan could never hold a slot. The defaults were
# written assuming Marsh hosts, so they list the two OTHER players; whoever is
# not Marsh inherits a roster containing themselves and missing Marsh.
#
# SteamID64 = 76561197960265728 + ActiveUser (the 32-bit account id Steam keeps
# in the registry for the logged-in user).
function Get-LocalSteamId64 {
    try {
        $au = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction Stop).ActiveUser
        if ($au -and [uint64]$au -ne 0) {
            return [string]([uint64]76561197960265728 + [uint64]$au)
        }
    } catch { }
    return $null
}

$ME = Get-LocalSteamId64
$NAMES = @{
    '76561199417484463' = 'Marsh'
    '76561198346257175' = 'Evan'
    '76561199025713332' = 'Zach'
}
if ($ME) {
    $who = $NAMES[$ME]
    if (-not $who) { $who = 'unrecognised account' }
    Ok "Detected this machine's Steam account: $ME ($who)"
    # Re-point the defaults at the two people who are NOT you.
    $others = @($DEFAULT_HOST, $DEFAULT_P1, $DEFAULT_P2) | Where-Object { $_ -ne $ME }
    if ($others.Count -ge 2) { $DEFAULT_P1 = $others[0]; $DEFAULT_P2 = $others[1] }
    if ($DEFAULT_HOST -eq $ME) { $DEFAULT_HOST = $others[0] }
} else {
    Warn "Couldn't read your Steam ID from the registry - skipping the self-peer check."
    Warn "Make sure the IDs you enter are your FRIENDS', never your own."
}

# Reject an ID that is this machine's own account, and reject duplicates. Both
# produce a session that looks connected and does not work.
function Test-PeerId([string]$id, [string]$label, [string[]]$already) {
    if (-not $id) { return $true }
    if ($ME -and $id -eq $ME) {
        Fail "$label is THIS machine's own Steam ID ($id)."
        Say  "      A host must list its FRIENDS, never itself - a self-tunnel"
        Say  "      makes joins connect and immediately drop."
        return $false
    }
    if ($already -contains $id) {
        Fail "$label repeats an ID already entered ($id)."
        return $false
    }
    return $true
}

$confPath = Join-Path $dest 'coop_config.json'
if ($role -eq '1') {
    Say ""
    Say "  Press Enter to accept the pre-filled ID, or paste a different one."
    do {
        $p1 = (Read-Host "  Friend #1 SteamID64 [$DEFAULT_P1]").Trim()
        if (-not $p1) { $p1 = $DEFAULT_P1 }
    } until (Test-PeerId $p1 'Friend #1' @())
    do {
        $p2 = (Read-Host "  Friend #2 SteamID64 [$DEFAULT_P2] (or '-' for 2-player)").Trim()
        if (-not $p2) { $p2 = $DEFAULT_P2 }
    } until ($p2 -eq '-' -or (Test-PeerId $p2 'Friend #2' @($p1)))
    # 'role' matters beyond convenience: the plugin arms the combat-report role
    # and picks its log filename from this at LOAD. Without it every client boots
    # as host, and a join that only picks JOIN in the F2 panel used to stay
    # combat-disabled all session (and write KenshiCoop_host.log).
    $conf = [ordered]@{ role = 'host'; transport = 'steam'; steamPeer = $p1 }
    if ($p2 -and $p2 -ne '-') { $conf.steamPeer2 = $p2 }
} else {
    Say ""
    Say "  Press Enter to accept the host's ID below, or paste a different one."
    do {
        $h = (Read-Host "  HOST's SteamID64 [$DEFAULT_HOST]").Trim()
        if (-not $h) { $h = $DEFAULT_HOST }
    } until (Test-PeerId $h "The host's ID" @())
    # A join talks ONLY to the host; the host relays the other join's state.
    # role=join also makes the plugin arm combat reporting and write
    # KenshiCoop_join.log instead of masquerading as a host - see the host branch.
    $conf = [ordered]@{ role = 'join'; transport = 'steam'; steamPeer = $h }
}
($conf | ConvertTo-Json) | Out-File -FilePath $confPath -Encoding utf8 -Force
Ok "Wrote $confPath"

Say ""
Say "=============================================="
Say "  Done. Next:"
Say "=============================================="
Say ""
Say "  1. Launch Kenshi and enable KenshiCoop in the Mods menu."
Say "  2. Set Kenshi to WINDOWED (Options > Video > uncheck Full Screen)."
Say "  3. Make sure Steam is running and ONLINE (not offline mode)."
Say "  4. HOST: load a save, split units into 3 squad tabs, press F2,"
Say "     set Role HOST, Connection ONLINE."
Say "     JOINS: from the main menu press F2, Role JOIN, Connection ONLINE."
Say ""
Say "  Everyone must run the SAME build, or you'll get 'protocol mismatch'."
Say "  Logs: $kenshi\KenshiCoop_*.log"
Say ""
Read-Host "Press Enter to close"
