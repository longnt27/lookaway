# LookAway

A native macOS menu-bar app that reminds you to blink, adjust your posture, and take a short screen break.

LookAway keeps a countdown in your menu bar, shows brief reminders while you work, and presents a shared break countdown across your connected displays. It uses SwiftUI and AppKit, with no third-party dependencies, accounts, or network service.

> This is an independent personal project inspired by LookAway from Mystical Bits, LLC. It is not affiliated with or endorsed by the commercial app. Please consider supporting the original developers.

## How it works

| Event | Default |
| --- | --- |
| Work session | 30 minutes |
| Screen break | 30 seconds |
| Blink reminder | Every 5 minutes of the work session |
| Posture reminder | Every 10 minutes of the work session |
| Reminder display | 2 seconds, followed by a brief fade-out |
| Advance warning | 1 minute before a scheduled break; visible for 10 seconds |

The work session starts when you launch the app. Finishing a break starts a fresh work session and resets the reminder intervals. Reminders that fall due together share one overlay; they never replace an active break.

### Menu-bar controls

Click the countdown in the menu bar to open the menu.

| Control | Behavior |
| --- | --- |
| **Start Break Now** | Starts a break immediately, including while paused. Overrides a pending skip. Unavailable during an existing break. |
| **Pause Timer** | Freezes the remaining work and reminder time, and dismisses any warning or reminder. |
| **Resume Timer** | Continues from the remaining time rather than starting over. |
| **Quit LookAway** | Stops all timers and closes the app's overlays. |

During a break, **I'm ready** becomes available after 3 seconds. Clicking it on any display ends the break on every display. Otherwise, the break ends automatically when its countdown reaches zero. The menu-bar countdown shows the remaining break time too.

### Before a scheduled break

The warning offers three choices:

- **I Know** or **X**: dismiss the warning without changing the schedule. Letting the warning time out has the same effect.
- **Skip Break**: skip only the upcoming scheduled break. The current countdown continues; when it reaches zero, a fresh 30-minute work session starts instead of a break. Later breaks happen normally.
- **+ 5 Minutes**: add five minutes to the current deadline. Another warning appears one minute before the postponed break.

An action on one display dismisses the warning on all displays and is applied only once.

### Focus, sleep, and displays

Warnings and overlays use non-activating panels: displaying them does not explicitly activate LookAway or make another application lose its keyboard focus. Brief reminders also let mouse events pass through. Break overlays receive mouse input, but **this is a reminder app, not a keyboard lock or security boundary**.

Work and reminder timers freeze while the Mac sleeps. A manually paused timer stays paused after waking. Sleeping during a break ends that break and starts a fresh work session on wake. Quitting and reopening the app also starts a new session; progress is not saved between launches.

Break overlays are rebuilt when the display arrangement changes, without restarting the countdown. Warnings are dismissed on display changes to avoid leaving controls on a disconnected display. Full-screen, Spaces, and focus behavior should be checked on your setup using the [manual test checklist](docs/testing.md).

## Requirements

- **macOS 15.4 or later**. The project is macOS-only.
- **Xcode 16.4** is the CI toolchain. Use it or a compatible newer version to build the app.
- A Mac for building and running; AppKit is not available on Linux or Windows.

There are no Swift packages, CocoaPods, or other dependencies to install. The project uses Swift 5 language mode with the compiler included in Xcode.

## Build and install

### With Xcode

```sh
git clone https://github.com/longnt27/lookaway.git
cd lookaway
open LookAway.xcodeproj
```

1. Select the shared **LookAway** scheme and **My Mac** as the run destination.
2. In the app target's **Signing & Capabilities**, use **Sign to Run Locally** for your own Mac, or select your own development team. No contributor's team ID is required by the project.
3. Choose **Product > Run**. Look for the countdown in the menu bar: the app does not open a main window or show a Dock icon.
4. To install a build outside Xcode, locate **Products > LookAway.app > Show in Finder**, then copy the app to **Applications** and open it. Quit any running copy before replacing it.

### From the command line

