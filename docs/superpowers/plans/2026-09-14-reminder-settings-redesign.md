# Reminder and Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded Blink/Posture reminders with user-managed reminder objects and rebuild Settings into a compact five-tab UI with consistent alignment, cards, an Add Reminder modal, migrated persistence, and updated documentation.

**Architecture:** `AppSettings` owns a generic `[Reminder]` collection and migrates legacy Blink/Posture fields in place. `BreakSchedule` schedules reminders by stable UUID and reconciles reminder-only configuration changes without restarting the work timer. Settings is split into shared row primitives plus reminder-specific views so General/Breaks/Appearance stay compact while the Reminders tab renders cards and a creation sheet.

**Tech Stack:** Swift 5, SwiftUI, AppKit, XCTest, UserDefaults JSON persistence, Xcode 16.4, macOS 15.4+, no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-14-reminder-settings-redesign-design.md`

## Global Constraints

- Keep `UserDefaults["LookAway.settings.v1"]`; migration must happen in place.
- Fresh installs seed exactly two ordinary reminders: Blink at 5 minutes and Posture at 10 minutes, both enabled.
- Blink/Posture receive no privileged behavior after seeding and may be renamed, reordered, disabled, or deleted.
- The reminder array may be empty.
- Reminder names/messages are required for saving, whitespace-normalized, and capped at the existing 120-character message limit.
- Reminder-only edits must not restart the main work timer.
- Simultaneous reminders render as one presentation in reminder-list order.
- Reminder presentation remains global, not per reminder.
- Remove the Schedule tab; move Working Hours into General.
- Move Reminder Presentation into Appearance.
- Use one compact label/control alignment system across Settings; ordinary helper prose remains absent.
- Target roughly a 700x500 default Settings window where default General and Breaks content fits without vertical scrolling.
- Keep updater behavior, launch-at-login behavior, break semantics, active-hours semantics, and global sound semantics unchanged unless explicitly required below.
- Rewrite `readme.md` to describe the resulting product accurately, including custom reminders and the current updater flow.

---

### Task 1: Generic reminder model, validation, persistence, and legacy migration

**Files:**
- Modify: `LookAway/AppSettings.swift`
- Create: `LookAwayTests/ReminderSettingsTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`
- Modify: `LookAwayTests/ExtendedSettingsTests.swift`

**Interfaces:**
- Produces: `Reminder: Codable, Equatable, Identifiable`
- Produces: `Reminder.defaultBlink`, `Reminder.defaultPosture`, and stable IDs for both seeded reminders
- Produces: `AppSettings.reminders: [Reminder]`
- Produces: `AppSettings.reminderValidationMessage: String?`
- Produces: `AppSettings.breakConfiguration` using enabled generic reminders
- Keeps: `SettingsStore.storageKey == "LookAway.settings.v1"`

- [ ] **Step 1: Write failing model/default tests**

Create `LookAwayTests/ReminderSettingsTests.swift` with deterministic expectations:

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
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.reminders, [])
    }

    func testReminderNormalizationPreservesIdsAndOrder() {
        let first = Reminder(id: UUID(), name: "  Water  ", message: "  Drink\nwater  ", intervalMinutes: 999, enabled: true)
        let second = Reminder(id: UUID(), name: "  Stretch ", message: String(repeating: "x", count: 200), intervalMinutes: -3, enabled: false)
        var settings = AppSettings.defaults
        settings.reminders = [first, second]
        let value = settings.normalized
        XCTAssertEqual(value.reminders.map(\.id), [first.id, second.id])
        XCTAssertEqual(value.reminders.map(\.name), ["Water", "Stretch"])
        XCTAssertEqual(value.reminders.map(\.message), ["Drink water", String(repeating: "x", count: 120)])
        XCTAssertEqual(value.reminders.map(\.intervalMinutes), [120, 1])
    }

    func testBlankReminderFieldsAreInvalidInsteadOfReceivingInventedFallbacks() {
        var settings = AppSettings.defaults
        settings.reminders = [Reminder(name: "   ", message: "Drink", intervalMinutes: 5, enabled: true)]
        XCTAssertNotNil(settings.normalized.reminderValidationMessage)
        settings.reminders[0].name = "Water"
        settings.reminders[0].message = " \n "
        XCTAssertNotNil(settings.normalized.reminderValidationMessage)
    }
}
```

