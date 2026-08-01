# make_trio_kit.ps1 - package the friend-facing drag-and-drop kit.
#
# Run this AFTER a successful build. It picks up the freshly built DLL, drops it
# into dist/trio-kit/KenshiCoop/, records a provenance hash so three players can
# confirm they're on the same build, and zips the lot.
#
#   powershell -ExecutionPolicy Bypass -File scripts\make_trio_kit.ps1
#
# Output: dist\KenshiCoopTrio-kit.zip  <- this is the file you send to friends.

param(
    [string]$Config = 'Release',
    [string]$Dll    = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$kit  = Join-Path $repo 'dist\trio-kit'
$pay  = Join-Path $kit  'KenshiCoop'

Write-Host "=== packaging KenshiCoopTrio kit ===" -ForegroundColor Cyan

# ---- 1. Find the built DLL --------------------------------------------------
if (-not $Dll) {
    $Dll = Join-Path $repo "src\plugin\x64\$Config\KenshiCoop.dll"
}
if (-not (Test-Path $Dll)) {
    Write-Host "KenshiCoop.dll not found at: $Dll" -ForegroundColor Red
    Write-Host ""
    Write-Host "Build it first:" -ForegroundColor Yellow
    Write-Host "  cmd /c scripts\build_plugin.cmd Release"
    Write-Host ""
    Write-Host "The kit is useless without it - the .mod file is only a mod-list"
    Write-Host "entry; the DLL is the actual mod."
    exit 1
}

New-Item -ItemType Directory -Force -Path $pay | Out-Null
Copy-Item $Dll (Join-Path $pay 'KenshiCoop.dll') -Force
$hash = (Get-FileHash (Join-Path $pay 'KenshiCoop.dll') -Algorithm SHA256).Hash
Write-Host "  DLL       : $Dll"
Write-Host "  SHA-256   : $hash"

# ---- 2. Provenance ----------------------------------------------------------
# All three players must run the same build. The protocol check catches a
# mismatch at connect time, but comparing this line first is faster than
# discovering it after everyone has loaded a save.
$commit = ''
try { $commit = (git -C $repo rev-parse --short HEAD 2>$null) } catch { }
@"
KenshiCoopTrio build provenance
===============================
built      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
config     : $Config
commit     : $commit
protocol   : 46  (NOT compatible with upstream KenshiCoop v45)
dll sha256 : $hash

All three players must have the SAME sha256 above. If they differ, someone
is on a stale build and the session will refuse to connect.
"@ | Out-File (Join-Path $kit 'PROVENANCE.txt') -Encoding utf8 -Force

# ---- 3. Zip -----------------------------------------------------------------
$zip = Join-Path $repo 'dist\KenshiCoopTrio-kit.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $kit '*') -DestinationPath $zip -Force

$mb = [math]::Round((Get-Item $zip).Length / 1MB, 2)
Write-Host ""
Write-Host "=== done ===" -ForegroundColor Green
Write-Host "  $zip  ($mb MB)"
Write-Host ""
Write-Host "  Send that zip to your friends. They unzip it anywhere and"
Write-Host "  double-click INSTALL.cmd."
