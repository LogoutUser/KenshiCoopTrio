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

$confPath = Join-Path $dest 'coop_config.json'
if ($role -eq '1') {
    $p1 = (Read-Host "  Friend #1 SteamID64 (17 digits)").Trim()
    $p2 = (Read-Host "  Friend #2 SteamID64 (blank for a 2-player game)").Trim()
    $conf = [ordered]@{ transport = 'steam'; steamPeer = $p1 }
    if ($p2) { $conf.steamPeer2 = $p2 }
} else {
    $h = (Read-Host "  HOST's SteamID64 (17 digits)").Trim()
    $conf = [ordered]@{ transport = 'steam'; steamPeer = $h }
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