- [ ] **Step 2: Write failing migration tests**

Add tests that decode legacy JSON with no `reminders` key and prove current JSON does not resurrect legacy objects:

```swift
func testLegacyBlinkAndPostureFieldsMigrateIntoReminders() throws {
    let data = Data(#"{"blinkEnabled":false,"blinkMinutes":8,"blinkMessage":"Slow blink","postureEnabled":true,"postureMinutes":17,"postureMessage":"Sit tall"}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data)
    XCTAssertEqual(settings.reminders.map(\.name), ["Blink", "Posture"])
    XCTAssertEqual(settings.reminders.map(\.enabled), [false, true])
    XCTAssertEqual(settings.reminders.map(\.intervalMinutes), [8, 17])
    XCTAssertEqual(settings.reminders.map(\.message), ["Slow blink", "Sit tall"])
}

func testStoredReminderArrayWinsOverLegacyFields() throws {
    let custom = Reminder(id: UUID(), name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
    let encodedReminder = try JSONEncoder().encode([custom])
    let remindersJSON = String(decoding: encodedReminder, as: UTF8.self)
    let data = Data("{\"reminders\":\(remindersJSON),\"blinkEnabled\":true,\"postureEnabled\":true}".utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data)
    XCTAssertEqual(settings.reminders, [custom])
}
```

- [ ] **Step 3: Run the focused tests and confirm they fail**

Run:

```bash
xcodebuild test \
  -project LookAway.xcodeproj \
  -scheme LookAway \
  -configuration Debug \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  -only-testing:LookAwayTests/ReminderSettingsTests
```

Expected: compile/test failures because `Reminder` and `AppSettings.reminders` do not exist.

- [ ] **Step 4: Implement the reminder value type and defaults**

In `AppSettings.swift`, add a focused model with deterministic seed IDs so defaults and legacy migration are stable across launches:

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

Replace the six Blink/Posture stored properties with:

```swift
var reminders: [Reminder] = [.defaultBlink, .defaultPosture]
```

Keep global reminder fields such as `reminderSeconds`, `reminderDisplays`, `reminderStyle`, `bannerPosition`, and `soundOnReminder`.

- [ ] **Step 5: Normalize and validate reminders without inventing content**

Use a single whitespace cleaner for names/messages and expose validation separately:

```swift
var reminderValidationMessage: String? {
    for reminder in normalized.reminders {
        if reminder.name.isEmpty { return "Reminder name is required." }
        if reminder.message.isEmpty { return "Reminder message is required." }
    }
    return nil
}
```

During `normalized`, map reminders while preserving IDs/order:

```swift
result.reminders = reminders.map { reminder in
    var value = reminder
    value.name = Self.cleanedText(reminder.name, limit: 120)
    value.message = Self.cleanedText(reminder.message, limit: 120)
    value.intervalMinutes = Self.clamp(reminder.intervalMinutes, to: Self.reminderMinutesRange)
    return value
}
```

Do not substitute Blink/Posture text for empty user-created reminders.

- [ ] **Step 6: Implement one-way legacy decoding**

Keep current stored fields in normal `CodingKeys`, including `reminders`, but read removed fields through a separate legacy key enum:

```swift
private enum LegacyReminderKeys: String, CodingKey {
    case blinkEnabled, blinkMinutes, blinkMessage
    case postureEnabled, postureMinutes, postureMessage
}
```

In `init(from:)`, if the current container contains `reminders`, decode it exactly, including an empty array. Otherwise build the two seeded reminders from the legacy container and old defaults. Because the legacy keys are not in the normal encoding keys, newly encoded settings must contain `reminders` and must not contain `blinkEnabled`, `blinkMinutes`, `blinkMessage`, `postureEnabled`, `postureMinutes`, or `postureMessage`.

- [ ] **Step 7: Make `SettingsStore.save` reject invalid reminder drafts**

Add a small error type and guard before persistence:

