# Camera Fixes Plan — 3 Issues

## Fix 1: Viewer Logout UI

**Problem:** No way to log out of Viewer after authenticating for camera or GPS tracking.

**Approach:**
- Add a "Log out of Viewer" button in the settings footer alongside the existing "Vehicle Tracking" button
- Only show it when `ViewerAuth.shared.isLoggedIn` is true
- On tap, confirm with alert, then call `ViewerAuth.shared.logout()` and refresh the footer
- Also stop tracking if active, since logout invalidates the session

**Files:**
- `src/iOS/Settings/SettingsViewController.swift` — add logout button to footer, add handler

---

## Fix 2: Camera Landscape Orientation

**Problem:** Opening camera in landscape shows mostly black screen with camera strip at top/bottom.

**Root cause:** `PhotoCapture.viewDidLoad()` calculates `cameraViewTransform` using `picker.view.bounds.size` which reflects landscape dimensions when presented from landscape. The portrait lock prevents rotation *after* presentation, but the initial layout is already wrong.

**Approach:**
- Move frame and transform calculations from `viewDidLoad` to `viewDidLayoutSubviews`
- This fires after the view settles to its final (portrait) geometry
- Use a flag to only calculate once (avoid recalculating on every layout pass)

**Files:**
- `src/iOS/PhotoCapture.swift` — move layout calc to `viewDidLayoutSubviews`

---

## Fix 3: Multi-Photo Sessions

**Problem:** Camera dismisses after each photo, requiring re-open for every shot.

**Approach:**
- After accepting a photo, return to capture mode instead of dismissing
- Fire `onAccept` for each photo (queues upload) but stay in camera
- Add a photo counter label to show "N photos taken"
- Cancel/X button becomes "Done" — always visible, dismisses camera when user is finished
- `onAccept` callback changes to fire per-photo without expecting dismissal
- `ViewerUploadViewController.presentCapture` adapts: `onAccept` no longer dismisses, add `onDone` callback for final dismissal

**Files:**
- `src/iOS/PhotoCapture.swift` — multi-photo flow, counter, Done button
- `src/iOS/ViewerUpload.swift` — adapt `ViewerUploadViewController.presentCapture`
