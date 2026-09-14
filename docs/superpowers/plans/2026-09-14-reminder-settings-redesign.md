# Reminder and Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded Blink/Posture reminders with user-managed reminder objects and rebuild Settings into a compact five-tab UI with consistent alignment, cards, an Add Reminder modal, migrated persistence, and rewritten documentation.

**Architecture:** `AppSettings` owns a generic `[Reminder]` collection and migrates legacy Blink/Posture fields in place. `BreakSchedule` schedules reminders by stable UUID and reconciles reminder-only configuration changes without restarting the work timer. Settings is split into shared compact row primitives plus reminder-specific views so the main tabs stay small while Reminders can grow naturally.

**Tech Stack:** Swift 5, SwiftUI, AppKit, XCTest, UserDefaults JSON persistence, Xcode 16.4, macOS 15.4+, no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-14-reminder-settings-redesign-design.md`

## Global Constraints

- Keep `UserDefaults["LookAway.settings.v1"]`; migration happens in place.
- Fresh installs seed exactly two ordinary reminders: Blink at 5 minutes and Posture at 10 minutes, both enabled.
- Blink/Posture may be renamed, reordered, disabled, or deleted and receive no privileged runtime behavior.
- The reminder array may be empty.
- Reminder names/messages are required for saving, whitespace-normalized, and capped at 120 characters.
- Reminder-only edits do not restart the main work timer.
- Simultaneous reminders render as one presentation in reminder-list order.
- Reminder presentation and reminder sound settings stay global.
- Remove the Schedule tab and move Working Hours into General.
- Move Reminder Presentation into Appearance.
- Use one compact label/control alignment system across Settings and keep ordinary helper prose absent.
- Target a roughly 700x500 default Settings window where default General and Breaks content fit without vertical scrolling.
- Keep updater, launch-at-login, break, active-hours, and sound behavior unchanged except where this plan explicitly changes reminder handling.
- Rewrite `readme.md` so it accurately describes custom reminders, five settings tabs, automatic update checks, user-triggered installation, and the update-success popover.

---

### Task 1: Generic reminder model, validation, persistence, and migration

**Files:**
- Modify: `LookAway/AppSettings.swift`
- Create: `LookAwayTests/ReminderSettingsTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`
- Modify: `LookAwayTests/ExtendedSettingsTests.swift`

**Interfaces:**
- Produces: `Reminder: Codable, Equatable, Identifiable`
- Produces: `Reminder.defaultBlink`, `Reminder.defaultPosture`, `Reminder.blinkID`, `Reminder.postureID`
- Produces: `AppSettings.reminders: [Reminder]`
- Produces: `AppSettings.reminderValidationMessage: String?`
- Keeps: `SettingsStore.storageKey == "LookAway.settings.v1"`

- [ ] **Step 1: Write failing reminder default/normalization tests**

Create `LookAwayTests/ReminderSettingsTests.swift`:

```swift
import XCTest
@testable import LookAway

final class ReminderSettingsTests: XCTestCase {
    func testFreshDefaultsSeedBlinkAndPostureAsOrdinaryReminders() {
        let reminders = AppSettings.defaults.reminders
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.map(\.name), ["Blink", "Posture"])
        XCTAssertEqual(reminders.map(\.message), ["Blink your eyes", "Adjust your posture"])
        XCTAssertEqual(reminders.map(\.intervalMinutes), [5, 10])
        XCTAssertEqual(reminders.map(\.enabled), [true, true])
    }

    func testEmptyReminderCollectionRoundTripsWithoutReseedingDefaults() throws {
        var settings = AppSettings.defaults
        settings.reminders = []
        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(restored.reminders, [])
    }

    func testReminderNormalizationPreservesIdsOrderAndBounds() {
        let first = Reminder(id: UUID(), name: "  Water  ", message: "  Drink\nwater  ", intervalMinutes: 999, enabled: true)
        let second = Reminder(id: UUID(), name: " Stretch ", message: String(repeating: "x", count: 200), intervalMinutes: -3, enabled: false)
        var settings = AppSettings.defaults
        settings.reminders = [first, second]
        let value = settings.normalized
        XCTAssertEqual(value.reminders.map(\.id), [first.id, second.id])
        XCTAssertEqual(value.reminders.map(\.name), ["Water", "Stretch"])
        XCTAssertEqual(value.reminders.map(\.message), ["Drink water", String(repeating: "x", count: 120)])
        XCTAssertEqual(value.reminders.map(\.intervalMinutes), [120, 1])
    }

    func testBlankReminderFieldsRemainInvalid() {
        var settings = AppSettings.defaults
        settings.reminders = [Reminder(name: "   ", message: "Drink", intervalMinutes: 5, enabled: true)]
        XCTAssertEqual(settings.normalized.reminderValidationMessage, "Reminder name is required.")
        settings.reminders[0].name = "Water"
        settings.reminders[0].message = " \n\t "
        XCTAssertEqual(settings.normalized.reminderValidationMessage, "Reminder message is required.")
    }
}
```

- [ ] **Step 2: Write failing migration and one-way encoding tests**

Add:

```swift
func testLegacyBlinkAndPostureFieldsMigrateIntoReminders() throws {
    let data = Data(#"{"blinkEnabled":false,"blinkMinutes":8,"blinkMessage":"Slow blink","postureEnabled":true,"postureMinutes":17,"postureMessage":"Sit tall"}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data)
    XCTAssertEqual(settings.reminders.map(\.id), [Reminder.blinkID, Reminder.postureID])
    XCTAssertEqual(settings.reminders.map(\.enabled), [false, true])
    XCTAssertEqual(settings.reminders.map(\.intervalMinutes), [8, 17])
    XCTAssertEqual(settings.reminders.map(\.message), ["Slow blink", "Sit tall"])
}

func testStoredReminderArrayWinsOverLegacyFields() throws {
    let custom = Reminder(id: UUID(), name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
    let remindersJSON = String(decoding: try JSONEncoder().encode([custom]), as: UTF8.self)
    let data = Data("{\"reminders\":\(remindersJSON),\"blinkEnabled\":true,\"postureEnabled\":true}".utf8)
    XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: data).reminders, [custom])
}

