# Testing LookAway

## Automated checks

Run the shared `LookAway` scheme with **Product > Test**, or use the [command-line test instructions](development.md#tests-and-contributions). GitHub Actions runs the regression suite, builds a universal arm64/x86_64 Release app, verifies both architectures, and retains results/logs.

Scheduling tests inject monotonic timestamps; preference tests use isolated defaults suites. Presentation tests cover reminder resolution, callbacks, display calculations, and panel configuration. Login tests use injected service closures rather than real registration.

## Manual release checklist

These are checks to perform, not a record of completed tests. Record commit, macOS/Xcode versions, hardware, display layout/scaling, and observations. Leave unverified items unchecked.

For a fast pass, choose a two-minute work session, a ten-second break, one-minute reminder intervals, a five-second warning, and two-second reminder visibility. Disable working-hours restrictions initially. Restore preferences afterward.

### Settings layout and persistence

- [ ] Exactly five tabs are present: General, Breaks, Reminders, Appearance, Sounds. There is no Schedule tab.
- [ ] General contains Startup, Menu bar, and Working hours. Appearance contains Reminder presentation and Break screen.
- [ ] At the minimum window size, labels stay horizontal and every picker/text/numeric control begins at the same control-column position. Controls do not stretch to the far edge for no reason.
- [ ] General and Breaks fit comfortably in the compact default window. Save/Cancel remain visible while page content scrolls when needed.
- [ ] Settings contains no explanatory gray helper paragraphs. Only actionable warnings/errors appear as extra text.
- [ ] Reopening an already visible/minimized window keeps its draft. Closing/reopening reloads saved values. Command-comma opens the reusable window.
- [ ] Cancel, Escape, and window-close discard draft changes. Save persists preferences through quit/relaunch.
- [ ] Restore Defaults and timing presets change only the draft until Save. They do not change launch-at-login registration.
- [ ] Reducing work duration clamps warning lead; reducing break duration clamps early-finish delay. Typed numeric values and steppers respect their bounds.
- [ ] Appearance, sound, display, reminder text/order, and menu-bar edits do not reset elapsed work time or a pending skip.

### Reminder collection

- [ ] A fresh install starts with two cards: Blink every 5 minutes and Posture every 10 minutes.
- [ ] Blink and Posture behave exactly like custom reminders: rename, edit message/interval, enable/disable, drag-reorder, and delete all work.
- [ ] **Add Reminder** is at the top and opens a modal sheet. Name and Message are required; interval defaults to 5 minutes; Enabled defaults on.
- [ ] Canceling the Add Reminder sheet creates nothing. Adding appends one card to the end of the draft.
- [ ] Card fields align to the same control column. The drag handle alone initiates reordering; editing text does not drag the card.
- [ ] Trash removes a card from the draft without a confirmation dialog. Canceling Settings restores it; Save commits deletion.
- [ ] Delete every reminder and Save. Relaunch preserves an empty reminder list rather than recreating Blink/Posture.
- [ ] A legacy preferences payload migrates old Blink/Posture enabled state, intervals, and messages into two ordinary reminder objects without loss.
- [ ] Blank inline reminder name/message blocks Save with one actionable error rather than silently inventing text.
- [ ] Reordering or editing name/message does not change any active reminder deadline. Changing one interval restarts only that reminder.
- [ ] Adding/enabling starts that reminder from now. Removing/disabling removes its deadline. None of these reminder-only edits reset the work timer.
- [ ] Multiple reminders due on the same tick appear once, with messages combined in the current card order.

### Work, breaks, warnings, and sleep

- [ ] Countdown starts at the configured interval, stays nonnegative, and continues while its menu is open.
- [ ] Pause freezes work and every reminder clock. Resume restores their remaining time.
- [ ] Sleep/wake preserves work/reminder remaining time and manual pause state without a reminder burst.
- [ ] Warning timing, visibility, Skip Break, and Postpone work with values other than defaults. Dismissing a warning does not move the break deadline.
- [ ] A work/break timing edit starts the expected fresh work session while preserving paused/sleeping intent. Reminder-only edits do not.
- [ ] Repeated Start Break Now does not restart an active break. Manual breaks override a pending skip.
- [ ] Early finish obeys its delay; disabling it hides the button while natural completion still works.
- [ ] Previewing the break screen neither starts a real break nor resets the work timer. Repeated Preview presses restart the preview cleanly.

### Working hours

- [ ] Enabling Working hours in General exposes weekday and From/Until controls. Selecting no days shows an actionable warning.
- [ ] Outside selected hours, automatic breaks/reminders pause and the menu reports Outside hours. The timer resumes its remaining time when hours begin.
- [ ] A manually paused timer never resumes automatically. Keep Paused during a scheduled pause cancels automatic resume.
- [ ] Test daytime, overnight, Saturday/Sunday transition, equal start/end, no selected days, and a sleep/wake across a schedule boundary.
- [ ] A break already in progress finishes when working hours end. Start Break Now remains available outside hours.

### Appearance, sounds, displays, and focus

- [ ] Reminder presentation controls live under Appearance and affect every reminder globally: style, displays, duration, and banner position.
- [ ] Test compact and full-screen reminders. Neither replaces an active break; reminder windows pass clicks through.
- [ ] Test all, primary, and pointer display selections independently for breaks/warnings and reminders, including displays on negative coordinates and mixed scaling.
- [ ] Disconnect/rearrange displays mid-break. Countdown/ready delay survive; no invisible window intercepts input.
- [ ] Sounds are silent by default. Enable warning, break-start, break-end, and reminder sound independently. Simultaneous warning/reminder events play at most one sound.
- [ ] Preview sounds at several volumes including zero; closing Settings stops preview playback.
- [ ] Opening Settings activates LookAway. Warnings/reminders/break overlays do not steal application focus.
- [ ] Test light, dark, and system settings appearance, keyboard navigation, and VoiceOver across the compact row layout and reminder cards.

### Login and updates

- [ ] With an installed, signed app, enable/disable launch at login and verify macOS Login Items plus next-login behavior. Approval/registration failures are shown honestly.
- [ ] Cancel/Restore Defaults never revert launch-at-login changes because macOS owns that setting directly.
- [ ] After launch, the update menu progresses from checking to either `App is up to date` or `Update to version x.x.x`.
- [ ] With an available release, the app does not install it merely because the background check found it. Selecting the update item starts installation.
- [ ] An update cannot install during an active break.
- [ ] After a verified update replaces and relaunches the app, a popover from the menu-bar icon confirms the running version.
- [ ] Wake the Mac and verify an update check occurs without disrupting work/reminder timers.