Run this from the repository root to build a universal Apple Silicon and Intel app without a development account:

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
```

The build output is `build/DerivedData/Build/Products/Release/LookAway.app`.

**This command verifies an unsigned build; it does not create a signed, notarized installer.** Use the Xcode signing flow above for local use, and configure appropriate signing and notarization before distributing a build to other people. Do not disable system-wide security protections to launch a build.

## Development

### Change the timing defaults

All scheduling defaults are in [`BreakConfiguration`](LookAway/BreakSchedule.swift):

```swift
struct BreakConfiguration {
    var workSeconds = 30 * 60
    var breakSeconds = 30
    var blinkSeconds = 5 * 60
    var postureSeconds = 10 * 60
    var warningSeconds = 60
    var reminderSeconds = 2
}
```

Edit these values and rebuild to use different intervals. Work, break, and reminder intervals must be positive; the warning interval may be zero. There is currently no settings interface. The banner's visibility duration is configured separately in `PopupBannerController.show`.

### Run the regression tests

Choose **Product > Test** in Xcode, or run:

```sh
xcodebuild test \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Debug \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
```

The shared scheme runs the `LookAwayTests` target: deterministic scheduling tests plus controller, countdown, callback, layout, and panel-configuration tests. Tests inject time and display providers rather than waiting through real work sessions. The generated `LookAwayUITests` starter target is not part of this regression suite.

[GitHub Actions](https://github.com/longnt27/lookaway/actions/workflows/ci.yml) runs the tests and a universal Release build on pushes and pull requests. Test results, coverage, and build logs are retained as the `macos-test-results` artifact for seven days. The workflow uses read-only repository permissions and pinned action revisions.

Automated tests do not establish that focus, physical monitor arrangements, or full-screen behavior work on every Mac. Use [`docs/testing.md`](docs/testing.md) for those checks.

### Code map

| File | Responsibility |
| --- | --- |
| `LookAway/BreakSchedule.swift` | Clock-driven work/break state machine, timing defaults, pause, skip, postpone, and sleep transitions |
| `LookAway/AppDelegate.swift` | Menu bar, heartbeat, system notifications, and coordination between the schedule and UI |
| `LookAway/OverlayController.swift` | Shared break/reminder countdown, display windows, and exactly-once presentation completion |
| `LookAway/PopupBannerController.swift` | Monitor-relative warning placement, one-shot actions, and timeout cancellation |
| `LookAway/OverlayWindow.swift` | Non-activating AppKit panel configuration |
| `LookAway/OverlayView.swift`, `LookAway/PopupBannerView.swift` | SwiftUI presentation and accessibility labels |
| `LookAwayTests/` | Scheduling and presentation regression tests |

Scheduling uses monotonic deadlines instead of subtracting one second per timer callback. This keeps delayed callbacks from extending sessions and avoids depending on changes to the wall clock. Presentation identifiers prevent an old button or delayed dismissal from affecting a newer overlay.

## Troubleshooting and limitations

**The app appears to do nothing.** Look in the menu bar, not the Dock. Open its menu and choose **Start Break Now** to check that it is running.

**Xcode reports a signing error.** Select your own local signing configuration or team, not someone else's. The unsigned command-line commands above are also suitable for build/test verification.

**`xcodebuild` cannot find Xcode or the macOS SDK.** Install the full Xcode application, open it once to finish setup, and select it in **Xcode > Settings > Locations > Command Line Tools**.

**No reminder is appearing.** Check that the timer is not paused. Reminder time advances only during work sessions and resets after a break or skipped cycle.

**A warning or overlay behaves oddly with another display or full-screen app.** Record your macOS version, display layout/scaling, and reproduction steps, then [open an issue](https://github.com/longnt27/lookaway/issues). Include whether the problem occurs when a panel appears, when you click it, or when it disappears.

There is no built-in launch-at-login setting, idle or meeting detection, saved session history, automatic updater, or configurable settings window. The app does not use network access or require camera, microphone, Accessibility, or Screen Recording permission for its reminder functionality. It is not a medical device or a substitute for professional care.

## Contributing

Keep changes focused, add regression tests for timing or lifecycle fixes, and run the macOS test suite before submitting a pull request. Describe any manual focus/display checks you performed separately from automated test results. Do not commit `DerivedData`, build products, or Xcode's per-user state.

The repository does not currently declare a license in a `LICENSE` file.