func testNewEncodingDoesNotWriteLegacyReminderFields() throws {
    let data = try JSONEncoder().encode(AppSettings.defaults)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertNotNil(json["reminders"])
    for key in ["blinkEnabled", "blinkMinutes", "blinkMessage", "postureEnabled", "postureMinutes", "postureMessage"] {
        XCTAssertNil(json[key])
    }
}
```

- [ ] **Step 3: Run the focused tests and verify red**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderSettingsTests
```

Expected: compile/test failures because `Reminder` and `AppSettings.reminders` do not exist.

- [ ] **Step 4: Implement `Reminder` and replace hardcoded reminder fields**

In `AppSettings.swift`:

```swift
struct Reminder: Codable, Equatable, Identifiable {
    static let blinkID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static let postureID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!

    static let defaultBlink = Reminder(id: blinkID, name: "Blink", message: "Blink your eyes", intervalMinutes: 5, enabled: true)
    static let defaultPosture = Reminder(id: postureID, name: "Posture", message: "Adjust your posture", intervalMinutes: 10, enabled: true)

    var id: UUID = UUID()
    var name: String
    var message: String
    var intervalMinutes: Int
    var enabled: Bool
}
```

Replace the six `blink*`/`posture*` stored properties with:

```swift
var reminders: [Reminder] = [.defaultBlink, .defaultPosture]
```

Keep `reminderSeconds`, `reminderDisplays`, `reminderStyle`, `bannerPosition`, and `soundOnReminder` as global settings.

- [ ] **Step 5: Implement normalization and validation**

Add a cleaner that does not invent fallback text:

```swift
private static func cleanedText(_ value: String, limit: Int) -> String {
    let clean = value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    return String(clean.prefix(limit))
}
```

Normalize reminders:

```swift
result.reminders = reminders.map { reminder in
    var value = reminder
    value.name = Self.cleanedText(reminder.name, limit: 120)
    value.message = Self.cleanedText(reminder.message, limit: 120)
    value.intervalMinutes = Self.clamp(reminder.intervalMinutes, to: Self.reminderMinutesRange)
    return value
}
```

Validate normalized content without recursively calling `normalized` from itself:

```swift
var reminderValidationMessage: String? {
    let reminders = normalized.reminders
    if reminders.contains(where: { $0.name.isEmpty }) { return "Reminder name is required." }
    if reminders.contains(where: { $0.message.isEmpty }) { return "Reminder message is required." }
    return nil
}
```

`normalized` itself must not call `reminderValidationMessage`.

- [ ] **Step 6: Implement one-way legacy decoding**

Use current keys for current properties and a separate legacy key enum:

```swift
private enum LegacyReminderKeys: String, CodingKey {
    case blinkEnabled, blinkMinutes, blinkMessage
    case postureEnabled, postureMinutes, postureMessage
}
```

In `init(from:)`, decode `reminders` when the current container contains that key, including an empty array. Otherwise decode the legacy container and construct:

```swift
let blink = Reminder(
    id: .blinkID,
    name: "Blink",
    message: try legacy.decodeIfPresent(String.self, forKey: .blinkMessage) ?? Reminder.defaultBlink.message,
    intervalMinutes: try legacy.decodeIfPresent(Int.self, forKey: .blinkMinutes) ?? Reminder.defaultBlink.intervalMinutes,
    enabled: try legacy.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? Reminder.defaultBlink.enabled
)
let posture = Reminder(
    id: .postureID,
    name: "Posture",
    message: try legacy.decodeIfPresent(String.self, forKey: .postureMessage) ?? Reminder.defaultPosture.message,
    intervalMinutes: try legacy.decodeIfPresent(Int.self, forKey: .postureMinutes) ?? Reminder.defaultPosture.intervalMinutes,
    enabled: try legacy.decodeIfPresent(Bool.self, forKey: .postureEnabled) ?? Reminder.defaultPosture.enabled
)
reminders = [blink, posture]
```

Do not include legacy keys in current encoding keys.

- [ ] **Step 7: Reject invalid reminder drafts at persistence time**

Add:

```swift
enum SettingsValidationError: Error, Equatable {
    case invalidReminder(String)
}
```

Then guard `SettingsStore.save`:

```swift
let next = candidate.normalized
if let message = next.reminderValidationMessage {
    throw SettingsValidationError.invalidReminder(message)
}
```

Persist only after the guard.

- [ ] **Step 8: Convert existing settings tests to the generic collection**

Replace old field mutations with index/ID based reminder mutations, for example:

```swift
var settings = AppSettings.defaults
settings.reminders[0].intervalMinutes = 8
settings.reminders[0].enabled = false
```

Preserve existing tests for bounds, presets, unrelated settings, round trips, and defaults.