```swift
enum SettingsValidationError: Error, Equatable {
    case invalidReminder(String)
}

@discardableResult
func save(_ candidate: AppSettings) throws -> Bool {
    let next = candidate.normalized
    if let message = next.reminderValidationMessage {
        throw SettingsValidationError.invalidReminder(message)
    }
    guard next != value else { return false }
    let data = try JSONEncoder().encode(next)
    defaults.set(data, forKey: Self.storageKey)
    value = next
    return true
}
```

- [ ] **Step 8: Update existing settings tests to generic reminders**

Replace direct `blink*`/`posture*` mutations in `SettingsTests.swift` and `ExtendedSettingsTests.swift` with reminder-array mutations. Keep the existing coverage for bounds, presets, persistence, defaults, and unrelated preferences.

- [ ] **Step 9: Run settings/model tests**

Run:

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

### Task 2: Generic reminder scheduler with ID-based reconciliation

**Files:**
- Modify: `LookAway/BreakSchedule.swift`
- Modify: `LookAwayTests/LookAwayTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`
- Create: `LookAwayTests/ReminderScheduleTests.swift`

**Interfaces:**
- Consumes: `Reminder.id`, `Reminder.intervalMinutes`, `Reminder.enabled`
- Produces: `ReminderScheduleConfiguration { id: UUID, intervalSeconds: Int }`
- Produces: `BreakConfiguration.reminders: [ReminderScheduleConfiguration]`
- Produces: `BreakSchedule.Event.reminder(UUID)`
- Keeps: `BreakSchedule.updateConfiguration(_:at:)`

- [ ] **Step 1: Write failing generic scheduler tests**

Create `ReminderScheduleTests.swift` with fixed UUIDs:

```swift
import XCTest
@testable import LookAway

final class ReminderScheduleTests: XCTestCase {
    private let a = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    private let b = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!

    func testArbitraryReminderIntervalsEmitIdEvents() {
        let config = BreakConfiguration(
            workSeconds: 1800,
            breakSeconds: 30,
            warningSeconds: 60,
            reminders: [
                ReminderScheduleConfiguration(id: a, intervalSeconds: 120),
                ReminderScheduleConfiguration(id: b, intervalSeconds: 180)
            ]
        )
        var schedule = BreakSchedule(configuration: config, now: 0)
        XCTAssertEqual(schedule.advance(at: 119), [])
        XCTAssertEqual(schedule.advance(at: 120), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 180), [.reminder(b)])
    }

    func testSimultaneousGenericRemindersAreReturnedTogether() {
        let config = BreakConfiguration(workSeconds: 1800, breakSeconds: 30, warningSeconds: 60,
            reminders: [.init(id: a, intervalSeconds: 300), .init(id: b, intervalSeconds: 300)])
        var schedule = BreakSchedule(configuration: config, now: 0)
        XCTAssertEqual(schedule.advance(at: 300), [.reminder(a), .reminder(b)])
    }
}
```

- [ ] **Step 2: Add reconciliation tests before implementation**

Cover each required semantic explicitly:

```swift
func testReorderingRemindersDoesNotResetWorkOrReminderDeadlines() { /* configure a/b, advance, reorder, assert original due times */ }
func testAddingReminderStartsOnlyThatReminderFromNow() { /* add b at t=100, b due at 100+interval */ }
func testRemovingReminderDropsItsDeadline() { /* remove a, never emit a */ }
func testChangingOneIntervalRestartsOnlyThatReminder() { /* change a only; b preserves remaining */ }
func testReminderOnlyChangesDoNotResetPendingSkipOrWorkRemaining() { /* keep work remaining and skip */ }
func testPauseAndResumePreserveGenericReminderRemainingTime() { /* pause before a due time */ }
func testSleepWakePreservesGenericReminderRemainingTimeWithoutBacklog() { /* freeze during sleep */ }
func testFinishingBreakStartsFreshCyclesForAllEnabledReminders() { /* break then fresh intervals */ }
func testDelayedAdvanceEmitsOnceAndRearmsFromCurrentTime() { /* advance late, no catch-up burst */ }
```

Implement these tests with concrete UUIDs/timestamps rather than helpers that hide the expected deadlines.

- [ ] **Step 3: Run focused scheduler tests and confirm failure**

