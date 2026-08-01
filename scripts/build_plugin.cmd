@echo off
REM Build KenshiCoop.dll with the legacy v100 (VC++ 2010) x64 toolchain on a
REM machine that has only "Windows SDK 7.1 + VC2010 SP1 compiler update" (no full
REM VS2010). We hand MSBuild a complete PATH/INCLUDE/LIB and UseEnv=true so it does
REM not rely on VS2010 registry/SDK auto-detection.
REM
REM Prereqs (see resources/BUILD_SETUP.md):
REM   - VC++ 2010 (v100) x64 compiler  (SDK 7.1 + KB2519277)
REM   - VS2022 Build Tools (for MSBuild.exe)
REM   - third_party/KenshiLib_deps (deps + Boost) and env vars set
REM   - third_party/enet/enet patched for C89 (scripts/apply_enet_patch is implicit;
REM     see third_party/enet/patches/0001-enet-c89-for-loops.patch)
setlocal

REM Build configuration (Phase 1 build separation). Default = Harness, the
REM optimized TEST build that INCLUDES the scenario runner - this is what the
REM regression/manual pipeline needs. Pass "Release" to produce the shipped
REM player DLL (no scenario code); "Debug" for a dev build.
REM   Usage:  scripts\build_plugin.cmd [Harness|Release|Debug]
set "CONFIG=%~1"
if "%CONFIG%"=="" set "CONFIG=Harness"

REM Repo root = parent of this script's folder.
set "REPO=%~dp0.."
pushd "%REPO%" >nul
set "REPO=%CD%"
popd >nul

set "VS10=C:\Program Files (x86)\Microsoft Visual Studio 10.0"
set "VC=%VS10%\VC"
set "SDK=C:\Program Files\Microsoft SDKs\Windows\v7.1"
set "KL=%REPO%\third_party\KenshiLib_deps"
set "ENET=%REPO%\third_party\enet\enet\include"

REM Locate MSBuild via vswhere (falls back to a common path).
set "MSBUILD="
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2^>nul`) do set "MSBUILD=%%i"
if not defined MSBUILD set "MSBUILD=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

REM x64 native toolchain on PATH so cl.exe finds its sibling DLLs (mspdb100, etc).
set "PATH=%VC%\bin\amd64;%VC%\bin;%VS10%\Common7\IDE;%SDK%\Bin\x64;%SDK%\Bin;%PATH%"

REM Headers: VC10 CRT + Win SDK 7.1 + vc10_compat ammintrin.h shim + our deps.
REM ...\Include\ogre is needed because the vendored ogre math headers include
REM each other by bare name ("OgreVector3.h"); vc10_compat also shims the
REM missing OgreConfig.h/OgrePlatformInformation.h that chain pulls in.
set "INCLUDE=%VC%\include;%SDK%\Include;%REPO%\third_party\vc10_compat;%KL%\KenshiLib\Include;%KL%\KenshiLib\Include\ogre;%KL%\boost_1_60_0;%ENET%"

REM Libs: VC10 x64 CRT + Win SDK 7.1 x64 + KenshiLib (kenshilib.lib, OgreMain_x64.lib).
set "LIB=%VC%\lib\amd64;%SDK%\Lib\x64;%KL%\KenshiLib\Libraries"

echo === Building KenshiCoop.dll (%CONFIG%^|x64, v100) ===
where cl.exe

REM UseEnv=true: use the INCLUDE/LIB/PATH above instead of registry-derived paths.
REM TrackFileAccess=false: avoid Tracker.exe TRK0002 under redirected shells.
REM VCTargetsPath: the project declares ToolsVersion 16.0, so a modern MSBuild
REM resolves $(VCTargetsPath) to its own VC\v170 folder - which only exists if
REM the "Desktop development with C++" workload was installed. We do not need
REM that workload (the compiler comes from SDK 7.1 + KB2519277), only the C++
REM BUILD TARGETS, and the v100-era ones sit in the shared MSBuild folder. Point
REM MSBuild there when the modern set is absent, so a Build Tools install
REM without the C++ workload still builds. See setup_toolchain.ps1.
REM NOTE: single-line IFs on purpose. The path contains "(x86)", and inside a
REM parenthesised IF block cmd treats that ")" as the block terminator.
REM The trailing "\\" is deliberate: MSBuild needs VCTargetsPath to END in a
REM separator (some imports concatenate without one), but a single backslash
REM before the closing quote would escape it and swallow the rest of the command
REM line. "\\" passes one literal backslash and closes the quote.
set "CPPTARGETS=%ProgramFiles(x86)%\MSBuild\Microsoft.Cpp\v4.0"
set VCTP=
if exist "%CPPTARGETS%\Microsoft.Cpp.Default.props" set VCTP=/p:VCTargetsPath="%CPPTARGETS%\\"
if defined VCTP echo Using v100-era C++ targets: %CPPTARGETS%

REM _TargetFrameworkDirectories / _FullFrameworkReferenceAssemblyPaths: the
REM v100-era targets default TargetFrameworkVersion to v4.0, so modern MSBuild
REM runs GetReferenceAssemblyPaths and fails with MSB3644 unless a .NET 4.0
REM targeting pack is installed. This is a NATIVE C++ DLL - it references no
REM managed assemblies at all - so the lookup is pure ceremony. Giving both
REM properties a dummy non-empty value satisfies the check without installing a
REM ~100 MB developer pack for something we never use.
set "NOREFASM=/p:_TargetFrameworkDirectories=none /p:_FullFrameworkReferenceAssemblyPaths=none"

"%MSBUILD%" "%REPO%\src\plugin\KenshiCoop.vcxproj" /p:Configuration=%CONFIG% /p:Platform=x64 /p:UseEnv=true /p:TrackFileAccess=false %VCTP% %NOREFASM% /nologo /v:minimal

endlocal
