# Reminder and Settings Redesign

Date: 2026-09-14
Status: Approved design, pending implementation plan

## Summary

Redesign LookAway settings around a reusable reminder model instead of the current hardcoded Blink/Posture special cases, while simplifying and tightening the settings UI.

The redesign has four goals:

1. Replace Blink/Posture-specific settings and scheduler logic with a generic reminder collection.
2. Make Blink and Posture ordinary seeded reminder objects that can be edited, reordered, disabled, or deleted like user-created reminders.
3. Reorganize Settings so each tab has a clear purpose, removing the nearly empty Schedule tab and moving reminder presentation into Appearance.
4. Make settings rows compact and consistently aligned through a shared label/control grid instead of stretching controls to arbitrary widths.

## Current Problems

The current data model has separate fields for Blink and Posture (`blinkEnabled`, `blinkMinutes`, `blinkMessage`, `postureEnabled`, `postureMinutes`, `postureMessage`), and the scheduler likewise owns separate blink/posture deadlines and event cases. This prevents arbitrary user reminders and forces the UI to treat the two reminders as unique features.

The current settings UI also has several structural problems:

- Controls are much wider than necessary.
- Pickers and numeric/text inputs do not share a common control start position.
- Reminder settings are split into hardcoded Blink, Posture, and Presentation sections.
- Schedule has its own tab despite containing only Working Hours.
- Reminder presentation is conceptually appearance/presentation configuration, not reminder data.
- Settings pages waste vertical space and feel oversized for the amount of configuration present.

## Information Architecture

Settings will have five tabs.

### General

Sections:

- Startup
  - Launch at login
  - Open Login Items Settings when needed
  - Start with timer paused
- Menu Bar
  - Show countdown
  - Include seconds
- Working Hours
  - Only run during selected hours
  - Weekday selection
  - From / Until
  - Actionable warnings only, such as no days selected

The Schedule tab is removed entirely.

### Breaks

Sections:

- Timing
  - Timing preset
  - Break every
  - Break duration
- Before a Break
  - Advance warning
  - Warn before break
  - Show warning for
  - Allow skipping the next break
  - Postpone by
- During a Break
  - Allow finishing early
  - Enable finish button after

### Reminders

The page begins with a header row:

- Left: `Reminders`
- Right: `+ Add Reminder`

Below it is a vertically scrollable stack of compact reminder cards.

There are no special Blink or Posture sections and no Presentation section.

### Appearance

Sections:

- App Appearance
  - Settings appearance
- Reminder Presentation
  - Reminder style
  - Reminder displays
  - Reminder duration
  - Banner position
- Break Screen
  - Break and warning displays
  - Random break quote
  - Break message
  - Show clock
  - Show break countdown
  - Background dimming
  - Overlay text size
  - Animate overlays and warnings
- Preview
  - Preview Break Screen

Reminder presentation remains global. Individual reminders do not choose their own style, display, duration, position, or animation behavior.

### Sounds

Keep sound behavior global rather than adding per-reminder sound configuration.

Sections:

- Play a Sound
  - Before a break
  - When a break starts
  - When a break ends
  - With reminders
- Sound and Volume
  - Sound
  - Volume
  - Preview Sound

## Reminder Data Model

Introduce a reusable Codable reminder value type.

Conceptually:

```swift
struct Reminder: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var message: String
    var intervalMinutes: Int
    var enabled: Bool
}
```

The exact type name may be adjusted if it conflicts with existing framework names, but the shape and semantics are fixed.

### Defaults

Fresh installs begin with two reminders:

1. Blink
   - message: `Blink your eyes`
   - interval: 5 minutes
   - enabled: true
2. Posture
   - message: `Adjust your posture`
   - interval: 10 minutes
   - enabled: true

These objects have no privileged behavior. After creation they are indistinguishable from reminders the user adds later.

Users may:

- Rename them
- Change their message
- Change their interval
- Enable or disable them
- Reorder them
- Delete them

There is no reminder `type` enum and no logic that depends on a reminder being named Blink or Posture.

### AppSettings

Replace the six hardcoded Blink/Posture fields with:

```swift
var reminders: [Reminder]
```

Global reminder presentation fields stay in `AppSettings`, including:

- reminder display selection
- reminder style
- reminder duration
- banner position
- global reminder sound enablement

Normalization must:

- Clamp each reminder interval to the allowed reminder interval range.
- Trim/collapse whitespace in names and messages.
- Enforce the same message length limit used today unless there is a strong implementation reason to change it.
- Preserve reminder order.
- Preserve stable IDs.

The settings model permits an empty reminder array. Deleting all reminders is valid.

## Persistence and Migration

Keep the existing storage key so users migrate in place.

When decoding old stored settings that do not contain a `reminders` field:

- Convert old Blink fields into one Reminder object.
- Convert old Posture fields into one Reminder object.
- Preserve their old enabled state, interval, and message.
- Seed them in Blink, Posture order.