Run:

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderScheduleTests
```

Expected: compile failures for the new generic scheduler types/events.

- [ ] **Step 4: Replace Blink/Posture scheduler configuration**

Define:

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

Remove `blinkSeconds`, `postureSeconds`, `blinkEnabled`, `postureEnabled`, and `reminderSeconds` from scheduler configuration.

Update `AppSettings.breakConfiguration` to include enabled reminders only:

```swift
reminders: value.reminders.filter(\.enabled).map {
    ReminderScheduleConfiguration(id: $0.id, intervalSeconds: $0.intervalMinutes * 60)
}
```

- [ ] **Step 5: Replace fixed deadlines with dictionaries**

Use:

```swift
private var reminderDeadlines: [UUID: TimeInterval]
private var pausedReminderRemaining: [UUID: TimeInterval] = [:]
```

Initialize enabled deadlines from `configuration.reminders`. Change the event enum to:

```swift
enum Event: Equatable {
    case warning, startBreak, skippedBreak
    case reminder(UUID)
}
```

In `advance(at:)`, iterate `configuration.reminders` in configuration order, emit `.reminder(id)` when due, and set that deadline to `now + intervalSeconds`.

- [ ] **Step 6: Reconcile reminder configuration by ID**

Inside `updateConfiguration(_:at:)`, compare work/break timing separately from reminder schedules. For reminders:

- delete deadlines/paused remaining for removed IDs;
- create deadlines for added IDs at `now + interval` (or paused remaining equal to interval while paused/sleeping);
- when an existing ID changes interval, restart only that ID;
- when an existing ID is unchanged, preserve its deadline/remaining value;
- ignore array order when deciding whether timing changed.

Only a change to `workSeconds` or `breakSeconds` resets the work session and pending skip. A warning-lead change updates `warningSeconds` without restarting work; reset `hasWarned` only when needed so the new lead can still produce one warning.

- [ ] **Step 7: Update pause/resume/sleep/break reset paths**

`pause(at:)` snapshots every enabled reminder's remaining time. `resume(at:)` recreates deadlines from those remaining values. `startWork(at:)` recreates all enabled reminder deadlines from full intervals. Preserve existing manual-pause/sleep behavior.

- [ ] **Step 8: Migrate old scheduler tests**

Replace `.blinkReminder`/`.postureReminder` expectations in `LookAwayTests.swift` and `SettingsTests.swift` with `.reminder(Reminder.blinkID)` / `.reminder(Reminder.postureID)` or purpose-built IDs. Delete tests whose only purpose was proving two hardcoded booleans were independent and replace them with generic collection tests.

- [ ] **Step 9: Run all scheduler-related tests**

Run:

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderScheduleTests -only-testing:LookAwayTests/LookAwayTests -only-testing:LookAwayTests/SchedulerSettingsTests
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add LookAway/BreakSchedule.swift LookAway/AppSettings.swift LookAwayTests/ReminderScheduleTests.swift LookAwayTests/LookAwayTests.swift LookAwayTests/SettingsTests.swift
git commit -m "refactor: schedule reminders by id"
```

---

### Task 3: Resolve generic reminder events into one presentation and one sound

**Files:**
- Modify: `LookAway/PresentationSupport.swift`
- Modify: `LookAway/AppDelegate.swift`
- Modify: `LookAwayTests/SoundRoutingTests.swift`
- Create: `LookAwayTests/ReminderPresentationTests.swift`

**Interfaces:**
- Consumes: `[BreakSchedule.Event]`, `AppSettings.reminders`
- Produces: `ReminderPresentationResolver.message(for:settings:) -> String?`
- Keeps: `SoundEvent.selected(for:settings:) -> SoundEvent?`

- [ ] **Step 1: Write failing presentation-resolution tests**

Create:

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
        XCTAssertEqual(ReminderPresentationResolver.message(for: [.reminder(disabled.id), .reminder(active.id), .reminder(UUID())], settings: settings), "Active")
    }
}
```

- [ ] **Step 2: Update sound-routing tests to generic reminder events**

Replace hardcoded Blink/Posture events with fixed `.reminder(id)` values and retain the warning-priority rule.

- [ ] **Step 3: Run focused tests and confirm failure**

Run:

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/ReminderPresentationTests -only-testing:LookAwayTests/SoundRoutingTests
```

Expected: failure because the resolver does not exist and sound routing still checks old event cases.

- [ ] **Step 4: Implement the resolver and generic sound detection**

