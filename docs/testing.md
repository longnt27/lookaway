# Testing LookAway

## Automated checks

Run the shared `LookAway` scheme with **Product > Test**, or use the [command-line test instructions](development.md#tests-and-contributions). GitHub Actions also builds universal arm64/x86_64 Release binaries and retains `.xcresult`, coverage, and logs.

Scheduling and working-hours tests inject timestamps and calendars; preference tests use isolated defaults suites. Presentation tests cover callbacks, layout calculations, and panel configuration. Login tests use injected service closures, never real registration. Window tests exercise creation and reuse, not end-to-end keyboard or VoiceOver behavior. Building for an architecture is not the same as running on that hardware.

## Manual release checklist

These are checks to perform, not a record of completed tests. Record commit, macOS/Xcode versions, hardware, display layout/scaling, and observations. Leave unverified items unchecked.

For a fast pass, choose a two-minute work session, a ten-second break, one-minute blink/posture intervals, a five-second warning, and two-second reminder visibility. Disable working-hours restrictions initially. Restore your preferences afterward.

### Settings and persistence

- [ ] All six tabs are reachable at the minimum window size. Forms scroll without hiding Save/Cancel. Numeric fields accept typed values and steppers; bounds and units are correct.
- [ ] Reopening an already visible or minimized window keeps the same draft/window. Closing and reopening reloads saved values. Command-comma works while LookAway is active.
- [ ] Cancel, Escape, and window-close discard draft changes without changing timers. Save persists every preference through a quit/relaunch.
- [ ] Restore Defaults and each timing preset affect only the draft until Save. Presets retain unrelated settings. Reset/cancel never changes launch-at-login registration.
- [ ] Reducing work duration clamps warning lead; reducing break duration clamps ready delay. Empty messages revert to defaults when saved; long/Unicode messages remain readable.
- [ ] Save timing changes while paused: the timer remains paused with the new interval. Save during a running break: it retains its original duration and presentation.
- [ ] Save appearance, sound, display, message, and menu-bar preferences: elapsed time and a pending skip remain unchanged. Old visible warning controls cannot act on later sessions.
- [ ] Hiding countdown or seconds leaves a clickable status icon and useful tooltip/accessibility label. Start-paused takes effect on the next launch, not immediately.

### Work, warnings, and sleep

- [ ] Countdown starts at the configured interval, stays nonnegative, and continues while its menu is open.
- [ ] Pause freezes work/reminder time and removes warnings/reminders. Resume preserves remaining time.
- [ ] Sleep/wake preserves work time and a manual pause. Sleep during a break removes it and starts a fresh session on wake, without an end sound or a reminder burst.
- [ ] The warning appears at the selected lead time and lasts the selected visibility duration. I Know, X, and timeout do not move the deadline.
- [ ] Skip Break suppresses one break only. Turning off skipping removes that control; a previously selected skip remains pending until consumed or overridden by a manual break.
- [ ] Postpone displays and adds the chosen number of minutes and rearms the warning. Test a value other than the five-minute default.
- [ ] Repeated Start Break Now cannot restart an active break. Manual breaks override pending skips.
- [ ] Quit during a warning, reminder, break, or sound preview: all windows/sounds stop and do not return. Relaunch uses saved preferences and a fresh session.

### Break screens and reminders

- [ ] Early finish is enabled after the selected delay on every display. Zero permits immediate finish. Disabling early finish hides the button but the break still completes automatically.
- [ ] Early finish and natural completion each start exactly one work session. Old or repeated clicks do not restart or close a newer session.
- [ ] Clock and break-countdown visibility are independent and never prevent completion. Dimming, text size, and custom messages match the static preview.
- [ ] Previewing appearance neither starts a break nor resets the work timer. The preview finish button cannot affect the real schedule.
- [ ] Blink and posture toggles/intervals/messages are independent. Simultaneous reminders share a presentation. Neither compact nor full-screen reminders replace an active break.
- [ ] Reminders pass clicks through; warning and break buttons accept the first click. Test custom text at maximum length and size in a compact reminder.

### Working hours

- [ ] Outside selected hours, automatic breaks/reminders pause and the menu reports Outside hours. The timer resumes its remaining time when hours begin.
- [ ] A manually paused timer never resumes automatically. Keep Paused during a scheduled pause prevents its later automatic resume.
- [ ] Change/disable working hours while automatically paused: eligibility updates without resetting remaining work. A manual pause remains paused.
- [ ] Test a daytime interval, overnight interval, Saturday-to-Sunday transition, equal times (whole selected day), and no selected days (no automatic activity).
- [ ] Sleep and wake across a schedule boundary. Check local timezone/DST changes. No negative countdown or burst of reminders appears.
- [ ] A break already in progress finishes when working hours end. Start Break Now remains available outside hours.

### Login and sounds

- [ ] With an installed, locally signed app, enable launch at login, inspect macOS Login Items, log out/in, and verify launch. Disable it and verify the next login does not launch it.
- [ ] Denied approval/registration errors are visible rather than reporting success. Changing Login Items in System Settings is reflected when returning to LookAway.
- [ ] Opening, closing, canceling, or restoring the Settings draft does not register/unregister the app. Only the explicit login toggle changes registration immediately.
- [ ] Sounds are silent by default. Enable warning, break-start, break-end, and reminder sounds separately; only the selected events play.
- [ ] Preview each sound at several volumes, including zero; closing Settings stops preview playback. Simultaneous warning/reminder events do not overlap sounds.

### Displays, focus, and accessibility

- [ ] Test all, primary, and pointer display selections independently for breaks/warnings and reminders. Moving the pointer after appearance does not move an existing presentation.
- [ ] Test displays to the left, right, and above the primary monitor, different scaling, and top/center/bottom banner positions. Windows remain within the selected display's usable area.
- [ ] Disconnect/reconnect or rearrange displays mid-break. Countdown and ready delay are preserved; warnings dismiss and no invisible window intercepts input.
- [ ] Dismissing on one monitor removes all copies exactly once. Test multiple Spaces and a full-screen foreground app.
- [ ] Type in another application when warnings/reminders/breaks appear: LookAway does not activate. Opening Settings intentionally does activate it. This is not a keyboard lock.
- [ ] Disable animations, then independently enable system Reduce Motion. Fades are suppressed. Reduce Transparency replaces blur with a readable solid background.
- [ ] Test Settings in light, dark, and system appearance, keyboard navigation and VoiceOver, including weekday toggles, typed numeric inputs, save errors, and launch approval status.
