# GoKaart — handoff (current as of 2026-10-13)

Written for whoever picks this repo up after Chris Gousset (GitHub `CEFgoose`) leaves Kaart. Everything here was checked against the code, git history and GitHub on 2026-10-13 unless it says otherwise.

## 1. What it is, and who uses it

- **GoKaart** is Kaart's fork of [Go Map!!](https://github.com/bryceco/GoMap) (Bryce Cogswell's iPhone/iPad OpenStreetMap editor). GitHub: `KaartGroup/GoKaart` (public, a GitHub fork of `bryceco/GoMap`).
- Used by Kaart field/editing staff on iPads (mostly iPad mini, in vehicles) to edit OSM, name streets and record GPX traces. Distributed **only through TestFlight**, not the public App Store.
- **Status: frozen.** On 2026-08-19 it was forked into **`KaartGroup/maprizon-mobile`** (private), which is where all active iOS work now happens (Maprizon camera + GoKaart editor in one app). GoKaart stays as the shipping fallback until Maprizon Mobile replaces it on devices. Do not build new Maprizon features here.
- Last release: **GoKaart 4.5.0, build 4315** (commit `d84f87704`, 2026-05-08). Nothing has shipped since; the two later commits are a secret removal and a README banner.

## 2. Architecture

Upstream layout is described in `README.md` (`src/iOS` = UI, `src/Shared` = map/OSM engine, `src/presets`, `src/xliff`, etc.) and `Architecture.png`. Kaart's changes sit on top, ~4,600 lines across 86 files versus the last upstream merge (`7ca25ec86`, 2026-01-13). The Kaart-specific pieces:

| Feature | Where |
|---|---|
| Unnamed-roads toggle + red halos (Poole.ch far-zoom tiles **disabled** 2026-05-01, grep `DISABLED 2026-05-01`) | `src/Shared/MapView.swift`, `EditorLayer/EditorMapLayer.swift` |
| Power Naming mode (tap a highway → name field focused) | `MapView.swift`, `UserPrefs.swift` (`mapViewEnablePowerNaming`), `POI/POICommonTagsViewController.swift`, `POI/POITabBarController.swift` |
| Planning mode (binoculars button), zoom label, aerial-with-basemap mode | `MapView.swift`, `CustomViews/ZoomLevelLabel.swift`, `Tiles/MapLibreVectorTilesView.swift` |
| GPX background recording fixes, Live Activity | `MainViewController.swift`, `SceneDelegate.swift`, `Shared/LocationProvider.swift`, `DisplaySettings/GpxViewController.swift` |
| Viewer camera upload (Auth0 PKCE login → `POST https://viewer.kaart.com/backend/api/still-images/upload`) | `src/iOS/ViewerUpload.swift`, `PhotoCapture.swift`, `Settings/SettingsViewController.swift` |
| Vehicle tracking pings (`https://viewer.kaart.com/backend/api/vehicle`) | `src/iOS/ViewerTracking.swift` |
| Older Kaart edits (2018–2024, Devin Markley): replace/merge-tags paste, one-way reverse, polygon fill, GPX colours, tertiary-road colour | various |

**Two of those integrations are dead in the current build — know this before a user reports it:**
- **Vehicle tracking:** the Maprizon backend deleted `/backend/api/vehicle/*` and its tables on 2026-08-03 (viewer migration `4aefad332a47`). Pings now fail silently. (Removed in maprizon-mobile; still present here.)
- **Viewer camera login:** GoKaart borrowed the Maprizon *web* app's confidential Auth0 client and shipped its client secret in the binary. The secret was removed from the code on 2026-09-03 (`5269dbb8b`) and was to be rotated in Auth0, so camera login/upload is expected to fail. The secret is **still in git history** of this public repo — treat it as burned; confirm it was rotated (see section 7).

`src/iOS/*.secret` (Google Maps, Mapbox Locator, Maxar) are upstream Go Map!!'s obfuscated imagery keys, decoded by an Xcode build rule. They are not Kaart credentials.

## 3. Build and run locally

- macOS + current Xcode (the project builds on Xcode 26 / iOS 26 SDK). Open `src/iOS/Go Map!!.xcodeproj`, scheme **Go Map!!**, run on a simulator or a device.
- Signing: automatic, Apple team **`2STHX823T6`** (the GoKaart targets). Bundle IDs: `com.kaartgroup.GoKaart`, `.GpxWidget`, `.PhotoShare`. Two configurations still reference upstream's team `MKTTC6734C`; tests keep `com.bryceco.*` IDs.
- Camera, compass and background GPS only work on a real device.
- SwiftFormat is the style tool (see README). No package installs are needed beyond Xcode's Swift Package resolution.

## 4. Release / deploy

- **There is no automated release.** `src/iOS/fastlane/` is upstream's: `Appfile` is still placeholder text and the `beta` lane needs a `match` certificate repo Kaart never set up. Releases were done by hand: bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` (see `d84f87704` for the pattern), Product → Archive in Xcode, upload from the Organizer to App Store Connect, then enable the build for the TestFlight testers. *(Inferred from history; the App Store Connect side could not be inspected from here.)*
- **CI** (`.github/workflows/ci.yml`, "XCode tests") has failed on every run since at least 2026-05-08. Cause: it pins the simulator `OS=26.1, name=iPhone 17 Pro`, which the GitHub macOS runner does not have ("Unable to find a device matching the provided destination specifier"). It is not a code failure. Fix by updating the destination if CI is ever wanted again.