When decoding settings that already contain `reminders`, use the stored collection and do not recreate Blink/Posture.

Migration is one-way at the data-model level. Newly saved settings serialize the generic reminder array rather than the legacy Blink/Posture fields.

Unknown future enum values must continue using the project’s existing safe-fallback behavior.

## Reminder Scheduler Architecture

Replace the dedicated blink/posture deadline fields with generic reminder scheduling state keyed by reminder ID.

Conceptually:

```swift
private var reminderDeadlines: [UUID: TimeInterval]
```

`BreakConfiguration` should carry the reminder timing data required by the scheduler instead of dedicated Blink/Posture seconds and booleans.

A practical configuration shape is a list of enabled reminder schedules, for example:

```swift
struct ReminderScheduleConfiguration: Equatable {
    let id: UUID
    let intervalSeconds: Int
}
```

and:

```swift
var reminders: [ReminderScheduleConfiguration]
```

The state machine should produce reminder events by reminder ID rather than distinct Blink/Posture event cases.

Conceptually:

```swift
case reminder(UUID)
```

or an equivalent event payload.

### Scheduling Semantics

Preserve current timer behavior:

- Reminder clocks pause when the main LookAway timer is manually paused.
- Reminder clocks pause outside Working Hours.
- Sleep freezes reminder timing.
- Waking must not replay a backlog of missed reminders.
- A completed break starts a fresh reminder cycle.
- Updating timing configuration starts fresh timing consistently with the existing settings semantics.
- Disabled reminders have no active deadline.
- Adding, removing, enabling, disabling, reordering, or changing a reminder interval must not leave stale scheduler state behind.

When several reminders become due in the same scheduler advance:

- Emit all due reminder IDs together during that tick.
- Advance each due reminder deadline from the current monotonic time, not from its stale prior deadline, so delayed callbacks do not produce catch-up storms.

## Reminder Presentation

When one or more reminder events fire together:

- Resolve the current reminder objects from their IDs.
- Ignore IDs no longer present or currently disabled.
- Combine due reminder messages into one presentation.
- Preserve reminder collection order when combining messages.
- Separate messages by line breaks.

Do not show one overlay/banner per reminder. Multiple simultaneous reminders produce a single reminder presentation.

The presentation continues to use the global reminder appearance settings.

## Reminder Cards

Each reminder appears as a compact card.

### Card Header

The header contains:

- Enabled toggle
- Reminder name
- Delete/trash button aligned to the trailing edge

The card name is editable inline. The name is not merely a title copied from a hidden model.

### Card Body

Rows:

- Message
- Remind every `[value] min`

Every card uses the same shared row grid as the rest of Settings.

Deleting a card modifies only the Settings draft. There is no confirmation dialog. Cancel restores the pre-edit settings; Save commits the deletion. This makes a second confirmation redundant.

### Reordering

Reminder cards support drag-and-drop reordering. Order is persisted and also defines the order in which simultaneously due reminder messages are combined.

## Add Reminder Modal

Clicking `+ Add Reminder` opens a modal sheet instead of appending a partially configured card directly.

Fields:

- Name
- Message
- Remind every `[5] min`
- Enabled toggle, on by default

Buttons:

- Cancel
- Add

Defaults:

- Name: blank
- Message: blank
- Interval: 5 minutes
- Enabled: true

Validation:

- Add is disabled while Name is empty after trimming whitespace.
- Add is disabled while Message is empty after trimming whitespace.
- Interval is constrained to the supported reminder range.
- Successful creation appends the reminder to the end of the collection and closes the modal.
- Cancel makes no changes.

Editing existing reminders happens inline in their cards. The modal is creation-only.

## Settings Layout System

The previous fix prevented catastrophic label wrapping, but the result is still oversized and visually uneven. Replace ad hoc row widths with one shared compact row system.

### Grid

Settings rows use two primary columns:

```text
Label column | Control column
```

Rules:

- Every control column begins at the same horizontal x-position within a settings page/card.
- Labels use a stable width sized for the longest normal labels without making the window excessively wide.
- Controls do not stretch to the far right edge merely because space exists.
- Pickers, text fields, and numeric controls use sensible explicit widths.
- Numeric controls keep number, unit, and stepper together as one control cluster.
- Picker and text-field leading edges align with numeric-control leading edges.
- Message fields can be wider than numeric controls, but start at the same control-column position.
- Section contents do not stretch to the full window width.

### Density

Reduce vertical and horizontal spacing from the current settings implementation:

- Smaller section gaps
- Smaller row gaps
- Compact cards
- Smaller page padding
- No explanatory helper paragraphs

Only actionable warnings and errors appear as extra text.

The settings window may remain resizable, but the content should have a compact preferred size. The UI must not rely on an unnecessarily tall minimum height to look correct.

