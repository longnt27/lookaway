# Testing LookAway

## Automated checks

From the repository root, run:

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

The shared scheme runs `LookAwayTests`, not the generated `LookAwayUITests` starter target. Scheduling tests supply explicit timestamps. Most presentation tests supply an empty display list and drive the controller directly; panel and settings-window tests construct AppKit windows. Preference tests use isolated defaults suites. These are not end-to-end tests of typing in another application or clicking controls on physical displays.

GitHub Actions also builds both `arm64` and `x86_64` in Release configuration. Building an architecture is not the same as running the UI on that hardware. Download `macos-test-results` from the workflow run to inspect the `.xcresult` and logs in Xcode.

## Manual checks before a release

This is a checklist to run, not a record of checks already completed. Record the commit, macOS version, hardware, Xcode version, display layout/scaling, and pass/fail observations with a release or pull request.

For a faster local pass, use Settings to choose a two-minute work session, 10-second break, one-minute blink and posture intervals, and a five-second warning. Leave reminder display time at two seconds. Both reminders should appear together after one minute. The **+ 5 Minutes** action still adds a real five minutes. Restore your preferred settings afterward; no source changes or rebuild are needed.

### Settings

- [ ] Open **Settings…** from the menu bar. One usable window opens, and repeated commands preserve unsaved edits rather than creating duplicates. Command-comma works while LookAway is active.
- [ ] Change every numeric control. Units are clear and values remain within bounds. Reducing work to one minute clamps the warning below 60 seconds.
- [ ] Change values and use **Cancel**, Escape, or the window close button. Reopen: saved preferences and the running schedule are unchanged.
- [ ] Save custom values, quit, and relaunch. Values and toggles persist, and the new work session starts with the saved interval.
- [ ] Disable blink, posture, and warnings separately and together. Disabled reminders do not appear; breaks still occur. Reenabling retains the selected intervals.
- [ ] Save timing changes while paused. The timer stays paused with the new full interval; resuming uses the new reminder intervals.
- [ ] Save timing changes while a warning/reminder is visible. The old presentation disappears and cannot affect the new session.
- [ ] Keep Settings open until a break starts. The break completes normally; saving afterward uses the selected values. Settings cannot open over an active break from the menu.
- [ ] Hide/show the menu-bar countdown. The timer does not restart; the icon stays clickable and its tooltip/accessibility label reports the timer state.
- [ ] **Restore Defaults** does not apply until **Save**. Canceling a reset preserves custom values; saving a reset restores the documented defaults.
- [ ] Resize the settings window; all controls and footer buttons remain reachable. Test light/dark appearance, keyboard navigation, and VoiceOver labels.

### Work, pause, and sleep

- [ ] On launch, the menu-bar countdown starts at the configured work interval, without an extra ten seconds or a negative countdown.
- [ ] Keep the menu open for several seconds. The countdown continues, and a due break is not deferred until the menu closes.
- [ ] Pause during work. The remaining time freezes, any warning/reminder disappears, and no reminders arrive while paused. Resume preserves the remaining work and reminder time.
- [ ] Sleep during work, then wake. Remaining work time is preserved; overdue reminders do not arrive in a burst.
- [ ] Sleep while manually paused. The app is still paused after waking.
- [ ] Sleep during a break. The overlay is gone on wake and a fresh work session begins.
- [ ] Quit while a warning or overlay is visible. All LookAway windows disappear and do not return. Relaunch starts a fresh work session with saved preferences.

### Warnings and scheduling

- [ ] A warning appears at the warning threshold. **I Know**, **X**, and the ten-second timeout leave the break deadline unchanged.
- [ ] **Skip Break** dismisses every copy of the warning. The current countdown continues; at zero it starts a full work session without showing a break. The following scheduled break still occurs.
- [ ] **+ 5 Minutes** extends the existing deadline by exactly five minutes, dismisses the warning, and rearms the warning for the configured warning interval before the new deadline.
- [ ] A warning disappears when a manual break starts, the app pauses, or the Mac sleeps. It must not act on the later session.
- [ ] After choosing **Skip Break**, choose **Start Break Now**. The manual break must start; the old skip must not suppress the next scheduled break.
- [ ] Start a break while paused. After completion, a new work session starts running, as documented.

### Break and reminder lifecycle

- [ ] Blink and posture reminders show the appropriate text. When due together, both messages appear in one overlay rather than one replacing the other.
- [ ] A reminder that is already visible is replaced cleanly by a due or manual break. It must not later close the break.
- [ ] No reminder replaces or interrupts an active break. **Start Break Now** and **Pause Timer** are unavailable during the break.
- [ ] **I'm ready** is disabled for the first three seconds on all displays. It becomes available at the same time everywhere.
- [ ] Early dismissal and automatic completion each remove all overlays and start exactly one fresh work session. Rapid repeated clicks must not restart that new session.
- [ ] The break countdown and the menu-bar break time agree. Display changes do not reset either countdown or the ready-button delay.

### Focus and interaction

- [ ] Type in another application when a warning appears. LookAway does not activate and typing stays in that application. Repeat for both kinds of reminder and a scheduled break. Opening Settings intentionally activates LookAway.
- [ ] Click **I Know**, **Skip Break**, and **+ 5 Minutes** separately. Each action works on its first click and the foreground application is not unexpectedly activated or deactivated afterward.
- [ ] Click **I'm ready** during a break. The action works without bringing up a normal LookAway application window.
- [ ] During a brief reminder, mouse clicks pass to the underlying application. During a break, its visible controls receive mouse input.
- [ ] Do not treat a break as a keyboard lock: keyboard focus and system shortcuts are intentionally not comprehensively blocked.

### Displays, Spaces, and accessibility

- [ ] Test a single display, then an external display positioned to the left, right, and above the primary display. Warning banners stay near the top center of each display's usable area.
- [ ] Break overlays cover each display and show the same time, including with different scaling and display sizes.
- [ ] Dismiss a warning or break on a secondary display. All other copies disappear, and the action happens once.
- [ ] Disconnect and reconnect a display during a break. The remaining countdown continues rather than restarting. No invisible window intercepts input on the remaining display.
- [ ] Change resolution or display arrangement while a warning is visible. The warning is dismissed and cannot affect the next session.
- [ ] Exercise multiple Spaces and a full-screen foreground application. Record any platform-specific visibility or focus differences.
- [ ] Enable Reduce Motion and confirm the warning/break fades are suppressed. Use VoiceOver to check the countdown and button labels; verify the controls remain usable with your keyboard-navigation settings.

Restore your preferred settings after this pass. Keep unverified manual checks unchecked.