- [ ] **Step 9: Run settings/model tests and verify green**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderSettingsTests -only-testing:LookAwayTests/SettingsTests -only-testing:LookAwayTests/ExtendedSettingsTests
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add LookAway/AppSettings.swift LookAwayTests/ReminderSettingsTests.swift LookAwayTests/SettingsTests.swift LookAwayTests/ExtendedSettingsTests.swift
git commit -m "refactor: model reminders as generic settings"
```

---

### Task 2: Generic ID-based reminder scheduler

**Files:**
- Modify: `LookAway/BreakSchedule.swift`
- Modify: `LookAway/AppSettings.swift`
- Modify: `LookAwayTests/LookAwayTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`
- Create: `LookAwayTests/ReminderScheduleTests.swift`

**Interfaces:**
- Produces: `ReminderScheduleConfiguration { id: UUID, intervalSeconds: Int }`
- Produces: `BreakConfiguration.reminders: [ReminderScheduleConfiguration]`
- Produces: `BreakSchedule.Event.reminder(UUID)`
- Keeps: `BreakSchedule.updateConfiguration(_:at:)`

- [ ] **Step 1: Write failing arbitrary/simultaneous reminder tests**

Create `ReminderScheduleTests.swift`:

```swift
import XCTest
@testable import LookAway

final class ReminderScheduleTests: XCTestCase {
    let a = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    let b = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!

    func config(_ reminders: [ReminderScheduleConfiguration]) -> BreakConfiguration {
        BreakConfiguration(workSeconds: 1800, breakSeconds: 30, warningSeconds: 60, reminders: reminders)
    }

    func testArbitraryReminderIntervalsEmitIdEvents() {
        var schedule = BreakSchedule(configuration: config([
            .init(id: a, intervalSeconds: 120),
            .init(id: b, intervalSeconds: 180)
        ]), now: 0)
        XCTAssertEqual(schedule.advance(at: 119), [])
        XCTAssertEqual(schedule.advance(at: 120), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 180), [.reminder(b)])
    }

    func testSimultaneousRemindersAreReturnedTogether() {
        var schedule = BreakSchedule(configuration: config([
            .init(id: a, intervalSeconds: 300),
            .init(id: b, intervalSeconds: 300)
        ]), now: 0)
        XCTAssertEqual(schedule.advance(at: 300), [.reminder(a), .reminder(b)])
    }
}
```

- [ ] **Step 2: Add concrete reconciliation tests**

Add these full tests:

```swift
func testReorderingDoesNotResetDeadlines() {
    var schedule = BreakSchedule(configuration: config([
        .init(id: a, intervalSeconds: 300),
        .init(id: b, intervalSeconds: 600)
    ]), now: 0)
    _ = schedule.advance(at: 100)
    schedule.updateConfiguration(config([
        .init(id: b, intervalSeconds: 600),
        .init(id: a, intervalSeconds: 300)
    ]), at: 100)
    XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
    XCTAssertEqual(schedule.advance(at: 299), [])
    XCTAssertEqual(schedule.advance(at: 300), [.reminder(a)])
}

func testAddingReminderStartsOnlyNewReminderFromNow() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 300)]), now: 0)
    schedule.updateConfiguration(config([
        .init(id: a, intervalSeconds: 300),
        .init(id: b, intervalSeconds: 200)
    ]), at: 100)
    XCTAssertEqual(schedule.advance(at: 299), [])
    XCTAssertEqual(schedule.advance(at: 300), [.reminder(a), .reminder(b)])
}

func testChangingOneIntervalRestartsOnlyThatReminder() {
    var schedule = BreakSchedule(configuration: config([
        .init(id: a, intervalSeconds: 300),
        .init(id: b, intervalSeconds: 500)
    ]), now: 0)
    schedule.updateConfiguration(config([
        .init(id: a, intervalSeconds: 600),
        .init(id: b, intervalSeconds: 500)
    ]), at: 100)
    XCTAssertEqual(schedule.advance(at: 499), [])
    XCTAssertEqual(schedule.advance(at: 500), [.reminder(b)])
    XCTAssertEqual(schedule.advance(at: 699), [])
    XCTAssertEqual(schedule.advance(at: 700), [.reminder(a)])
}

func testRemovingReminderDropsItsDeadline() {
    var schedule = BreakSchedule(configuration: config([
        .init(id: a, intervalSeconds: 100),
        .init(id: b, intervalSeconds: 200)
    ]), now: 0)
    schedule.updateConfiguration(config([.init(id: b, intervalSeconds: 200)]), at: 50)
    XCTAssertEqual(schedule.advance(at: 100), [])
    XCTAssertEqual(schedule.advance(at: 200), [.reminder(b)])
}

func testReminderOnlyUpdatePreservesWorkAndPendingSkip() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 300)]), now: 0)
    schedule.skipUpcomingBreak()
    schedule.updateConfiguration(config([.init(id: a, intervalSeconds: 600)]), at: 100)
    XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
    XCTAssertTrue(schedule.skipsUpcomingBreak)
}

func testPauseResumePreservesReminderRemainingTime() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 300)]), now: 0)
    schedule.pause(at: 100)
    schedule.resume(at: 1000)
    XCTAssertEqual(schedule.advance(at: 1199), [])
    XCTAssertEqual(schedule.advance(at: 1200), [.reminder(a)])
}

func testSleepWakePreservesReminderRemainingTimeWithoutBacklog() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 300)]), now: 0)
    schedule.prepareForSleep(at: 100)
    XCTAssertEqual(schedule.advance(at: 9000), [])
    schedule.wake(at: 10000)
    XCTAssertEqual(schedule.advance(at: 10199), [])
    XCTAssertEqual(schedule.advance(at: 10200), [.reminder(a)])
}

func testFinishingBreakStartsFreshReminderCycle() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 300)]), now: 0)
    XCTAssertTrue(schedule.startBreakNow())
    schedule.finishBreak(at: 30)
    XCTAssertEqual(schedule.advance(at: 329), [])
    XCTAssertEqual(schedule.advance(at: 330), [.reminder(a)])
}

func testLateAdvanceDoesNotReplayBacklog() {
    var schedule = BreakSchedule(configuration: config([.init(id: a, intervalSeconds: 100)]), now: 0)
    XCTAssertEqual(schedule.advance(at: 450), [.reminder(a)])
    XCTAssertEqual(schedule.advance(at: 451), [])
    XCTAssertEqual(schedule.advance(at: 550), [.reminder(a)])
}
```

- [ ] **Step 3: Run focused scheduler tests and verify red**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderScheduleTests
```

