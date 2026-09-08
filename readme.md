# LookAway

A native macOS menu-bar app for screen breaks, blink reminders, and posture checks.

By default, take a **30-second break every 30 minutes**, with blink reminders every **5 minutes** and posture reminders every **10 minutes**. Breaks appear across connected displays. No account or internet connection required.

## Install

Requires **macOS 15.4+** and **Xcode 16.4 or a compatible newer version**. Installation currently requires building from source; no prebuilt download is available.

1. Download this repository using **Code > Download ZIP**, extract it, and open `LookAway.xcodeproj` in Xcode.
2. Select the **LookAway** scheme and **My Mac**. Under the app target's **Signing & Capabilities**, choose **Sign to Run Locally** or your development team.
3. Choose **Product > Run**. LookAway appears in your menu bar, not the Dock.

To install outside Xcode, right-click **Products > LookAway.app**, choose **Show in Finder**, and copy the app to **Applications**.

## Use

Click the menu-bar icon to **Start Break Now**, **Pause Timer**, **Resume Timer**, or **Quit LookAway**.

Before a scheduled break, choose **Skip Break** to skip just the next break, or **+ 5 Minutes** to postpone it. During a break, **I'm ready** lets you finish early after three seconds.

Timers pause while your Mac sleeps. Reopening the app starts a fresh session.

## Settings

Open **Settings…** from the menu bar to adjust break timing, turn blink/posture reminders and warnings on or off, and show or hide the countdown. Choose **Save** to keep your preferences between launches, or **Restore Defaults** to reset them before saving.

Saving timing changes starts a fresh work session; a paused timer stays paused. An active break finishes normally.

## Support

[Report an issue](https://github.com/longnt27/lookaway/issues) · [Developer guide](docs/development.md)

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.
