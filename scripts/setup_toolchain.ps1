# setup_toolchain.ps1 - install the VC++ 2010 (v100) x64 toolchain.
#
# MUST RUN AS ADMINISTRATOR.
#
#   Right-click Start > Terminal (Admin), then:
#     powershell -ExecutionPolicy Bypass -File C:\Users\marsh\Projects\KenshiCoopTrio\scripts\setup_toolchain.ps1
#
# WHY THIS IS FIDDLY
# ------------------
# Kenshi 1.0.65 was built with Visual C++ 2010, and a KenshiLib plugin shares the
# game's C++ runtime and ABI. A DLL built with any modern toolset will crash the
# game, so the 2010 x64 compiler is a hard requirement.
#
# Windows SDK 7.1 carries that compiler, but its installer REFUSES to run when a
# newer VC++ 2010 redistributable is present - which is why step 2 removes them.
#
# Kenshi itself imports MSVCR100.dll / MSVCP100.dll from the system and ships no
# local copy, so KENSHI WILL NOT LAUNCH between steps 2 and 6. That window is the
# entire risk of this script, and step 6 always runs (finally block) even if the
# SDK install fails - so a failed run still leaves you able to play.
#
# Nothing else in a typical Steam library uses the 2010 runtime; modern games use
# VCRuntime140, and games that do need 2010 usually ship their own copy locally.

$ErrorActionPreference = 'Stop'
$repo  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tools = Join-Path $repo 'tools'

function Step($n,$m) { Write-Host ""; Write-Host "[$n] $m" -ForegroundColor Cyan }
function Ok($m)      { Write-Host "    [ok]   $m" -ForegroundColor Green }
function Warn($m)    { Write-Host "    [warn] $m" -ForegroundColor Yellow }
function Bad($m)     { Write-Host "    [FAIL] $m" -ForegroundColor Red }

# ---- 0. Preflight -----------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Bad "Not running as Administrator."
    Write-Host ""
    Write-Host "  Right-click Start > 'Terminal (Admin)', then re-run:" -ForegroundColor Yellow
    Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit 1
}

$sdkExe = Join-Path $tools 'winsdk_web.exe'
$kbExe  = Join-Path $tools 'VC-Compiler-KB2519277.exe'
foreach ($f in @($sdkExe,$kbExe)) {
    if (-not (Test-Path $f)) { Bad "Missing installer: $f"; exit 1 }
    if ((Get-AuthenticodeSignature $f).Status -ne 'Valid') {
        Bad "Signature check failed on $f - do not run it."; exit 1
    }
}
Ok "Both Microsoft installers present and signature-valid."

Write-Host ""
Write-Host "  This will temporarily remove the VC++ 2010 runtime." -ForegroundColor Yellow
Write-Host "  KENSHI WILL NOT LAUNCH until this finishes (restored at the end)." -ForegroundColor Yellow
Write-Host "  Budget 30-60 minutes. Close Kenshi and Steam downloads first."
Write-Host ""
if ((Read-Host "  Continue? (y/N)") -ne 'y') { Write-Host "  Cancelled. Nothing changed."; exit 0 }

$restoreNeeded = $false
try {
    # ---- 1. Record what's installed -----------------------------------------
    Step 1 "Recording current VC++ 2010 redistributables"
    $had = @()
    foreach ($id in @('Microsoft.VCRedist.2010.x64','Microsoft.VCRedist.2010.x86')) {
        $out = winget list --id $id --exact 2>$null | Out-String
        if ($out -match [regex]::Escape($id)) { $had += $id; Ok "present: $id" }
    }
    if (-not $had) { Warn "No 2010 redists found - SDK 7.1 may install cleanly already." }

    # ---- 2. Remove them (Kenshi breaks here) --------------------------------
    Step 2 "Removing VC++ 2010 redistributables (Kenshi offline from here)"
    foreach ($id in $had) {
        $restoreNeeded = $true
        winget uninstall --id $id --exact --silent --disable-interactivity 2>&1 | Out-Null
        Ok "removed $id"
    }

    # ---- 3. Windows SDK 7.1 --------------------------------------------------
    Step 3 "Installing Windows SDK 7.1 (this is the slow one)"
    Warn "If this fails, it is almost always a leftover 2010 redist. See NOTE at the end."
    $p = Start-Process -FilePath $sdkExe -ArgumentList '-q','-params:ADDLOCAL=ALL' -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Warn "SDK installer exit code $($p.ExitCode) - continuing to verify anyway."
    }
    $vc10 = 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC'
    $sdk  = 'C:\Program Files\Microsoft SDKs\Windows\v7.1'
    if (Test-Path $sdk)  { Ok "SDK at $sdk" }        else { Warn "SDK not found at $sdk" }
    if (Test-Path $vc10) { Ok "VC10 at $vc10" }      else { Warn "VC10 not found at $vc10" }

    # ---- 4. KB2519277 (restores the x64 compiler) ---------------------------
    Step 4 "Installing VC++ 2010 SP1 compiler update (KB2519277)"
    $p = Start-Process -FilePath $kbExe -ArgumentList '/quiet','/norestart' -Wait -PassThru
    Ok "installer exit code $($p.ExitCode)"

    # ---- 5. MSBuild ----------------------------------------------------------
    Step 5 "Installing VS2022 Build Tools (for MSBuild)"
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        Ok "Visual Studio installer already present - skipping."
    } else {
        winget install --id Microsoft.VisualStudio.2022.BuildTools --exact `
                       --accept-package-agreements --accept-source-agreements `
                       --disable-interactivity 2>&1 | Out-Null
        if (Test-Path $vswhere) { Ok "Build Tools installed." } else { Warn "Build Tools may not have installed." }
    }
}
finally {
    # ---- 6. ALWAYS restore the runtime (Kenshi playable again) --------------
    if ($restoreNeeded) {
        Step 6 "Restoring VC++ 2010 redistributables (Kenshi playable again)"
        foreach ($id in @('Microsoft.VCRedist.2010.x64','Microsoft.VCRedist.2010.x86')) {
            winget install --id $id --exact --accept-package-agreements `
                           --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        }
        $sys = Test-Path 'C:\Windows\System32\msvcr100.dll'
        if ($sys) { Ok "msvcr100.dll back in System32 - Kenshi will launch." }
        else      { Bad "msvcr100.dll MISSING. Run: winget install Microsoft.VCRedist.2010.x64 Microsoft.VCRedist.2010.x86" }
    }
}

# ---- 7. Verify the compiler -------------------------------------------------
Step 7 "Verifying the x64 v100 compiler"
$cl = 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64\cl.exe'
if (Test-Path $cl) {
    Ok "FOUND: $cl"
    Write-Host ""
    Write-Host "  Toolchain is ready. Next:" -ForegroundColor Green
    Write-Host "    cd `"$repo`""
    Write-Host "    cmd /c scripts\build_plugin.cmd Release"
    Write-Host ""
    Write-Host "  Expect compile errors on the first run - the trio changes have"
    Write-Host "  never been through a compiler. Paste them back to Claude to fix."
} else {
    Bad "x64 compiler NOT found at $cl"
    Write-Host ""
    Write-Host "  NOTE - the usual cause:" -ForegroundColor Yellow
    Write-Host "  SDK 7.1 silently skips its compilers when ANY newer VC++ 2010"
    Write-Host "  package is still installed. Open Settings > Apps, remove anything"
    Write-Host "  named 'Microsoft Visual C++ 2010 ... 10.0.40219' (all of them),"
    Write-Host "  then re-run this script. Your Kenshi is playable meanwhile."
}
Write-Host ""