Expected: compile failures for generic scheduler types/events.

- [ ] **Step 4: Replace hardcoded scheduler configuration**

Implement:

```swift
struct ReminderScheduleConfiguration: Equatable {
    let id: UUID
    let intervalSeconds: Int
}

struct BreakConfiguration: Equatable {
    var workSeconds = 30 * 60
    var breakSeconds = 30
    var warningSeconds = 60
    var reminders: [ReminderScheduleConfiguration] = [
        .init(id: Reminder.blinkID, intervalSeconds: 5 * 60),
        .init(id: Reminder.postureID, intervalSeconds: 10 * 60)
    ]

    var isValid: Bool {
        workSeconds > 0 && breakSeconds > 0 && warningSeconds >= 0
            && reminders.allSatisfy { $0.intervalSeconds > 0 }
    }
}
```

Update `AppSettings.breakConfiguration`:

```swift
return BreakConfiguration(
    workSeconds: value.workMinutes * 60,
    breakSeconds: value.breakSeconds,
    warningSeconds: value.warningEnabled ? value.warningSeconds : 0,
    reminders: value.reminders.filter(\.enabled).map {
        ReminderScheduleConfiguration(id: $0.id, intervalSeconds: $0.intervalMinutes * 60)
    }
)
```

- [ ] **Step 5: Replace fixed deadlines/events with ID-based state**

Use:

```swift
private var reminderDeadlines: [UUID: TimeInterval]
private var pausedReminderRemaining: [UUID: TimeInterval] = [:]

enum Event: Equatable {
    case warning, startBreak, skippedBreak
    case reminder(UUID)
}
```

Initialize `reminderDeadlines` from the enabled configurations. In `advance(at:)`, iterate `configuration.reminders` in collection order, emit `.reminder(id)` when due, and rearm at `now + intervalSeconds`.

- [ ] **Step 6: Implement ID-based configuration reconciliation**

Build lookup dictionaries:

```swift
let oldByID = Dictionary(uniqueKeysWithValues: configuration.reminders.map { ($0.id, $0.intervalSeconds) })
let newByID = Dictionary(uniqueKeysWithValues: next.reminders.map { ($0.id, $0.intervalSeconds) })
```

For removed IDs, remove deadline/paused state. For new IDs, start at full interval from `now` or store full paused remaining. For IDs whose interval changed, restart only that ID. For unchanged IDs, preserve deadline/remaining even when array order changes.

Handle work timing separately:

```swift
let workTimingChanged = next.workSeconds != configuration.workSeconds || next.breakSeconds != configuration.breakSeconds
```

Only `workTimingChanged` starts a fresh work session/paused work interval and clears a pending skip. A warning-only or reminder-only change must not reset work remaining.

- [ ] **Step 7: Update pause/resume/sleep/startWork paths**

Pause:

```swift
pausedReminderRemaining = Dictionary(uniqueKeysWithValues: configuration.reminders.map { reminder in
    (reminder.id, max(0, (reminderDeadlines[reminder.id] ?? now) - now))
})
```

Resume recreates each deadline from stored remaining time. `startWork(at:)` recreates every enabled reminder deadline from its full interval. Sleep continues to use pause/resume semantics, so no reminder backlog accumulates.

- [ ] **Step 8: Migrate old scheduler expectations**

Replace `.blinkReminder`/`.postureReminder` in `LookAwayTests.swift` and `SettingsTests.swift` with `.reminder(Reminder.blinkID)` / `.reminder(Reminder.postureID)` where the default objects are intentionally being tested. Remove obsolete tests that exist only to prove two hardcoded reminder booleans are independent.

- [ ] **Step 9: Run scheduler tests and verify green**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderScheduleTests -only-testing:LookAwayTests/LookAwayTests -only-testing:LookAwayTests/SchedulerSettingsTests
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add LookAway/AppSettings.swift LookAway/BreakSchedule.swift LookAwayTests/ReminderScheduleTests.swift LookAwayTests/LookAwayTests.swift LookAwayTests/SettingsTests.swift
git commit -m "refactor: schedule reminders by id"
```

---

### Task 3: Generic reminder presentation and sound routing

**Files:**
- Modify: `LookAway/PresentationSupport.swift`
- Modify: `LookAway/AppDelegate.swift`
- Modify: `LookAwayTests/SoundRoutingTests.swift`
- Create: `LookAwayTests/ReminderPresentationTests.swift`

**Interfaces:**
- Produces: `ReminderPresentationResolver.message(for:settings:) -> String?`
- Keeps: `SoundEvent.selected(for:settings:) -> SoundEvent?`

- [ ] **Step 1: Write failing resolver tests**

```swift
import XCTest
@testable import LookAway

final class ReminderPresentationTests: XCTestCase {
    func testDueReminderIdsResolveInSettingsOrder() {
        let first = Reminder(id: UUID(), name: "First", message: "One", intervalMinutes: 5, enabled: true)
        let second = Reminder(id: UUID(), name: "Second", message: "Two", intervalMinutes: 5, enabled: true)
        var settings = AppSettings.defaults
        settings.reminders = [second, first]
        let events: [BreakSchedule.Event] = [.reminder(first.id), .reminder(second.id)]
        XCTAssertEqual(ReminderPresentationResolver.message(for: events, settings: settings), "Two\nOne")
    }

