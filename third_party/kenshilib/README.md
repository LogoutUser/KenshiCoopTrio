# KenshiLib patches

`third_party/KenshiLib_deps/` is fetched, not committed (see the root README).
These patches make that checkout compile under the VC++ 2010 (v100) toolset.

Both fix genuine defects in KenshiLib's headers, not in KenshiCoop. Neither
changes any struct layout, so a patched build is binary-compatible with the
`KenshiLib.dll` that RE_Kenshi loads at runtime.

## Setup

```bash
git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps third_party/KenshiLib_deps
cd third_party/KenshiLib_deps
git checkout e75769b          # KenshiLib 0.3.0 - the layout KenshiCoop expects
git apply ../kenshilib/patches/0001-vc10-duplicate-enum-and-incomplete-type.patch
```

Then extract Boost (the repo ships it zipped, via git-lfs):

```bash
powershell -Command "Expand-Archive -Path third_party\KenshiLib_deps\boost_1_60_0\boost.zip -DestinationPath third_party\KenshiLib_deps\boost_1_60_0 -Force"
```

## Why the 0.3.0 pin

KenshiLib **0.4.0** (commit `b566d74`) moved `kenshi/CombatClass.h` into
`kenshi/combat/`, but that header still includes its siblings by bare quoted
name (`"Enums.h"`, `"util/hand.h"`), which resolve against `kenshi/` rather than
`kenshi/combat/`.

Putting `Include/kenshi` on the include path fixes those names but breaks the
build a different way: headers there use `#pragma once`, and VC10 keys that on
the resolved path *string*, so a file reachable as both
`<kenshi/Building/X.h>` and `<Building/X.h>` gets processed twice. Pinning to
0.3.0 avoids the whole question and matches the include paths KenshiCoop's
source was written against.

## What patch 0001 fixes

**1. `BuildingDesignation` declared twice.** `Platoon.h` and
`Building/Building.h` each declare the *identical* enum - Platoon.h even carries
a `// TODO move?` comment on it. `EngineInternal.h` includes both, so they meet
in one translation unit and VC10 rejects it (C2011). The patch wraps both in a
shared `KENSHILIB_BUILDINGDESIGNATION_DEFINED` guard; whichever is seen first
wins, and the definitions are byte-identical so it does not matter which.

**2. `CraftingItem` incomplete.** `CraftingBuilding.h` forward-declares
`class CraftingItem;` but then declares `std::deque<CraftingItem> crafting;` as a
member *by value*. VC10's `std::deque` instantiates against the element type and
needs it complete (C2027). The patch gives it an opaque one-byte definition.

That is layout-safe, which matters because a wrong layout here would corrupt
memory at runtime rather than fail loudly. `sizeof(std::deque<T>)` does not
depend on `T`, and KenshiLib's own offset comments confirm the expected size:

```
std::deque<CraftingItem, ...> crafting;  // 0x498 Member
itemType specialCraftItemType;           // 0x4C8 Member
```

`0x4C8 - 0x498 = 0x30` = 48 bytes, exactly what a VC10 x64 `std::deque` occupies
for any element type. Every member after it keeps its documented offset.

KenshiCoop never reads this container - it only forms member-function pointers
on `CraftingBuilding` (`_NV_operate`, `_NV_getProductionItemData`) for the
protocol-33 machine-state sync.
