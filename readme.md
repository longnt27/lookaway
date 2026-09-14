# LookAway

LookAway is a native macOS menu-bar app that helps you take screen breaks and create lightweight recurring reminders without an account.

By default, LookAway schedules a **30-second break every 30 minutes** and starts with two editable reminders: **Blink** every 5 minutes and **Posture** every 10 minutes. They are ordinary reminders, so you can rename, reorder, disable, edit, or delete them and create as many others as you need.

## What it does

- Scheduled screen breaks with advance warnings, skip, and postpone controls
- Any number of recurring reminders with custom names, messages, and intervals
- Full-screen or compact reminder presentation
- Working-days and working-hours scheduling
- Display targeting for breaks and reminders
- Optional sounds for warnings, breaks, and reminders
- Configurable break screen with clock, countdown, dimming, text size, and preview
- Automatic update checks with one-click installation from the menu bar
- Native Apple Silicon and Intel support

## Install

Requires **macOS 15.4+**. Xcode is not required.

```sh
curl -fsSL https://raw.githubusercontent.com/longnt27/lookaway/main/install.sh | sh
```

The installer downloads the latest universal Apple Silicon/Intel release, verifies its SHA-256 checksum, installs LookAway to `~/Applications`, and opens it.

> LookAway is intentionally distributed without Apple notarization. macOS may show a security warning depending on your system settings.

## Everyday use

Click the menu-bar icon to:

- Start a break immediately
- Pause or resume the timer
- Open Settings
- Install an available update
- Quit LookAway

Before a scheduled break, the warning can let you skip that break or postpone it. During a break, **I'm ready** can finish the break early when early finishing is enabled. Work and reminder timers pause while your Mac sleeps and while LookAway is outside configured working hours.

## Reminders

Open **Settings > Reminders** to manage recurring reminders.

Use **Add Reminder** to open the creation sheet, enter a name and message, choose an interval, and add it to the list. Existing reminders are edited directly in their cards. Each card can be enabled or disabled, renamed, reordered with its drag handle, or deleted.

Blink and Posture are only the two initial defaults. They have no special runtime behavior and can be treated exactly like reminders you create yourself.

If several reminders become due together, LookAway combines them into one presentation instead of stacking multiple interruptions.

## Settings

LookAway has five settings tabs:

- **General**: launch behavior, menu-bar countdown, and working hours
- **Breaks**: work/break timing, advance warnings, skip/postpone behavior, and early finish
- **Reminders**: the reminder card list and Add Reminder action
- **Appearance**: app appearance, global reminder presentation, break-screen presentation, and preview
- **Sounds**: warning, break, and reminder sounds plus volume

Settings use Save/Cancel semantics. Reminder deletion and reordering only modify the draft until you press **Save**. Launch at login is managed directly by macOS and is the exception to that draft behavior.

## Updates

LookAway checks GitHub Releases for updates shortly after launch, every 30 minutes while running, and after your Mac wakes.

The menu-bar item reports the current state, for example:

- `Update to version x.x.x`
- `App is up to date`
- `Checking for updates…`

LookAway does **not** silently install a discovered update. When an update is available, choose **Update to version x.x.x** from the menu. LookAway downloads the release, verifies its SHA-256 checksum and bundle metadata, replaces the installed app, and relaunches it. After a successful relaunch, a popover from the menu-bar icon confirms the version now running.

Updates cannot install during an active break.

## Privacy and scope

LookAway stores preferences locally in macOS `UserDefaults`. It does not require an account, camera, microphone, Accessibility permission, or Screen Recording permission.

The app contacts GitHub to check for and download releases. Reminder content stays local to the Mac.

LookAway is a reminder and break-timing utility, not a device lock or medical application.

## Support and development

- [Report an issue](https://github.com/longnt27/lookaway/issues)
- [Developer guide](docs/development.md)
- [Testing guide](docs/testing.md)

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.