    func testDeletedAndDisabledReminderIdsAreIgnored() {
        let active = Reminder(id: UUID(), name: "A", message: "Active", intervalMinutes: 5, enabled: true)
        let disabled = Reminder(id: UUID(), name: "B", message: "Disabled", intervalMinutes: 5, enabled: false)
        var settings = AppSettings.defaults
        settings.reminders = [active, disabled]
        XCTAssertEqual(
            ReminderPresentationResolver.message(for: [.reminder(disabled.id), .reminder(active.id), .reminder(UUID())], settings: settings),
            "Active"
        )
    }
}
```

- [ ] **Step 2: Update sound tests to generic events and verify red**

Use a fixed UUID:

```swift
let reminderID = UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!
XCTAssertEqual(SoundEvent.selected(for: [.warning, .reminder(reminderID)], settings: settings), .reminder)
```

Run:

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderPresentationTests -only-testing:LookAwayTests/SoundRoutingTests
```

Expected: resolver missing and old sound event checks failing.

- [ ] **Step 3: Implement resolver and generic sound detection**

```swift
enum ReminderPresentationResolver {
    static func message(for events: [BreakSchedule.Event], settings: AppSettings) -> String? {
        let due = Set(events.compactMap { event -> UUID? in
            if case .reminder(let id) = event { return id }
            return nil
        })
        let messages = settings.reminders
            .filter { $0.enabled && due.contains($0.id) }
            .map(\.message)
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}
```

Update `SoundEvent.selected`:

```swift
let hasReminder = events.contains { event in
    if case .reminder = event { return true }
    return false
}
if events.contains(.warning), settings.soundOnWarning { return .warning }
if hasReminder, settings.soundOnReminder { return .reminder }
return nil
```

- [ ] **Step 4: Route generic events in `AppDelegate.tick()`**

```swift
let settings = settingsStore.value
if let message = ReminderPresentationResolver.message(for: events, settings: settings) {
    overlayController.show(
        mode: .reminder(message: message, duration: settings.reminderSeconds),
        settings: settings
    )
}
if let event = SoundEvent.selected(for: events, settings: settings) {
    soundPlayer.play(event: event, settings: settings)
}
```

In `applySettings`, always call:

```swift
schedule.updateConfiguration(settingsStore.value.breakConfiguration, at: now)
```

The scheduler now decides which timing state changes; `AppDelegate` must not reset based on whole-configuration inequality.

- [ ] **Step 5: Run focused presentation/sound tests and verify green**

Run the Step 2 command again. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LookAway/PresentationSupport.swift LookAway/AppDelegate.swift LookAwayTests/SoundRoutingTests.swift LookAwayTests/ReminderPresentationTests.swift
git commit -m "refactor: present generic reminders"
```

---

### Task 4: Settings editor operations and validation

**Files:**
- Modify: `LookAway/SettingsEditor.swift`
- Modify: `LookAwayTests/SettingsTests.swift`

**Interfaces:**
- Produces: `validationMessage`, `canSave`, `addReminder(_:)`, `removeReminder(id:)`, `moveReminder(id:before:)`, `moveReminderToEnd(id:)`

- [ ] **Step 1: Write failing editor tests**

```swift
func testEditorBlocksSaveForInvalidReminder() {
    var applied = 0
    let editor = SettingsEditor(settings: .defaults) { _ in applied += 1 }
    editor.draft.reminders[0].message = "   "
    XCTAssertEqual(editor.validationMessage, "Reminder message is required.")
    XCTAssertFalse(editor.canSave)
    XCTAssertFalse(editor.apply())
    XCTAssertEqual(applied, 0)
}