## Working Hours Move

Delete the Schedule tab.

Move the complete Working Hours section into General. Behavior is unchanged:

- enable/disable working hours
- selected weekdays
- start/end time
- no-days-selected warning

This is a structural UI move, not a change to active-hours semantics.

## Reminder Presentation Move

Delete Presentation from the Reminders tab.

Move:

- reminder style
- reminder displays
- reminder duration
- banner position

to Appearance > Reminder Presentation.

`bannerPosition` should live visually with reminder presentation even if the current code also uses banner-like presentation elsewhere. If implementation reveals it is genuinely shared by multiple feature families, the label can be generalized while preserving this placement.

## Error Handling

Settings should stay quiet unless the user can act on the information.

Keep inline warnings/errors for cases such as:

- Login item approval required
- Login item registration unavailable
- No Working Hours days selected
- Sound preview unavailable
- Settings save failure

Do not reintroduce explanatory gray prose beneath ordinary controls.

## Testing Strategy

Implementation must use regression coverage for both data behavior and UI structure.

### Model and Migration Tests

Add tests that verify:

- Fresh defaults contain exactly Blink and Posture reminder objects with expected values.
- Legacy Blink/Posture preferences decode into generic reminders without data loss.
- Once a stored `reminders` collection exists, legacy fields do not recreate deleted/default reminders.
- Empty reminder arrays round-trip correctly.
- Reminder IDs and order round-trip correctly.
- Reminder normalization clamps intervals and cleans names/messages.

### Scheduler Tests

Replace Blink/Posture-specific scheduler tests with generic reminder tests covering:

- Arbitrary number of reminders
- Independent intervals
- Enabled/disabled state
- Add/remove/configuration updates
- Pausing and resuming
- Sleep/wake
- Break reset behavior
- Multiple reminders due on the same tick
- No catch-up backlog after delayed callbacks

### App Integration Tests

Verify event-to-presentation behavior:

- Reminder IDs resolve to current settings objects.
- Multiple due reminders combine into one message in reminder-list order.
- Deleted/disabled reminder IDs are safely ignored.
- Reminder sound still fires according to global sound settings.

### Settings/UI Regression Tests

Keep structural regression checks and update them to enforce the new architecture:

- No Schedule tab.
- Working Hours appears under General.
- Reminder Presentation appears under Appearance, not Reminders.
- Reminders UI is generated from `AppSettings.reminders`, not hardcoded Blink/Posture sections.
- Shared row components/grid are used for picker, text, and numeric rows.
- Helper-note prose remains absent.

Where feasible, add focused SwiftUI/AppKit UI tests for actual alignment or minimum layout geometry rather than relying only on source-text assertions.

## Files and Responsibilities

Likely implementation areas:

- `AppSettings.swift`
  - Reminder model
  - defaults
  - normalization
  - Codable migration
  - generic reminder configuration conversion
- `BreakSchedule.swift`
  - generic reminder deadlines
  - reminder-ID events
  - generic pause/resume/sleep/reset behavior
- `SettingsView.swift`
  - new tab structure
  - Working Hours move
  - Reminder cards
  - Add Reminder modal
  - Reminder Presentation move
  - compact shared row grid
- `AppDelegate.swift`
  - resolve generic reminder events
  - combine messages
  - preserve global reminder sound behavior
- Tests
  - migration, scheduler, settings structure, integration behavior

If `SettingsView.swift` becomes too large while implementing cards and the modal, split focused components such as `ReminderCard`, `AddReminderSheet`, and shared setting-row primitives into separate files rather than growing one monolith further.

## Non-Goals

This redesign does not add:

- Per-reminder sound selection
- Per-reminder presentation style
- Per-reminder display targeting
- Per-reminder colors/icons
- Reminder-specific schedules by weekday/time
- Snoozing individual reminders
- Reminder templates beyond the two initial seed objects

Those can be considered later if real usage justifies the complexity.

## Acceptance Criteria

The work is complete when all of the following are true:

1. Fresh installs start with Blink and Posture as ordinary Reminder objects.
2. Existing Blink/Posture user configuration migrates without loss.
3. Users can add reminders through a modal and edit/delete/reorder all reminders through cards.
4. The scheduler supports an arbitrary reminder collection without Blink/Posture-specific fields, deadlines, or event cases.
5. Simultaneous reminders produce one combined presentation.
6. Schedule is removed and Working Hours appears under General.
7. Reminder Presentation appears under Appearance.
8. The Reminders tab contains only the reminder collection UI and Add Reminder action.
9. Settings controls share a consistent aligned control column and are materially more compact than the current UI.
10. Ordinary settings contain no explanatory helper paragraphs; only actionable warnings/errors remain.
11. Global reminder sound and presentation behavior remains functional.
12. Migration, scheduler, settings-structure, and build/regression tests pass before merge.
