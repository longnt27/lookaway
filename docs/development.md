# Developing LookAway

For installation and everyday use, see the [README](../readme.md).

## Toolchain and builds

LookAway uses SwiftUI, AppKit, and ServiceManagement, targets macOS 15.4+, and has no third-party dependencies. CI uses Xcode 16.4 with Swift 5 language mode. Building and running require a Mac.

```sh
git clone https://github.com/longnt27/lookaway.git
cd lookaway
open LookAway.xcodeproj
```

Select the shared **LookAway** scheme and **My Mac**. Configure **Sign to Run Locally** or your own development team under **Signing & Capabilities**. No contributor team ID is required.

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

## Preferences and settings architecture

Settings has five tabs: **General**, **Breaks**, **Reminders**, **Appearance**, and **Sounds**. Working Hours belongs to General. Global reminder presentation belongs to Appearance. The Reminders tab only manages reminder objects.

The settings window uses compact shared row primitives from `SettingsComponents.swift`. Every ordinary value row has one stable label column and one aligned control column. Do not reintroduce `Form`, `LabeledContent`, free-stretching controls, or explanatory helper paragraphs. Only actionable warnings/errors should add extra text.

`AppSettings` owns user-facing units and one generic reminder collection:

```swift
struct Reminder: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var message: String
    var intervalMinutes: Int
    var enabled: Bool
}
```

Fresh settings seed Blink and Posture, but those are ordinary reminders after creation. Users may rename, reorder, disable, delete, or replace them with arbitrary reminders. An empty reminder array is valid.

Preferences remain one JSON value at `UserDefaults["LookAway.settings.v1"]`. Saves from the old hardcoded Blink/Posture model are migrated in place when no `reminders` array exists. Once a reminders array is present, even an empty one, it is authoritative and defaults are not recreated.

| Preference | Range / behavior |
| --- | --- |
| Work / break duration | 1–180 minutes / 5–600 seconds |
| Reminder interval | 1–120 minutes per reminder |
| Reminder visibility | 1–15 seconds globally |
| Reminder name/message | Required, whitespace-normalized, max 120 characters |
| Warning lead / visibility | 5–300 seconds, shorter than work / 3–30 seconds |
| Postponement | 1–60 minutes |
| Early-finish delay | 0–60 seconds, shorter than the break |
| Dimming / text size | 0–90% / 80–150% |
| Sound volume | 0–100%; event sounds default off |
| Working hours | Local weekday selection and minute-of-day boundaries |

Timing presets change work/break durations and dependent bounds without replacing unrelated preferences or reminders.

The editor owns a draft. Save persists/applies; Cancel or close discards edits; Restore Defaults only edits the draft. Reminder add/delete/reorder operations are draft-only until Save. Invalid blank reminder names/messages block saving rather than receiving invented fallback text.

**Launch at login is the exception to draft editing.** `LoginItemController` reads and changes `SMAppService.mainApp` directly. Restore Defaults and Cancel do not alter that system registration.

## Reminder scheduling

`BreakSchedule` schedules reminders generically by UUID. `BreakConfiguration.reminders` contains enabled reminder IDs and intervals, while reminder messages and presentation duration stay in `AppSettings`.

Reminder configuration is reconciled by ID:

- Reordering, renaming, or changing a message does not reset work time or reminder deadlines.
- Adding or enabling a reminder starts its interval from the configuration-change time.
- Removing or disabling a reminder removes its active deadline.
- Changing one reminder interval restarts only that reminder.
- Changing work/break timing starts a fresh work session, preserving the existing pause/sleep rules.
- A finished break starts a fresh cycle for all enabled reminders.
- Delayed timer callbacks emit each overdue reminder once and rearm it from the current monotonic time rather than replaying a backlog.

When multiple reminder IDs are due on the same tick, `ReminderPresentationResolver` resolves the current enabled reminder objects in settings order and combines their messages into one presentation. One global reminder sound may play for that combined event.

`ActiveHoursGate` pauses work/reminders outside selected hours and resumes only pauses it owns. Manual pauses remain manual. Sleep freezes monotonic work/reminder remaining time rather than accumulating missed reminder events.

## Break and presentation behavior

Skip suppresses exactly one scheduled break. Postpone adds the configured duration to the existing deadline and rearms the warning. Manual breaks override pending skips. Active breaks keep their existing countdown and settings snapshot when saved preferences change.

Break/warning and reminder display selections are independent. Primary display means the first `NSScreen.screens` entry. Pointer selection is captured when a presentation starts, with primary fallback. Compact and full-screen reminders share countdown/completion logic and pass mouse input through.

## Updates

`UpdateController` checks `latest.json` from GitHub Releases shortly after launch and every 30 minutes. `AppDelegate` also checks after wake.

A background check only changes the menu state. It never silently installs an update. When the user chooses `Update to version x.x.x`, the updater downloads the ZIP, verifies SHA-256 and bundle metadata, stages a replacement, relaunches LookAway, and records the expected version. On the next successful launch, AppDelegate shows an update-success popover from the status item.

Update installation is blocked during an active break.

## Code map

| File | Responsibility |
| --- | --- |
| `AppSettings.swift` | Reminder model, defaults, normalization, migration, persistence |
| `BreakSchedule.swift` | Monotonic work/break and generic reminder scheduling |
| `SettingsEditor.swift` | Draft editing, reminder operations, validation, save errors |
| `SettingsComponents.swift` | Shared compact aligned settings rows |
| `SettingsView.swift` | Five-tab settings information architecture |
| `ReminderSettingsView.swift` | Reminder cards, drag reordering, Add Reminder sheet |
| `SettingsWindowController.swift` | Reusable compact settings window and break preview |
| `LoginItemController.swift` | System-owned login registration and approval/errors |
| `ActiveHours.swift` | Local-calendar eligibility, pause ownership, countdown formatting |
| `AppDelegate.swift` | Menu, heartbeat, notifications, settings, updater coordination |
| `PresentationSupport.swift` | Reminder resolution, display selection, sound routing |
| `OverlayController.swift`, `OverlayView.swift` | Shared countdown, overlay lifecycle, early finish |
| `PopupBannerController.swift`, `PopupBannerView.swift` | Warning placement and actions |
| `UpdateController.swift` | Periodic update checks, verification, installation |

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

The shared scheme runs `LookAwayTests`. Tests use injected time/display/service inputs and isolated UserDefaults suites. Automated tests never register the runner as a login item or require audible playback.

[CI](https://github.com/longnt27/lookaway/actions/workflows/ci.yml) runs the regression suite, builds a universal arm64/x86_64 Release app, verifies both architectures, and retains logs/results. Add regression coverage for behavior changes and record desktop checks in [testing.md](testing.md).

## Troubleshooting and scope

For signing errors, select your own local signing identity/team. For missing SDKs, install full Xcode and select it under **Settings > Locations > Command Line Tools**. For login-item problems, install the signed app in Applications and inspect macOS Login Items.

LookAway has no idle/meeting detection or session history. Reminder functionality needs no camera, microphone, Accessibility, or Screen Recording permission. GitHub access is used for update checks/downloads. LookAway is not a medical device.
