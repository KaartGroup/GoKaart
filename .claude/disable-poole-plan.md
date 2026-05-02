# Disable Poole.ch Tile Calls — Plan

## Goal
Stop the Unnamed Roads feature from making any network calls to `tile2.poole.ch` / `tile3.poole.ch`. Reversible (commented-out, not deleted) so we can restore quickly when boss clarifies.

## Boss's complaint
"Please remove the qa.poole website data from the unnamed feature in go Kaart. I believe this should be as simple as not calling on the website data at all."

We don't yet know *why* — could be privacy, reliability, licensing. Until clarified, stop the calls.

## Current architecture (verified in code)
1. `TileServer.noName` (TileServer.swift:355) defines the Poole.ch tile URL
2. `TileServerList+JSON.swift:283` registers it in `externalAerials`
3. `MapView.toggleUnnamedRoads()` adds/removes the identifier from `tileOverlaySelections`
4. `MapView.updateTileOverlayLayers()` creates a `MercatorTileLayer` for it when selected — **this is what fetches from Poole.ch**
5. `MapView.useUnnamedRoadHalo()` returns `noNameLayer() != nil` — local halos in `EditorMapLayer.swift:788` depend on this returning true
6. `MapView.viewStateWillChangeTo` (line 1347) toggles tile layer visibility based on editor visibility

## The catch
If we only stop the layer from being created, `useUnnamedRoadHalo()` always returns false, so the **local** red halos in the editor break too. The Unnamed Roads button would appear to do nothing.

## Plan — minimal, reversible

### Change 1: Skip MercatorTileLayer creation for noName
**File:** `src/Shared/MapView.swift` — inside `updateTileOverlayLayers`, ~line 612

Add a skip *before* `let layer = MercatorTileLayer(...)` (~line 623):
```swift
// DISABLED 2026-05-01 per request: stop fetching tiles from poole.ch.
// Local halos in EditorMapLayer still work via useUnnamedRoadHalo() reading tileOverlaySelections.
if tileServer == TileServer.noName {
    continue
}
```

### Change 2: Decouple useUnnamedRoadHalo() from the tile layer
**File:** `src/Shared/MapView.swift` — line 2441

```swift
func useUnnamedRoadHalo() -> Bool {
    // DISABLED 2026-05-01: was `noNameLayer() != nil`. Now reads selections directly
    // since the tile layer is no longer created (poole.ch calls disabled).
    return UserPrefs.shared.tileOverlaySelections.value?.contains(TileServer.noName.identifier) ?? false
}
```

This keeps the toggle button → halo behavior working with no network call.

### Change 3: Force halo refresh on toggle
**File:** `src/Shared/MapView.swift` — inside `toggleUnnamedRoads` (~line 754)

Currently the editor halo redraw only fires inside `updateTileOverlayLayers` (line 579-580) when the selection vs `useUnnamedRoadHalo()` mismatch is detected. With Change 2 those values are always equal, so we add an explicit redraw:
```swift
UserPrefs.shared.tileOverlaySelections.value = overlays
editorLayer.clearCachedProperties()  // refresh halos immediately
updateUnnamedRoadsButtonAppearance()
```

### Change 4 (defensive): leave dead code commented, not removed
- Don't touch `TileServer.noName` definition (TileServer.swift:355)
- Don't touch `externalAerials.append(TileServer.noName)` (TileServerList+JSON.swift:283) — keeping it registered means the saved user selection isn't auto-cleared by the "server doesn't exist anymore" branch in `updateTileOverlayLayers`
- Don't touch `noNameLayer()` or `viewStateWillChangeTo` Hidden swap — they become inert no-ops since the layer is never created

## What changes for users
- Unnamed Roads button still toggles. Red halos at editor zoom still appear.
- **At far zoom (basemap mode), unnamed road highlighting is gone** — that's the Poole.ch feature, which is what boss asked us to disable.
- No network requests to poole.ch.

## Reversibility
To restore: revert the 3 changed blocks. Each has a `DISABLED 2026-05-01` comment marker for easy grep.

## Verification checklist
1. Build succeeds (Xcode, simulator)
2. Toggle Unnamed Roads ON → red halos appear on unnamed highways at editor zoom
3. Toggle OFF → halos disappear
4. Network monitoring: no requests to `tile*.poole.ch` in either state
5. At far zoom (basemap), no unnamed-road overlay (expected regression)

## Branch & commit
- Branch: `feature/disable-poole-tiles` (no Trello card — boss email request)
- Commit message: "Disable poole.ch tile calls for Unnamed Roads feature per request"
- After verification, merge to master and push for TestFlight build (deadline: Monday 2026-05-04 EOD)

## Open questions for boss (after we ship)
- Is "qa.poole" a typo for "poole.ch", or a different staging URL we should also check for?
- What's the underlying concern (privacy, reliability, cost, license)?
- Should we build a local far-zoom replacement, or is editor-zoom-only acceptable long-term?
