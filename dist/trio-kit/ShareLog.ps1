# Collect KenshiCoop logs for diagnosis.
#
# Kenshi truncates KenshiCoop_*.log on every launch, so the session where
# something went wrong is destroyed the moment you relaunch. Run this BEFORE
# restarting.
#
# If this folder is inside a clone of the repo AND you have push access, it
# commits the logs to logs/<name>/ and pushes. Otherwise it just drops a zip on
# your Desktop to send over Discord. Either way the logs get off this machine.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow }

Say ""
Say "=== KenshiCoop log collector ==="
Say ""

# ---- find Kenshi -------------------------------------------------------------
function Find-Kenshi {
    $steam = $null
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam','HKCU:\SOFTWARE\Valve\Steam')) {
        try { $p = (Get-ItemProperty -Path $k -ErrorAction Stop).InstallPath; if ($p) { $steam = $p; break } } catch { }
    }
    if (-not $steam) { $steam = 'C:\Program Files (x86)\Steam' }
    $roots = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in (Get-Content $vdf)) {
            if ($line -match '"path"\s+"(.+?)"') { $roots += $Matches[1].Replace('\\','\') }
        }
    }
    foreach ($r in ($roots | Select-Object -Unique)) {
        $c = Join-Path $r 'steamapps\common\Kenshi'
        if (Test-Path (Join-Path $c 'kenshi_x64.exe')) { return $c }
    }
    return $null
}

$kenshi = Find-Kenshi
if (-not $kenshi) { $kenshi = (Read-Host "  Kenshi folder path").Trim('"') }
Ok "Kenshi: $kenshi"

# ---- gather ------------------------------------------------------------------
$who   = (Read-Host "  Your name (evan / zach / marsh)").Trim()
if (-not $who) { $who = $env:USERNAME }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $env:TEMP "kclogs-$stamp"
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$found = 0
foreach ($pat in @('KenshiCoop_*.log','RE_Kenshi_log.txt')) {
    Get-ChildItem -Path $kenshi -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $stage $_.Name) -Force
        Ok "collected $($_.Name)  ($([math]::Round($_.Length/1KB)) KB)"
        $found++
    }
}
# The mod's own config matters for diagnosis (which peers were armed).
$conf = Join-Path $kenshi 'mods\KenshiCoop\coop_config.json'
if (Test-Path $conf) { Copy-Item $conf (Join-Path $stage 'coop_config.json') -Force; Ok "collected coop_config.json" }

# Build identity - mismatched DLLs explain a whole class of problems.
$dll = Join-Path $kenshi 'mods\KenshiCoop\KenshiCoop.dll'
if (Test-Path $dll) {
    $h = (Get-FileHash $dll -Algorithm SHA256).Hash
    "dll sha256 : $h`nmachine    : $env:COMPUTERNAME`nwho        : $who`ncollected  : $(Get-Date)" |
        Out-File (Join-Path $stage 'BUILD.txt') -Encoding utf8
    Ok "DLL sha256 $($h.Substring(0,16))..."
}

if ($found -eq 0) { Warn "No KenshiCoop logs found - has the mod run on this machine?" }

# ---- publish -----------------------------------------------------------------
# Preferred: commit into the repo if this kit sits inside a clone with push access.
$repo = $root
while ($repo -and -not (Test-Path (Join-Path $repo '.git'))) {
    $parent = Split-Path -Parent $repo
    if ($parent -eq $repo) { $repo = $null; break }
    $repo = $parent
}

# Logs go to a PER-PLAYER BRANCH, never to main. main is Marsh's - it is the
# single authority for what the build actually is, and nothing lands there
# without going through him. A log branch keeps your evidence out of that path
# entirely, so sharing a log can never disturb the shipped build.
# NOTE ON THE GIT CALLS BELOW: no '2>&1', and $ErrorActionPreference is relaxed
# for this block. PowerShell wraps a native command's stderr in an ErrorRecord,
# which under 'Stop' becomes a TERMINATING error - so a routine git progress
# message on stderr aborted the whole block, the catch swallowed it, and the
# branch was never restored. That is exactly how an earlier version left a repo
# sitting on a logs-* branch while reporting only "couldn't push".
$pushed = $false
if ($repo) {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $orig = $null
    try {
        $branch = "logs-$who"
        $orig = (& git -C $repo rev-parse --abbrev-ref HEAD)
        & git -C $repo fetch origin | Out-Null
        # Fresh branch off origin/main each time: no merge conflicts, no history
        # to reconcile, and it cannot carry local code edits along.
        & git -C $repo checkout -B $branch origin/main | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "checkout failed (uncommitted changes?)" }
        $dest = Join-Path $repo "logs\$who"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item (Join-Path $stage '*') $dest -Recurse -Force
        & git -C $repo add "logs/$who" | Out-Null
        & git -C $repo commit -m "logs: $who $stamp" | Out-Null
        & git -C $repo push -u origin $branch --force | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Ok "pushed to branch '$branch' (main untouched)"
            Say "     readable at: logs/$who on branch $branch"
            $pushed = $true
        } else {
            Warn "push rejected - you may not have accepted the repo invite yet"
        }
    } catch {
        Warn "git step failed: $($_.Exception.Message)"
    } finally {
        # ALWAYS go back to the branch they were on, even if anything above blew
        # up. Leaving someone on a logs-* branch silently is worse than not
        # pushing at all - their next 'git pull' would look broken.
        if ($orig) { & git -C $repo checkout $orig 2>$null | Out-Null }
        $ErrorActionPreference = $prevEAP
    }
    if (-not $pushed) { Warn "falling back to a zip you can send over Discord" }
}

if (-not $pushed) {
    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) "KenshiCoop-logs-$who-$stamp.zip"
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
    Ok "saved $zip"
    Say ""
    Say "  Send that zip over Discord."
}

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Say ""
Read-Host "Press Enter to close"