func testEditorAddsDeletesAndReordersDraftOnly() {
    let editor = SettingsEditor(settings: .defaults) { _ in }
    let custom = Reminder(name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
    editor.addReminder(custom)
    editor.moveReminder(id: custom.id, before: Reminder.blinkID)
    XCTAssertEqual(editor.draft.reminders.first?.id, custom.id)
    editor.moveReminderToEnd(id: custom.id)
    XCTAssertEqual(editor.draft.reminders.last?.id, custom.id)
    editor.removeReminder(id: custom.id)
    XCTAssertFalse(editor.draft.reminders.contains { $0.id == custom.id })
    XCTAssertEqual(editor.saved, .defaults)
}
```

- [ ] **Step 2: Run `SettingsTests` and verify red**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/SettingsTests
```

Expected: missing editor APIs.

- [ ] **Step 3: Implement editor validation and collection operations**

```swift
var validationMessage: String? { draft.normalized.reminderValidationMessage }
var canSave: Bool { hasChanges && validationMessage == nil }

func addReminder(_ reminder: Reminder) {
    draft.reminders.append(reminder)
    errorMessage = nil
}

func removeReminder(id: UUID) {
    draft.reminders.removeAll { $0.id == id }
    errorMessage = nil
}

func moveReminder(id: UUID, before targetID: UUID) {
    guard id != targetID,
          let source = draft.reminders.firstIndex(where: { $0.id == id }),
          let target = draft.reminders.firstIndex(where: { $0.id == targetID }) else { return }
    let reminder = draft.reminders.remove(at: source)
    let insertion = source < target ? target - 1 : target
    draft.reminders.insert(reminder, at: insertion)
}

func moveReminderToEnd(id: UUID) {
    guard let source = draft.reminders.firstIndex(where: { $0.id == id }) else { return }
    draft.reminders.append(draft.reminders.remove(at: source))
}
```

At the start of `apply()`:

```swift
if let validationMessage {
    errorMessage = validationMessage
    return false
}
```

- [ ] **Step 4: Run `SettingsTests` and verify green**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LookAway/SettingsEditor.swift LookAwayTests/SettingsTests.swift
git commit -m "feat: edit reminder collections in settings draft"
```

---

### Task 5: Compact shared Settings layout and five-tab structure

**Files:**
- Create: `LookAway/SettingsComponents.swift`
- Modify: `LookAway/SettingsView.swift`
- Modify: `LookAway/SettingsWindowController.swift`
- Modify: `LookAwayTests/SettingsLayoutTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`

**Interfaces:**
- Produces: `SettingsLayout`, `SettingsRow`, `SettingsNumericRow`, `SettingsTextRow`, `SettingsPickerRow`, `SettingsDateRow`
- Keeps: `SettingsView(editor:login:soundPlayer:onPreview:onClose:)`

- [ ] **Step 1: Write failing layout/tab/window tests**

Update `SettingsLayoutTests.swift` to load `SettingsView.swift` and `SettingsComponents.swift` and assert:

```swift
XCTAssertFalse(settingsSource.contains("schedule.tabItem"))
XCTAssertFalse(settingsSource.contains("private var schedule"))
XCTAssertTrue(settingsSource.contains("settingsSection(\"Working hours\")"))
XCTAssertTrue(settingsSource.contains("settingsSection(\"Reminder presentation\")"))
XCTAssertTrue(componentsSource.contains("struct SettingsRow"))
XCTAssertTrue(componentsSource.contains("static let labelWidth"))
XCTAssertFalse(settingsSource.contains("private let labelWidth"))
XCTAssertFalse(settingsSource.contains("Form {"))
XCTAssertFalse(settingsSource.contains("LabeledContent("))
XCTAssertFalse(settingsSource.contains("note(\""))
```

Add to `SettingsTests.swift`:

```swift
func testSettingsWindowUsesCompactGeometry() throws {
    let controller = SettingsWindowController(settings: { .defaults }, onApply: { _ in })
    let window = try XCTUnwrap(controller.window)
    XCTAssertLessThanOrEqual(window.frame.width, 720)
    XCTAssertLessThanOrEqual(window.frame.height, 540)
    XCTAssertLessThanOrEqual(window.contentMinSize.height, 500)
}
```

- [ ] **Step 2: Run layout/window tests and verify red**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/SettingsLayoutTests -only-testing:LookAwayTests/SettingsTests/testSettingsWindowUsesCompactGeometry
```

Expected: failures for Schedule, missing shared rows, and oversized window.

- [ ] **Step 3: Implement shared compact row primitives**

In `SettingsComponents.swift`:

```swift
import SwiftUI

enum SettingsLayout {
    static let pageWidth: CGFloat = 560
    static let labelWidth: CGFloat = 180
    static let columnGap: CGFloat = 12
    static let pickerWidth: CGFloat = 220
    static let textWidth: CGFloat = 300
    static let numberWidth: CGFloat = 64
    static let dateWidth: CGFloat = 180
    static let pagePadding: CGFloat = 18
    static let sectionGap: CGFloat = 14
    static let rowGap: CGFloat = 8
}

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayout.columnGap) {
            Text(label).lineLimit(1).frame(width: SettingsLayout.labelWidth, alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }
}
```

Implement the four convenience rows by wrapping `SettingsRow`. `SettingsNumericRow` clamps through a `Binding<Int>`, uses a 64-point field, a fixed unit label, and a labels-hidden Stepper. `SettingsTextRow` uses a 300-point rounded field. `SettingsPickerRow` uses a 220-point picker. `SettingsDateRow` uses a 180-point DatePicker. Every control begins immediately after the same 180-point label column.

- [ ] **Step 4: Reorganize `SettingsView`**

Use exactly five tabs:

```swift
general.tabItem { Label("General", systemImage: "gearshape") }
breaks.tabItem { Label("Breaks", systemImage: "cup.and.saucer") }
reminders.tabItem { Label("Reminders", systemImage: "bell") }
appearance.tabItem { Label("Appearance", systemImage: "paintbrush") }
sounds.tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
```

General section order becomes Startup, Menu bar, Working hours. Delete the Schedule property.

Appearance section order becomes App appearance, Reminder presentation, Break screen, Preview. `Reminder presentation` contains style, displays, duration, and banner position. Change `With blink or posture reminders` to `With reminders` in Sounds.

Convert pickers, numeric rows, text fields, and dates to the shared row primitives. Toggles remain native where there is no separate value control.

- [ ] **Step 5: Reduce Settings page/window geometry**

Set section/page spacing from `SettingsLayout`. In `SettingsWindowController` use:

```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.contentMinSize = NSSize(width: 660, height: 480)
```

Set `SettingsView` minimum frame to the same compact lower bound rather than forcing 700x580 content.

- [ ] **Step 6: Run layout/window tests and verify green**

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add LookAway/SettingsComponents.swift LookAway/SettingsView.swift LookAway/SettingsWindowController.swift LookAwayTests/SettingsLayoutTests.swift LookAwayTests/SettingsTests.swift
git commit -m "refactor: compact and reorganize settings"
```

---

### Task 6: Reminder cards, drag reordering, and Add Reminder modal

**Files:**
- Create: `LookAway/ReminderSettingsView.swift`
- Modify: `LookAway/SettingsView.swift`
- Modify: `LookAwayTests/SettingsLayoutTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`

**Interfaces:**
- Produces: `NewReminderDraft`, `ReminderSettingsView`, `ReminderCard`, `AddReminderSheet`
- Consumes: `SettingsEditor` reminder operations from Task 4

- [ ] **Step 1: Write failing reminder UI structure tests**

Extend `SettingsLayoutTests.swift`:

```swift
XCTAssertTrue(reminderSource.contains("ForEach($editor.draft.reminders)"))
XCTAssertTrue(reminderSource.contains("Add Reminder"))
XCTAssertTrue(reminderSource.contains(".sheet"))
XCTAssertTrue(reminderSource.contains("draggable"))
XCTAssertTrue(reminderSource.contains("dropDestination"))
XCTAssertFalse(reminderSource.contains("settingsSection(\"Blink\")"))
XCTAssertFalse(reminderSource.contains("settingsSection(\"Posture\")"))
XCTAssertFalse(reminderSource.contains("settingsSection(\"Presentation\")"))
```

Add logic tests:

```swift
func testNewReminderDraftDefaultsAndValidation() {
    var draft = NewReminderDraft()
    XCTAssertEqual(draft.intervalMinutes, 5)
    XCTAssertTrue(draft.enabled)
    XCTAssertFalse(draft.canAdd)
    draft.name = "Water"
    XCTAssertFalse(draft.canAdd)
    draft.message = "Drink"
    XCTAssertTrue(draft.canAdd)
    let reminder = draft.reminder()
    XCTAssertEqual(reminder.name, "Water")
    XCTAssertEqual(reminder.message, "Drink")
    XCTAssertEqual(reminder.intervalMinutes, 5)
}
```

- [ ] **Step 2: Run reminder UI/logic tests and verify red**

Run `SettingsLayoutTests` and `SettingsTests`. Expected: missing reminder views/draft.

- [ ] **Step 3: Implement the creation draft**

```swift
struct NewReminderDraft: Equatable {
    var name = ""
    var message = ""
    var intervalMinutes = 5
    var enabled = true

    var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reminder() -> Reminder {
        Reminder(name: name, message: message, intervalMinutes: intervalMinutes, enabled: enabled)
    }
}
```

- [ ] **Step 4: Implement the Reminders page and card stack**

Header:

```swift
HStack {
    Text("Reminders").font(.headline)
    Spacer()
    Button("Add Reminder", systemImage: "plus") { isAddingReminder = true }
}
```

Object-driven cards:

```swift
ForEach($editor.draft.reminders) { $reminder in
    ReminderCard(
        reminder: $reminder,
        onDelete: { editor.removeReminder(id: reminder.id) },
        onMoveBefore: { draggedID in editor.moveReminder(id: draggedID, before: reminder.id) }
    )
}
```

Add an end drop target that parses a dragged UUID string and calls `editor.moveReminderToEnd(id:)`.

- [ ] **Step 5: Implement compact editable cards**

The card header contains the drag handle, enabled toggle, inline name field, spacer, and trash button. Only the handle gets:

```swift
.draggable(reminder.id.uuidString)
```

Each card receives:

```swift
.dropDestination(for: String.self) { items, _ in
    guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
    onMoveBefore(id)
    return true
}
```

The body uses shared `SettingsTextRow("Message", ...)` and `SettingsNumericRow("Remind every", ..., unit: "min")`. If trimmed name/message is empty, show one compact red validation line inside the card.

- [ ] **Step 6: Implement `AddReminderSheet`**

Use local `@State private var draft = NewReminderDraft()`. Render Name, Message, Remind every, and Enabled. The footer is:

```swift
HStack {
    Spacer()
    Button("Cancel") { onCancel() }.keyboardShortcut(.cancelAction)
    Button("Add") { onAdd(draft.reminder()) }
        .keyboardShortcut(.defaultAction)
        .disabled(!draft.canAdd)
}
```

In `ReminderSettingsView`:

```swift
.sheet(isPresented: $isAddingReminder) {
    AddReminderSheet(
        onCancel: { isAddingReminder = false },
        onAdd: { reminder in
            editor.addReminder(reminder)
            isAddingReminder = false
        }
    )
}
```

- [ ] **Step 7: Wire the Reminders tab and Save state**

```swift
private var reminders: some View {
    ReminderSettingsView(editor: editor)
}
```

Change the Save button to:

```swift
.disabled(!editor.canSave)
```

Keep existing save errors, login warnings, no-days warning, card validation, and sound-preview failure as the only extra explanatory text.

- [ ] **Step 8: Run reminder/settings tests and verify green**

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/SettingsLayoutTests -only-testing:LookAwayTests/SettingsTests
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add LookAway/ReminderSettingsView.swift LookAway/SettingsView.swift LookAwayTests/SettingsLayoutTests.swift LookAwayTests/SettingsTests.swift
git commit -m "feat: add editable reminder cards"
```

---

### Task 7: Rewrite README and update product/developer/testing docs

**Files:**
- Rewrite: `readme.md`
- Modify: `docs/development.md`
- Modify: `docs/testing.md`

**Interfaces:**
- Documents five Settings tabs and generic reminders
- Documents actual updater behavior
- Removes stale hardcoded Blink/Posture and six-tab language

- [ ] **Step 1: Rewrite `readme.md` with complete user-facing copy**

Use this structure and substance, adjusting only wording for polish while preserving facts:

```markdown
# LookAway

LookAway is a native macOS menu-bar app for screen breaks and lightweight recurring reminders. It runs locally, needs no account, and stays out of the way until it is time to look somewhere other than a glowing rectangle for a moment.

By default, LookAway starts with a 30-second break every 30 minutes plus two editable reminders: Blink every 5 minutes and Posture every 10 minutes. Those reminders are ordinary objects: rename them, change them, reorder them, disable them, delete them, or create more.

## Features

- Scheduled screen breaks with advance warnings, skip, and postpone controls
- Any number of recurring reminders
- Full-screen or compact reminder presentation
- Working days and hours
- All, primary, or pointer-display targeting
- Optional sounds, countdowns, dimming, text sizing, and break quotes
- Break-screen preview on the real display
- Automatic update checks with one-click installation from the menu bar

## Install

Requires **macOS 15.4+**. No Xcode is required.

```sh
curl -fsSL https://raw.githubusercontent.com/longnt27/lookaway/main/install.sh | sh
```

The installer downloads the latest universal Apple Silicon/Intel release, verifies its SHA-256 checksum, installs it to `~/Applications`, and opens LookAway.

> LookAway is intentionally distributed without Apple notarization. macOS may show a security warning depending on your system settings.

## Everyday use

Click the menu-bar icon to start a break immediately, pause or resume the timer, open Settings, install an available update, or quit.

Before a scheduled break, the warning can be dismissed, skipped, or postponed. During a break, **I'm ready** can finish the break early when early finishing is enabled. Work and reminder timers pause during sleep and outside configured working hours.

## Reminders

Open **Settings > Reminders** to manage reminder cards. Use **Add Reminder** to create one with a name, message, interval, and enabled state. Existing cards can be edited inline, reordered with their drag handle, disabled, or deleted. Blink and Posture are merely the two defaults created for a fresh install.

When several reminders are due together, LookAway combines them into one presentation instead of stacking multiple interruptions.

## Settings

LookAway has five settings tabs:

- **General**: startup, menu-bar countdown, and working hours
- **Breaks**: work/break timing, warnings, skip/postpone, and early finish
- **Reminders**: reminder cards and Add Reminder
- **Appearance**: app appearance, reminder presentation, break screen, and preview
- **Sounds**: warning, break, and reminder sounds plus volume

Changes stay in a draft until **Save**. **Cancel** or closing the window discards draft changes. Launch at login is managed directly by macOS and applies immediately.

## Updates

LookAway checks GitHub Releases periodically and after waking. The menu shows **App is up to date** when nothing is available or **Update to version x.x.x** when a newer release is found. LookAway installs only after you choose the update item. After a successful relaunch, a popover from the menu-bar icon confirms the installed version.

## Privacy and scope

LookAway requires no account and stores preferences locally. It does not need camera, microphone, Accessibility, or Screen Recording permission. Network access is used for update checks and release downloads from GitHub.

LookAway is a reminder app, not a device lock or medical device.

## Support and development

- [Report an issue](https://github.com/longnt27/lookaway/issues)
- [Developer guide](docs/development.md)
- [Testing guide](docs/testing.md)

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.
```

- [ ] **Step 2: Update `docs/development.md`**

Change the settings section to five tabs, describe `AppSettings.reminders`, document generic 1–120 minute reminder intervals, note invalid blank custom reminder fields, explain ID-based scheduler reconciliation, and add `SettingsComponents.swift` / `ReminderSettingsView.swift` to the code map. Replace the stale statement that there is no automatic updater with the actual GitHub-release update-check/install behavior.

- [ ] **Step 3: Update `docs/testing.md`**

Replace `All six tabs` with five tabs. Replace Blink/Posture-special-case checklist items with checks for Add Reminder modal validation, seeded/custom card edits, delete/reorder, empty reminder collections, simultaneous arbitrary reminders, and reminder-only edits preserving work time. Add checks for aligned control columns, Working Hours under General, Reminder Presentation under Appearance, updater menu state, and post-update popover.

- [ ] **Step 4: Search for stale product/runtime language**

```bash
grep -RInE 'six Settings tabs|Blink / posture interval|\.blinkReminder|\.postureReminder|With blink or posture reminders|check for updates' readme.md docs LookAway LookAwayTests || true
```

Expected: no stale user-facing/docs wording and no old runtime event cases. Legacy migration key names may remain only in migration code and migration tests.

- [ ] **Step 5: Commit**

```bash
git add readme.md docs/development.md docs/testing.md
git commit -m "docs: rewrite readme for custom reminders"
```

---

### Task 8: Full verification and release-quality review

**Files:**
- Modify only files already in scope if verification exposes a defect.

**Interfaces:**
- Verifies the full implementation against the spec and README requirement.

- [ ] **Step 1: Run the full test suite from a clean result bundle**

```bash
rm -rf build/DerivedData build/TestResults.xcresult
mkdir -p build
xcodebuild test \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Debug \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  2>&1 | tee build/test.log
```

Expected: exit 0, zero failing tests.

- [ ] **Step 2: Build and verify the universal Release app**

```bash
xcodebuild build \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CLANG_ENABLE_CODE_COVERAGE=NO GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  2>&1 | tee build/release.log

xcrun lipo build/DerivedData/Build/Products/Release/LookAway.app/Contents/MacOS/LookAway -verify_arch arm64 x86_64
```

Expected: build succeeds and both architectures verify.

- [ ] **Step 3: Sweep for removed hardcoded runtime concepts**

```bash
grep -RInE '\bblinkEnabled\b|\bblinkMinutes\b|\bblinkMessage\b|\bpostureEnabled\b|\bpostureMinutes\b|\bpostureMessage\b|\.blinkReminder|\.postureReminder' LookAway LookAwayTests || true
```

Expected: old field names occur only inside explicit legacy migration keys/fixtures; old event cases do not occur.

```bash
grep -RIn 'Schedule"' LookAway/SettingsView.swift LookAway/ReminderSettingsView.swift || true
grep -RIn 'Presentation"' LookAway/ReminderSettingsView.swift || true
```

Expected: no Schedule tab and no Reminder Presentation section inside the Reminders view.

- [ ] **Step 4: Review every acceptance criterion**

Read `docs/superpowers/specs/2026-09-14-reminder-settings-redesign-design.md` line by line and verify each acceptance criterion against code/tests. Also verify `readme.md` has been rewritten and no longer claims updates install without user action.

- [ ] **Step 5: Commit verification fixes only when needed**

If Steps 1–4 expose defects, fix them, rerun the failing verification, then commit the verified fixes with a focused message. Do not create an empty commit when no fix is needed.

- [ ] **Step 6: Push the implementation branch and open a PR**

Create the implementation branch from `main`, not from the design-only branch. The PR description must list generic reminder migration, scheduler reconciliation, five-tab Settings reorganization, cards/Add modal, compact alignment/window changes, README/developer/testing rewrites, and the exact passing test/build commands.

Do not merge until PR checks pass and the user approves integration.