In `PresentationSupport.swift`:

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

Update `SoundEvent.selected` so any `.reminder(_)` counts as one reminder sound while warning remains higher priority when both sounds are enabled.

- [ ] **Step 5: Simplify `AppDelegate.tick()`**

Replace special-case message assembly with:

```swift
let settings = settingsStore.value
if let message = ReminderPresentationResolver.message(for: events, settings: settings) {
    overlayController.show(
        mode: .reminder(message: message, duration: settings.reminderSeconds),
        settings: settings
    )
}
```

Update `applySettings` to call `schedule.updateConfiguration(settingsStore.value.breakConfiguration, at: now)` after every successful save; the scheduler itself now decides whether work timing or only reminder timing changed. Do not compare whole `BreakConfiguration` in `AppDelegate`, because array order changes are not work-timer changes.

- [ ] **Step 6: Run presentation/sound tests**

Run the focused command from Step 3 again. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add LookAway/PresentationSupport.swift LookAway/AppDelegate.swift LookAwayTests/SoundRoutingTests.swift LookAwayTests/ReminderPresentationTests.swift
git commit -m "refactor: present generic reminders"
```

---

### Task 4: Settings editor reminder operations and save validation

**Files:**
- Modify: `LookAway/SettingsEditor.swift`
- Modify: `LookAwayTests/SettingsTests.swift`

**Interfaces:**
- Produces: `SettingsEditor.validationMessage: String?`
- Produces: `SettingsEditor.canSave: Bool`
- Produces: `addReminder(_:)`, `removeReminder(id:)`, `moveReminder(id:before:)`, `moveReminderToEnd(id:)`

- [ ] **Step 1: Write failing editor tests**

Add concrete tests:

```swift
func testEditorBlocksSaveForInvalidReminder() {
    var applied = 0
    let editor = SettingsEditor(settings: .defaults) { _ in applied += 1 }
    editor.draft.reminders[0].message = "   "
    XCTAssertNotNil(editor.validationMessage)
    XCTAssertFalse(editor.canSave)
    XCTAssertFalse(editor.apply())
    XCTAssertEqual(applied, 0)
}