## 5. Upstream (bryceco/GoMap) sync

- Remote `upstream` = `https://github.com/bryceco/GoMap.git`. Last merged 2026-01-15 (`5de2c9a32`). As of 2026-10-13 upstream is **666 commits ahead**; Kaart is 38 commits ahead of upstream.
- **Policy (recorded on Trello, 2026-08-19): no bulk merges.** A previous bulk merge broke the app and cost a month; a 2026-08 test merge produced 17 conflicted files, 11 hunks in `MapView.swift` alone. If something from upstream is needed: triage read-only, agree a shortlist, hand-apply one change at a time. Nothing upstream is required for the current build.
- Since GoKaart is frozen, any upstream work now belongs in `maprizon-mobile`.

## 6. What is in flight

**Open PRs on `KaartGroup/GoKaart`:** none. (Careful: plain `gh pr list` in a clone with the `upstream` remote can list *bryceco/GoMap*'s PRs. Use `-R KaartGroup/GoKaart`.)

**Open GitHub issues:** #35–#40 (point/markup waypoints, GPX/GeoJSON colours, GPX delete crash, custom paint styles, low-class roads vanishing when zoomed out, Overpass-only loading). None has been worked since 2025.

**Branches:**
- Local in Chris's clone: `feature/disable-poole-tiles` — **already shipped** (contained in `master`). `docs/not-maprizon-mobile` — merged as PR #41. Nothing local is unshipped. (The clone also has two uncommitted planning notes, `.claude/binoculars-corner-plan.md` and `.claude/maprizon-mobile-plan.md`; the Maprizon plan lives on in the maprizon-mobile repo.)
- Remote `35-ability-to-add-a-pointmarkup-not-for-osm-purposes-but-traveler-usefullness` (Devin Markley, Jan 2025): 6 commits **not on master** — waypoint markers with types, saved into and shared with GPX files (issue #35). Never merged; would need rebasing onto 2026 code.
- Remote `GoMap-Merge`: fully contained in master; nothing to do.

**Trello board "GoKaart"** (id `64fa5713b3e661b84b12e997`, read 2026-10-13):
- *Blocked / Waiting:* "Maprizon Mobile v0 — needs test org, device, and Auth0 client type" (2026-08-19). Partly stale: the `maprizon-mobile` GitHub repo now exists, and the client secret has since been removed (section 2). The other items — a Maprizon test org, a physical test device, the Auth0 client type, and the open decisions about `facing`, binding sessions to trips, and the timelapse preset — belong to maprizon-mobile.
- *In Progress:* "Maprizon Mobile — v0" (the maprizon-mobile work; see that repo). Two GPS bugs moved from the TM4 board: GPX traces stop recording when GoKaart is backgrounded or another app is in front. Fixes for background GPX recording were committed in March 2026 (`f06e22a1c`, `124464fef`, `1e8dc3eba`) and shipped in 4.4.0/4.5.0, but the cards were never confirmed closed by a field test.
- *Needs Testing:* "Power Naming Mode" — the code is on master and shipped. Its device test checklist is still unticked.
- *UI Changes (requests, not started):* move the camera button away from the + button, make the camera controls bigger for iPad mini, make the Unnamed Roads toggle work when zoomed out. The last one is no longer possible since the Poole.ch far-zoom layer was disabled.
- *Exploratory:* Viewer still-image upload (built, now broken by the auth change) and live GPS sharing to Viewer (built as vehicle tracking, now dead server-side). Both are superseded by maprizon-mobile.

## 7. Accounts and access a successor needs

No secret values are in this document.

- **GitHub** `KaartGroup` org: admin or write on `GoKaart` and `maprizon-mobile`. Chris's account is `CEFgoose`. ACCESS TRANSFER NEEDED for any repo where he is the only admin.
- **Apple Developer / App Store Connect**, team `2STHX823T6`: App Manager or Admin to archive, upload and manage TestFlight testers for `com.kaartgroup.GoKaart`. ACCESS TRANSFER NEEDED if Chris's Apple ID is the Account Holder, or the only person who manages testers or signing certificates.
- **Auth0** tenant `dev-p6r3cciondp4has2.us.auth0.com` (shared with Maprizon): confirm that the client secret leaked in GoKaart's git history was rotated after 2026-09-03. **Not verified.** A native app should get its own public (Token Endpoint Auth Method = None) client.
- **Trello** "GoKaart" board: board admin. ACCESS TRANSFER NEEDED if Chris is the only admin. Chris's Claude Code automation (skills `gokaart-daily-briefing`, `gokaart-trello-monitor` in his `~/.claude/skills`) used his personal Trello API token. It is not in this repo and does not transfer.
- **Weblate / gomaposm.com** credentials in the README's "Updating external assets" belong to upstream (Bryce), not Kaart. Kaart does not need them; pull translations and presets by merging upstream instead.

## 8. Could not be verified from the repo

- Whether TestFlight still serves build 4315 to testers, and who the testers are.
- Whether the Auth0 secret was actually rotated, and whether `viewer.kaart.com` still accepts still-image uploads from this client.
- Who holds the Apple Developer Account Holder role.
