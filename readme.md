# LookAway

A native macOS menu-bar app for screen breaks, blink reminders, and posture checks.

By default, take a **30-second break every 30 minutes**, with blink reminders every **5 minutes** and posture reminders every **10 minutes**. No account required.

## Install

Requires **macOS 15.4+**. No Xcode required.

```sh
curl -fsSL https://raw.githubusercontent.com/longnt27/lookaway/main/install.sh | sh
```

The installer downloads the latest universal Apple Silicon/Intel release, verifies its SHA-256 checksum, installs it to `~/Applications`, and opens LookAway. Future updates are downloaded and installed automatically from GitHub Releases.

> LookAway is intentionally distributed without Apple notarization. macOS may show a security warning depending on your system settings.

## Use

Click the menu-bar icon to start a break, pause or resume the timer, open settings, check for updates, or quit.

Before a break, the warning lets you skip or postpone it. During a break, **I'm ready** lets you finish early. Timers pause while your Mac sleeps.

## Make it yours

Open **Settings…** to choose timing presets, working days and hours, custom messages, displays, compact or full-screen reminders, sounds, and startup behavior. Adjust the break screen's clock, countdown, dimming, and text size with a built-in preview.

## Support

[Report an issue](https://github.com/longnt27/lookaway/issues) · [Developer guide](docs/development.md)

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.
