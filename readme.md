# LookAway

A native macOS menu-bar app for screen breaks, blink reminders, and posture checks.

By default, take a **30-second break every 30 minutes**, with blink reminders every **5 minutes** and posture reminders every **10 minutes**. No account or internet connection required.

## Install

Requires **macOS 15.4+** and **Xcode 16.4 or a compatible newer version**. Installation currently requires building from source; no prebuilt download is available.

1. Download this repository using **Code > Download ZIP**, extract it, and open `LookAway.xcodeproj` in Xcode.
2. Select the **LookAway** scheme and **My Mac**. Under the app target's **Signing & Capabilities**, choose **Sign to Run Locally** or your development team.
3. Choose **Product > Run**. LookAway appears in your menu bar, not the Dock.

To install outside Xcode, right-click **Products > LookAway.app**, choose **Show in Finder**, and copy the app to **Applications**.

## Use

Click the menu-bar icon to start a break, pause or resume the timer, open settings, or quit.

Before a break, the warning lets you skip or postpone it. During a break, **I'm ready** lets you finish early. These controls are configurable. Timers pause while your Mac sleeps; reopening the app starts a fresh session.

## Make it yours

Open **Settings…** to choose timing presets, working days and hours, custom messages, displays, compact or full-screen reminders, sounds, and startup behavior. Adjust the break screen's clock, countdown, dimming, and text size with a built-in preview.

**Save** keeps your preferences; **Cancel** discards edits. Timing changes start a fresh work session without unpausing a manually paused timer or interrupting an active break. Launch at login is managed separately by macOS and takes effect immediately.

## Support

[Report an issue](https://github.com/longnt27/lookaway/issues) · [Developer guide](docs/development.md)

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.
