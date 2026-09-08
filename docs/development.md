# Developing LookAway

For installation and everyday use, see the [README](../readme.md).

## Toolchain and builds

LookAway uses SwiftUI, AppKit, and ServiceManagement, targets macOS 15.4+, and has no third-party dependencies. CI uses Xcode 16.4 with Swift 5 language mode. Building and running require a Mac.

```sh
git clone https://github.com/longnt27/lookaway.git
cd lookaway
open LookAway.xcodeproj
```

Select the shared **LookAway** scheme and **My Mac**. Configure **Sign to Run Locally** or your own development team under **Signing & Capabilities**. No contributor's team ID is required.

To verify an unsigned universal build:

```sh
xcodebuild build \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CLANG_ENABLE_CODE_COVERAGE=NO GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=

xcrun lipo \
  build/DerivedData/Build/Products/Release/LookAway.app/Contents/MacOS/LookAway \
  -verify_arch arm64 x86_64
```

Output: `build/DerivedData/Build/Products/Release/LookAway.app`. This is not a signed, notarized installer. Use local signing in Xcode for your Mac and configure signing/notarization before distribution. Do not disable system-wide security protections.

## Preferences

The six Settings tabs are General, Breaks, Reminders, Schedule, Appearance, and Sounds. The menu command and Command-comma open one reusable window. Opening Settings intentionally activates LookAway; reminder windows do not. Settings cannot be opened over an active break.

`AppSettings` stores user-facing units, normalizes them, and converts scheduling values to `BreakConfiguration`. Preferences remain one JSON value at `UserDefaults["LookAway.settings.v1"]`. Older saves retain known fields and gain defaults for new ones. Unknown enum values fall back independently; malformed data falls back to defaults. Values are bounded before arithmetic. Unrelated defaults keys are never removed.

| Preference | Range / behavior |
| --- | --- |
| Work / break duration | 1–180 minutes / 5–600 seconds |
| Blink / posture interval | 1–120 minutes; independently enabled |
| Warning lead / visibility | 5–300 seconds, shorter than work / 3–30 seconds |
| Postponement | 1–60 minutes |
| Reminder visibility | 1–15 seconds |
| Early-finish delay | 0–60 seconds, shorter than the break; early finish can be disabled |
| Messages | 120 characters; whitespace normalized; empty means default |
| Dimming / text size | 0–90% / 80–150% |
| Sound volume | 0–100%; all four event sounds default off |
| Working hours | Local weekday selection and minute-of-day boundaries |

Timing presets change work/break durations and normalize dependent bounds, without replacing unrelated preferences. Disabling reminders retains their intervals. Zero warning lead in the scheduler disables warnings.

The editor owns a draft. Save persists/applies; Cancel or close discards edits; Restore Defaults only edits the draft. Reopening a visible window retains unsaved edits. Appearance and the static break preview reflect the draft without creating overlays or changing timers. Sound preview is an explicit temporary action.

**Launch at login is the exception to draft editing.** `LoginItemController` reads `SMAppService.mainApp.status` and changes registration only on an explicit toggle. It is not stored in `AppSettings`, changed by Restore Defaults, or reverted by Cancel. Errors and required approval are shown, and status refreshes when Settings opens or LookAway becomes active. Use an installed, signed app to test actual registration. See Apple's [SMAppService documentation](https://developer.apple.com/documentation/servicemanagement/smappservice).

## Runtime semantics

A changed `BreakConfiguration` starts a fresh work/reminder session, clears a pending skip, and preserves pause/sleep intent. Active breaks keep a settings snapshot and their existing countdown. Other settings do not reset work time. Saving dismisses obsolete warnings/reminders so they cannot retain old actions. Start-paused applies only on the next launch. Session progress is not persisted.

Skip suppresses exactly one scheduled break. Postpone adds the configured duration to the existing deadline and rearms the warning. Dismissing a warning does not move the deadline. Manual breaks override pending skips. Early-finish policy is checked in the controller as well as the button; disabling it does not prevent automatic completion or quitting the app.

`ActiveHoursGate` pauses work/reminders outside the selected hours, resumes only pauses it owns, and never interrupts a running break. Manual pauses remain manual; **Keep Paused** cancels the gate's automatic resume. Manual breaks remain available outside working hours. An overnight interval belongs to its starting day; equal start/end covers the entire selected day. An empty weekday list deliberately keeps automatic activity paused. Calendar time determines eligibility while monotonic time still measures durations. The heartbeat remains active during scheduled pauses and stops during system sleep.

Break/warning and reminder display selections are independent. Primary means the first `NSScreen.screens` entry, not `NSScreen.main` (which follows keyboard focus). Pointer selection is captured at presentation start, with primary fallback if that display is unavailable. Display refresh never restarts a break. Banners use each display's global visible frame and support top, center, or bottom placement.

Compact and full-screen reminders share countdown/completion logic and pass mouse input through. Simultaneous reminders share one presentation; a warning/reminder collision emits at most one sound. Overlays use white text on a dark background; the appearance picker controls the Settings window. System Reduce Motion and Reduce Transparency override decorative effects. This is a reminder app, not a keyboard lock.

## Code map

| File | Responsibility |
| --- | --- |
| `AppSettings.swift` | Defaults, presets, validation, migration, and persistence |
| `SettingsEditor.swift` | Draft editing and save/error handling |
| `SettingsView.swift`, `SettingsWindowController.swift` | Tabbed settings and reusable window |
| `LoginItemController.swift` | System-owned login registration and approval/errors |
| `ActiveHours.swift` | Local-calendar eligibility, pause ownership, countdown formatting |
| `BreakSchedule.swift` | Monotonic scheduling, reconfiguration, pause/skip/postpone/sleep |
| `AppDelegate.swift` | Menu, heartbeat, notifications, settings and sound coordination |
| `PresentationSupport.swift` | Display selection and per-event system sound playback |
| `OverlayController.swift`, `OverlayView.swift` | Shared countdown, presentation snapshots, early finish, preview content |
| `PopupBannerController.swift`, `PopupBannerView.swift` | Warning placement, one-shot actions, cancellation |
| `OverlayWindow.swift` | Non-activating AppKit panels |

## Tests and contributions

```sh
xcodebuild test \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Debug \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
```

The shared scheme runs `LookAwayTests`, not the generated UI-test starter target. Tests inject time, calendar/display inputs, and login-service closures. Preferences use isolated defaults suites. Automated tests never register the runner as a login item or require audible playback. Window tests cover construction and reuse, not end-to-end keyboard, VoiceOver, or screen rendering.

[CI](https://github.com/longnt27/lookaway/actions/workflows/ci.yml) runs regression tests with coverage, a universal Release build, and architecture verification. Results/logs are retained for seven days as `macos-test-results`. Release builds have no coverage instrumentation. Add regression tests for behavior changes and record desktop checks separately in [testing.md](testing.md). Do not commit build products or Xcode user state.

## Troubleshooting and scope

For signing errors, select your own local signing identity/team. For missing SDKs, install full Xcode and select it under **Settings > Locations > Command Line Tools**. Report display/focus issues with macOS version, display layout/scaling, and reproduction steps. For login-item problems, install the signed app in Applications and inspect the status/error and macOS Login Items settings.

There is no idle/meeting detection, session history, or automatic updater. Reminder functionality needs no network service, camera, microphone, Accessibility, or Screen Recording permission. LookAway is not a medical device. The repository does not currently declare a license in a `LICENSE` file.