func testEditorAddsDeletesAndReordersReminderDraftsOnly() {
    let editor = SettingsEditor(settings: .defaults) { _ in }
    let custom = Reminder(name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
    editor.addReminder(custom)
    XCTAssertEqual(editor.draft.reminders.last, custom)
    editor.moveReminder(id: custom.id, before: Reminder.blinkID)
    XCTAssertEqual(editor.draft.reminders.first?.id, custom.id)
    editor.removeReminder(id: custom.id)
    XCTAssertFalse(editor.draft.reminders.contains { $0.id == custom.id })
    XCTAssertEqual(editor.saved, .defaults)
}
```

- [ ] **Step 2: Run the editor tests and confirm failure**

Run `SettingsTests` only; expected failures for missing APIs.

- [ ] **Step 3: Implement editor validation and collection operations**

Use draft-only mutations:

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
```

Implement move operations by finding source/target indices and using `Array.move(fromOffsets:toOffset:)` semantics without touching `saved`.

When `apply()` is called with validation failure, set `errorMessage` to the actionable validation message and return `false` before invoking `onApply`.

- [ ] **Step 4: Run `SettingsTests`**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LookAway/SettingsEditor.swift LookAwayTests/SettingsTests.swift
git commit -m "feat: edit reminder collections in settings draft"
```

---

### Task 5: Compact shared Settings layout and five-tab information architecture

**Files:**
- Create: `LookAway/SettingsComponents.swift`
- Modify: `LookAway/SettingsView.swift`
- Modify: `LookAway/SettingsWindowController.swift`
- Modify: `LookAwayTests/SettingsLayoutTests.swift`
- Modify: `LookAwayTests/SettingsTests.swift`

**Interfaces:**
- Produces: `SettingsLayout` metrics used by all settings rows
- Produces: `SettingsRow<Content>` and convenience numeric/text/picker/date rows
- Keeps: `SettingsView(editor:login:soundPlayer:onPreview:onClose:)`

- [ ] **Step 1: Expand structural regression tests before changing the view**

Update `SettingsLayoutTests.swift` to assert the five-tab architecture and shared row component. Read both `SettingsView.swift` and `SettingsComponents.swift` in the test helper. Required assertions:

```swift
XCTAssertFalse(settingsSource.contains("schedule.tabItem"))
XCTAssertFalse(settingsSource.contains("private var schedule"))
XCTAssertTrue(settingsSource.contains("settingsSection(\"Working hours\")"))
XCTAssertTrue(settingsSource.contains("settingsSection(\"Reminder presentation\")"))
XCTAssertTrue(componentsSource.contains("struct SettingsRow"))
XCTAssertTrue(componentsSource.contains("static let labelWidth"))
XCTAssertFalse(settingsSource.contains("private let labelWidth"))
XCTAssertFalse(settingsSource.contains("note(\""))
```

Also retain the existing ban on `Form {` and `LabeledContent(`.

- [ ] **Step 2: Add a window-geometry regression test**

In `SettingsTests.swift`:

```swift
func testSettingsWindowUsesCompactDefaultAndMinimumSize() throws {
    let controller = SettingsWindowController(settings: { .defaults }, onApply: { _ in })
    let window = try XCTUnwrap(controller.window)
    XCTAssertLessThanOrEqual(window.frame.width, 720)
    XCTAssertLessThanOrEqual(window.frame.height, 540)
    XCTAssertLessThanOrEqual(window.contentMinSize.height, 500)
}
```

- [ ] **Step 3: Run layout/window tests and confirm failure**

Run:

```bash
xcodebuild test -project LookAway.xcodeproj -scheme LookAway -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -only-testing:LookAwayTests/SettingsLayoutTests -only-testing:LookAwayTests/SettingsTests/testSettingsWindowUsesCompactDefaultAndMinimumSize
```

Expected: failures because Schedule still exists, controls are local ad hoc rows, and the window is 760x760 with a 620-point minimum height.

- [ ] **Step 4: Create one shared compact row system**

In `SettingsComponents.swift`, define explicit geometry instead of stretching to available width:

```swift
enum SettingsLayout {
    static let pageWidth: CGFloat = 560
    static let labelWidth: CGFloat = 180
    static let columnGap: CGFloat = 12
    static let pickerWidth: CGFloat = 220
    static let textWidth: CGFloat = 300
    static let numberWidth: CGFloat = 64
    static let pagePadding: CGFloat = 18
    static let sectionGap: CGFloat = 14
    static let rowGap: CGFloat = 8
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayout.columnGap) {
            Text(label)
                .lineLimit(1)
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }
}
```

Add `SettingsNumericRow`, `SettingsTextRow`, `SettingsPickerRow`, and `SettingsDateRow` using this same label width and explicit control widths. Numeric rows keep field + unit + stepper as one compact cluster.

- [ ] **Step 5: Reorganize `SettingsView` into five tabs**

Tab order becomes exactly:

```swift
general.tabItem { Label("General", systemImage: "gearshape") }
breaks.tabItem { Label("Breaks", systemImage: "cup.and.saucer") }
reminders.tabItem { Label("Reminders", systemImage: "bell") }
appearance.tabItem { Label("Appearance", systemImage: "paintbrush") }
sounds.tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
```

Move the complete Working Hours section into General after Menu Bar. Delete the Schedule view/property.

Move Reminder style, Reminder displays, Show reminders for, and Banner position into `Appearance > Reminder presentation`. Rename the first appearance section to `App appearance`, and keep Break Screen/Preview below it.

Change sound copy from `With blink or posture reminders` to `With reminders`.

- [ ] **Step 6: Convert ordinary controls to shared rows**

Use `SettingsPickerRow` for settings appearance, reminder style/displays, break displays, banner position, and sound. Use `SettingsNumericRow` for all numeric controls. Use `SettingsTextRow` for break message. Use `SettingsDateRow` for From/Until. Toggles may remain native rows when they do not have a separate value control.

Do not add explanatory gray text.

- [ ] **Step 7: Reduce page and window geometry**

Set page/section spacing from `SettingsLayout`. Change `SettingsWindowController` to a compact initial size around 700x520 and `contentMinSize` around 660x480. Change `SettingsView` minimum frame accordingly so the window is not forced back to 580+ content height.

- [ ] **Step 8: Run layout/window tests**

Expected: PASS.

- [ ] **Step 9: Commit**

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
- Consumes: `SettingsEditor` reminder operations from Task 4
- Produces: `ReminderSettingsView`
- Produces: `ReminderCard`
- Produces: `AddReminderSheet`

- [ ] **Step 1: Add structural reminder-UI regression tests**

Assert that the Reminders page is object-driven and creation uses a sheet:

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

- [ ] **Step 2: Add modal validation tests at the logic layer**

Keep view state thin by exposing a small testable draft type in `ReminderSettingsView.swift`:

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

Add tests proving blank name/message disable Add, defaults are 5 minutes/enabled, and conversion keeps entered values.

- [ ] **Step 3: Run the reminder UI/logic tests and confirm failure**

Run `SettingsLayoutTests` and the new `NewReminderDraft` tests. Expected: missing types/source structure.

- [ ] **Step 4: Build the Reminders header and card stack**

`ReminderSettingsView` owns `@State private var isAddingReminder = false` and renders:

```swift
HStack {
    Text("Reminders").font(.headline)
    Spacer()
    Button("Add Reminder", systemImage: "plus") { isAddingReminder = true }
}
```

Then:

```swift
ForEach($editor.draft.reminders) { $reminder in
    ReminderCard(
        reminder: $reminder,
        onDelete: { editor.removeReminder(id: reminder.id) },
        onMoveBefore: { draggedID in editor.moveReminder(id: draggedID, before: reminder.id) }
    )
}
```

Render an explicit end drop target after the final card that calls `moveReminderToEnd(id:)`.

- [ ] **Step 5: Implement compact editable cards**

Card header contains only:

- drag handle (`line.3.horizontal`) with `.draggable(reminder.id.uuidString)`;
- enabled toggle;
- inline name text field;
- trailing trash button.

Body uses the same `SettingsRow` system as the rest of Settings for:

```text
Message      [text field]
Remind every [number] min [stepper]
```

Add `.dropDestination(for: String.self)` on each card and parse the dragged UUID. The card body itself must not be draggable.

If normalized name or message is empty, show one compact red actionable line inside that card and let `editor.canSave` keep Save disabled.

- [ ] **Step 6: Implement the Add Reminder sheet**

The sheet owns `@State var draft = NewReminderDraft()` and uses the shared rows for Name, Message, and Remind every. Add and Cancel buttons sit in a standard trailing button row. Disable Add when `!draft.canAdd`.

On Add:

```swift
editor.addReminder(draft.reminder())
isAddingReminder = false
```

Cancel closes the sheet without mutating `editor.draft`.

- [ ] **Step 7: Wire the Reminders tab**

Replace the old body with:

```swift
private var reminders: some View {
    ReminderSettingsView(editor: editor)
}
```

Change the footer Save button disabled condition to `!editor.canSave`. Keep error text only when actionable.

- [ ] **Step 8: Run reminder/settings tests**

Run:

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

### Task 7: Rewrite README and update developer/testing documentation

**Files:**
- Rewrite: `readme.md`
- Modify: `docs/development.md`
- Modify: `docs/testing.md`

**Interfaces:**
- Documents the five-tab Settings UI and generic reminder model
- Documents current updater semantics accurately
- Removes stale Blink/Posture-special-case and six-tab language

- [ ] **Step 1: Rewrite `readme.md` from the product-user perspective**

Replace the current short README with a clearer structure:

```markdown
# LookAway

LookAway is a native macOS menu-bar app that helps you take screen breaks and create lightweight recurring reminders without an account.

## What it does
- Scheduled screen breaks with warning, skip, and postpone controls
- Any number of custom reminders, with Blink and Posture included as editable defaults
- Full-screen or compact reminder presentation
- Working-hours scheduling
- Display targeting, sounds, break-screen appearance, and preview
- Automatic update checks with one-click installation from the menu bar

## Install
...

## Everyday use
...

## Reminders
Explain Add Reminder, cards, rename/edit/reorder/delete, and that Blink/Posture are ordinary defaults.

## Settings
Explain the five tabs: General, Breaks, Reminders, Appearance, Sounds.

## Updates
Explain that LookAway checks automatically; the menu shows `Update to version x.x.x` or `App is up to date`; installation starts only when the user chooses the update; successful relaunch shows a menu-bar popover.

## Privacy and scope
Explain no account, local preferences, no camera/microphone/Accessibility/Screen Recording requirement, and that GitHub is contacted for update checks.

## Support and development
Link issues, `docs/development.md`, and `docs/testing.md`.
```

Keep the macOS 15.4+ requirement, installer command, universal Apple Silicon/Intel wording, SHA-256 verification, and non-notarized warning. Remove the inaccurate statement that future updates are automatically installed without user action.

- [ ] **Step 2: Update `docs/development.md`**

Change:

- six Settings tabs to five;
- Blink/Posture fields to `AppSettings.reminders`;
- reminder interval docs to generic 1–120 minute reminder intervals;
- runtime configuration semantics so reminder-only edits reconcile by ID without resetting work time;
- code map to include `SettingsComponents.swift` and `ReminderSettingsView.swift`;
- updater paragraph if it still says there is no automatic updater;
- message behavior so blank custom reminder fields are invalid rather than silently defaulted.

- [ ] **Step 3: Update `docs/testing.md` manual checklist**

Replace stale items such as `All six tabs`, `blink/posture intervals`, and old reminder special cases with checks for:

- five tabs;
- compact aligned row columns;
- General containing Working Hours;
- Appearance containing Reminder Presentation;
- Add Reminder modal validation;
- inline edit/delete/reorder of seeded and custom cards;
- deleting all reminders;
- migration from old preferences;
- simultaneous arbitrary reminders;
- reminder-only edits preserving work time;
- updater menu state and success popover.

Keep unchecked manual items unchecked.

- [ ] **Step 4: Search for stale product language**

Run:

```bash
grep -RInE 'six Settings tabs|Blink / posture interval|blinkEnabled|postureEnabled|\.blinkReminder|\.postureReminder|check for updates' readme.md docs LookAway LookAwayTests || true
```

Expected: no stale user-facing/docs references; code/test matches may only remain inside explicit legacy-migration key handling where necessary.

- [ ] **Step 5: Commit**

```bash
git add readme.md docs/development.md docs/testing.md
git commit -m "docs: rewrite readme for custom reminders"
```

---

### Task 8: Full regression verification and release-quality review

**Files:**
- Modify only if verification exposes defects in files already touched above.

**Interfaces:**
- Verifies the complete feature against the approved spec and README requirement.

- [ ] **Step 1: Run the full unit/regression suite**

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

Expected: exit 0 and zero failing tests.

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

Expected: build succeeds and `lipo` verifies both `arm64` and `x86_64`.

- [ ] **Step 3: Perform a source-level architecture sweep**

Run:

```bash
grep -RInE '\bblinkEnabled\b|\bblinkMinutes\b|\bblinkMessage\b|\bpostureEnabled\b|\bpostureMinutes\b|\bpostureMessage\b|\.blinkReminder|\.postureReminder' LookAway LookAwayTests || true
```

Expected: only explicit legacy decoding keys/test fixtures may remain; no runtime/UI/scheduler logic may depend on them.

Run:

```bash
grep -RIn 'Schedule"' LookAway/SettingsView.swift LookAway/ReminderSettingsView.swift || true
grep -RIn 'Presentation"' LookAway/ReminderSettingsView.swift || true
```

Expected: no Schedule tab and no reminder-presentation section inside Reminders.

- [ ] **Step 4: Review acceptance criteria line by line**

Check the implementation against every acceptance criterion in `docs/superpowers/specs/2026-09-14-reminder-settings-redesign-design.md`, plus the user-added README rewrite requirement. Fix any mismatch before opening a PR.

- [ ] **Step 5: Commit any verification fixes**

If Step 1–4 required changes, commit only those verified fixes with a focused message. If no changes were required, do not create an empty commit.

- [ ] **Step 6: Push the implementation branch and open a PR**

Use a feature branch created from `main` for implementation, not the design-only branch. PR description must include:

- generic reminder migration;
- scheduler reconciliation behavior;
- five-tab Settings reorganization;
- cards + Add Reminder modal;
- compact alignment/window changes;
- README/developer/testing documentation rewrite;
- exact test/build commands and passing results.

Do not merge until the PR checks pass and the user approves integration.
