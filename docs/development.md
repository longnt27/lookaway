# Developing LookAway

For installation and everyday use, see the [README](../readme.md).

## Toolchain

LookAway uses SwiftUI and AppKit, targets macOS 15.4 or later, and has no third-party dependencies. CI uses Xcode 16.4 with Swift 5 language mode. Building and running require a Mac.

```sh
git clone https://github.com/longnt27/lookaway.git
cd lookaway
open LookAway.xcodeproj
```

Select the shared **LookAway** scheme and **My Mac**. Configure **Sign to Run Locally** or your own development team under **Signing & Capabilities**. The project does not require a contributor's team ID.

## Command-line builds

Run from the repository root to build both Apple Silicon and Intel architectures:

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

Output: `build/DerivedData/Build/Products/Release/LookAway.app`.

This verifies an unsigned build; it does not produce a signed, notarized installer. Use local signing in Xcode for your own Mac, and configure signing and notarization before distributing a release. Do not disable system-wide security protections to launch a build.

## Settings and timing

Users configure the app through **Settings…** in the status menu. Command-comma opens the same window while LookAway is active. The menu command is unavailable during a break because its overlays would cover the settings window.

[`AppSettings`](../LookAway/AppSettings.swift) stores user-facing units and converts them to [`BreakConfiguration`](../LookAway/BreakSchedule.swift). Preferences are encoded as one JSON value in `UserDefaults` under `LookAway.settings.v1`. Missing fields retain defaults; malformed data falls back to defaults. Both reads and writes normalize numeric values before scheduler arithmetic.

| Preference | Allowed range |
| --- | --- |
| Work interval | 1–180 minutes |
| Break duration | 5–600 seconds |
| Blink/posture intervals | 1–120 minutes, independently enabled |
| Warning lead time | 5–300 seconds, always shorter than the work interval |
| Reminder display time | 1–15 seconds |

Disabling a reminder retains its selected interval. Disabling warnings maps to a zero warning interval in the scheduler. Banner visibility remains 10 seconds, configured in `PopupBannerController.show`; postponement remains five minutes.

The settings editor owns a draft. **Save** persists and applies it; **Cancel** or closing the window discards edits. **Restore Defaults** changes only the draft until saved. Reopening a visible window retains unsaved edits; reopening a closed window reloads saved values. Settings never clear unrelated `UserDefaults` keys.

Saving a changed scheduling configuration starts a fresh work session and reminder intervals, clears a pending skip, and dismisses obsolete warnings/reminders. Paused timers remain paused, including across sleep. An active break keeps its existing overlay countdown and uses the new configuration after completion. Unchanged settings or a countdown-display-only change do not reset the session. Session progress itself is not persisted between launches.

### Scheduling behavior

- Finishing a break starts a full work session and resets reminder intervals. Simultaneous blink/posture reminders share one overlay and cannot replace an active break.
- **Skip Break** leaves the current countdown running. At zero, a fresh work session starts instead of a break. A manual break overrides a pending skip; repeated manual actions cannot restart an active break.
- **+ 5 Minutes** extends the current deadline and rearms the warning. **I Know**, the close button, and warning timeout dismiss the banner without changing the schedule.
- Pause and sleep preserve remaining work and reminder time. Manual pause survives sleep. Sleeping during a break ends that break and starts a fresh work session on wake.

## Architecture

| File | Responsibility |
| --- | --- |
| [`AppSettings.swift`](../LookAway/AppSettings.swift) | Preference defaults, bounds, decoding, persistence, and conversion to scheduler units |
| [`SettingsEditor.swift`](../LookAway/SettingsEditor.swift) | Draft editing, restore defaults, and save/error handling |
| [`SettingsView.swift`](../LookAway/SettingsView.swift), [`SettingsWindowController.swift`](../LookAway/SettingsWindowController.swift) | Native settings form and reusable window lifecycle |
| [`BreakSchedule.swift`](../LookAway/BreakSchedule.swift) | Clock-driven state machine, reconfiguration, pause, skip, postpone, and sleep transitions |
| [`AppDelegate.swift`](../LookAway/AppDelegate.swift) | Menu bar, heartbeat, system notifications, settings application, and UI coordination |
| [`OverlayController.swift`](../LookAway/OverlayController.swift) | Shared countdown, display windows, and exactly-once completion |
| [`PopupBannerController.swift`](../LookAway/PopupBannerController.swift) | Monitor-relative warning placement, one-shot actions, and cancellation |
| [`OverlayWindow.swift`](../LookAway/OverlayWindow.swift) | Non-activating AppKit panel configuration |
| [`OverlayView.swift`](../LookAway/OverlayView.swift), [`PopupBannerView.swift`](../LookAway/PopupBannerView.swift) | SwiftUI presentation and accessibility labels |
| [`LookAwayTests/`](../LookAwayTests/) | Scheduling, settings, persistence, and presentation regression tests |

Monotonic deadlines avoid timer drift and dependence on wall-clock changes. Presentation identifiers prevent stale buttons or delayed dismissals from affecting a newer overlay. Countdown and completion are shared across displays; display changes rebuild overlays without restarting the countdown and dismiss warning banners.

Reminder panels do not explicitly activate LookAway. Opening Settings does activate it so the form can receive keyboard input. Brief reminders pass through mouse input; break overlays receive it. This is a reminder app, not a keyboard lock or security boundary. Full-screen, Spaces, focus, and accessibility behavior still require [manual testing](testing.md).

## Tests and contributions

Choose **Product > Test** in Xcode, or run:

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

The shared scheme runs `LookAwayTests`, not the generated `LookAwayUITests` starter target. Tests inject clocks and display providers rather than waiting through work sessions. Preference tests use isolated, uniquely named defaults suites and remove only those suites after each test. Window tests exercise construction and close/reopen behavior; they are not end-to-end keyboard or VoiceOver tests.

[GitHub Actions](https://github.com/longnt27/lookaway/actions/workflows/ci.yml) runs regression tests with coverage and a universal Release build on pushes and pull requests. The `macos-test-results` artifact retains results and logs for seven days. Coverage is enabled explicitly for CI tests, not ordinary Release builds.

Keep changes focused, add regression tests for timing or lifecycle fixes, and run the macOS suite before submitting a pull request. Record manual checks separately using the [testing checklist](testing.md). Do not commit build products, `DerivedData`, or Xcode user state. Quit any running copy before replacing the installed app.

## Build troubleshooting

**Signing errors:** Select your own local signing configuration or team. The unsigned commands above are suitable for build/test verification.

**Missing Xcode or macOS SDK:** Install the full Xcode application, open it to finish setup, and select it under **Xcode > Settings > Locations > Command Line Tools**.

**Display or focus issues:** Include your macOS version, display layout/scaling, and reproduction steps in an [issue](https://github.com/longnt27/lookaway/issues). Note whether the problem occurs when a panel appears, is clicked, or disappears.

## Current scope

There is no built-in launch-at-login setting, idle or meeting detection, saved session history, or automatic updater. Reminder functionality does not use network access or require camera, microphone, Accessibility, or Screen Recording permissions. LookAway is not a medical device or a substitute for professional care.

The repository does not currently declare a license in a `LICENSE` file.
