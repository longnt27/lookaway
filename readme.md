<div align="center">

# 🌌 LookAway

### Your screen has had enough of you. Your eyes have had enough of your screen.

**A native macOS intervention against the slow conversion of human beings into desk-shaped organisms.**

![macOS](https://img.shields.io/badge/macOS-15.4%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-native-orange?logo=swift)
![Universal](https://img.shields.io/badge/Universal-Apple%20Silicon%20%2B%20Intel-blueviolet)
![Local First](https://img.shields.io/badge/data-local%20first-success)
![Account](https://img.shields.io/badge/account-not%20required-brightgreen)

**Break the cycle. Blink on purpose. Stand up before your spine files a formal complaint.**

</div>

---

## 🧠 The problem, unfortunately

Modern computing is magnificent.

We have instant access to nearly every piece of recorded human knowledge, global communication, absurd amounts of compute, real-time collaboration, and the ability to spend four uninterrupted hours staring at a pull request because one padding value feels spiritually incorrect.

The machine got better.

The human body did not receive a corresponding firmware update.

Your eyes still dry out. Your shoulders still crawl toward your ears. Your neck still bends. Time still disappears when a glowing rectangle gives you an endless sequence of things that feel *just important enough* to postpone standing up for another ten minutes.

Then another ten.

Then you look outside and somehow it is dark.

**LookAway exists to interrupt that trajectory.**

Not with accounts. Not with dashboards. Not with streaks, leaderboards, engagement loops, biometric surveillance, cloud synchronization, or a cheerful mascot congratulating you for possessing eyelids.

It does one thing with unreasonable conviction:

> **It makes your Mac remind you that there is, in fact, a biological organism sitting in front of it.**

---

## 🌱 The grand vision

LookAway is a native macOS menu-bar app for structured screen breaks and recurring reminders.

That sentence is technically accurate and emotionally inadequate.

The actual idea is simpler:

**Your computer should occasionally defend you from your computer.**

By default, LookAway schedules a **30-second break every 30 minutes** and begins with two reminders:

- 👁️ **Blink** every 5 minutes
- 🧍 **Posture** every 10 minutes

These are not sacred system entities forged into the binary by ancient Apple engineers. They are ordinary reminders. Rename them. Reorder them. Disable them. Delete them. Replace them with:

- 💧 Drink water
- 🫁 Breathe
- 🧘 Unclench jaw
- 🪟 Look out the window
- 🦵 Stand up
- 🌿 Touch grass, if conditions permit
- ☕ Stop reheating the same coffee
- 🧠 Ask yourself why you have had the same terminal tab open since Tuesday

Create as many reminders as your increasingly negotiated relationship with modern knowledge work requires.

---

## ⚡ What LookAway does

LookAway is intentionally small, but it is not timid.

### 🕰️ Structured breaks

Schedule recurring work sessions and breaks with:

- configurable work duration
- configurable break duration
- advance warnings
- a warning-time **Skip Break** action that immediately starts a fresh work interval
- postpone controls
- optional early finish once a break has actually begun

A break should be a break, not a hostage situation conducted by your own menu bar. The warning is where you negotiate with fate. Once the break starts, we stop putting an eject button next to the thing you just agreed to do.

### 🔔 Arbitrary recurring reminders

Reminders are first-class objects rather than two hardcoded exceptions pretending to be a feature.

Every reminder has its own:

- name
- message
- interval
- enabled state
- position in the reminder list

Create one. Create twenty. Delete Blink entirely and replace it with **"Stop leaning toward the screen like it owes you money"**. The scheduler does not care.

### 🖥️ Presentation that fits the interruption

Reminders can appear as:

- **full-screen overlays** when subtlety has failed
- **compact banners** when you still trust yourself to cooperate

You can choose which displays receive breaks and reminders, how long reminders stay visible, and where banner-style reminders appear.

### 🗓️ Working hours

LookAway can limit itself to selected days and working hours.

Because being reminded about posture at 2:14 AM while watching a movie would technically be consistent and socially deranged.

### 🔊 Sounds

Optional sounds can accompany:

- warnings
- breaks
- reminders

Volume is configurable. Silence remains a valid philosophical position.

### 🎨 A configurable break screen

Tune the break experience with:

- clock visibility
- countdown visibility
- dimming
- text size
- animations
- break messages
- preview

The point is not to build a meditation metaverse. The point is to make the interruption feel deliberate enough that you actually respect it.

### 🔄 Updates that do not require pilgrimage

LookAway checks GitHub Releases for updates and can install them from the menu bar.

When an update is available, the app tells you. It does **not** silently replace itself behind your back like a creature living in the walls.

---

## 🚀 Install

Requires **macOS 15.4+**.

Xcode is **not** required.

```sh
curl -fsSL https://raw.githubusercontent.com/longnt27/lookaway/main/install.sh | sh
```

The installer:

1. finds the latest LookAway release
2. downloads the universal build
3. verifies the SHA-256 checksum
4. installs LookAway to `~/Applications`
5. opens it

The release binary supports both:

- Apple Silicon (`arm64`)
- Intel (`x86_64`)

Because abandoning perfectly functional Macs merely because the silicon fashion cycle moved on would be extremely on-brand for the industry, and we decline to participate.

> [!WARNING]
> LookAway is intentionally distributed without Apple notarization. Depending on your macOS security settings, the system may show a warning on first launch.

---

## 🧭 Everyday use

LookAway lives in the macOS menu bar, where it can quietly supervise your descent into concentration.

Click the icon to:

- ▶️ start a break immediately
- ⏸️ pause the timer
- ▶️ resume the timer
- ⚙️ open Settings
- ⬆️ install an available update
- ⏻ quit LookAway

Before a scheduled break, the warning can allow you to:

- **Skip** the upcoming break, immediately starting a fresh work interval from that moment
- **Postpone** it

During an active break, if early finishing is enabled, you can finish early with **I'm ready** after the configured delay.

There is deliberately no **Skip Break** button once the break has started. At that point the negotiation window has closed. Thirty seconds of peace has been declared by treaty.

LookAway is meant to support your attention, not seize administrative control over your body.

When your Mac sleeps, work and reminder timers pause rather than building a bureaucratic backlog of missed eye blinks to prosecute when you wake up.

Outside configured working hours, the schedule pauses too.

---

## 🔔 Reminders: tiny interventions against entropy

Open **Settings → Reminders**.

At the top is **Add Reminder**.

Click it and a creation sheet appears with:

- Name
- Message
- Interval
- Enabled state

Existing reminders live as cards and can be edited directly.

Each reminder can be:

- ✅ enabled or disabled
- ✏️ renamed
- 💬 given a new message
- ⏱️ assigned a new interval
- ↕️ reordered
- 🗑️ deleted

The default Blink and Posture reminders are merely the first two citizens of the system. They receive no divine protection.

If several reminders become due together, LookAway combines their messages into one presentation instead of launching a synchronized assault of stacked interruptions.

Civilization survives another minute.

---

## ⚙️ Settings without the control-panel archaeological dig

LookAway has **five** settings tabs.

### ⚙️ General

- launch at login
- start with timer paused
- menu-bar countdown options
- working days
- working hours

### ☕ Breaks

- work duration
- break duration
- warning timing
- warning-time skip behavior
- postpone behavior
- early finish behavior

### 🔔 Reminders

- reminder cards
- Add Reminder
- enable / disable
- rename
- edit message
- edit interval
- reorder
- delete

### 🎨 Appearance

- app appearance
- reminder style
- reminder displays
- reminder duration
- banner position
- break displays
- break-screen options
- preview

### 🔊 Sounds

- warning sound
- break sound
- reminder sound
- sound choice
- volume

The window uses a compact aligned grid rather than stretching controls across empty space simply because SwiftUI discovered there were pixels available and developed ambitions.

Settings use **Save / Cancel** semantics.

That means reminder edits, deletions, and reordering remain in the draft until you press **Save**.

Launch-at-login is the exception because macOS owns that registration directly. Operating systems do enjoy reminding application developers who actually owns the machine.

---

## 🌙 What happens during a break

When break time arrives, LookAway presents the break screen on your configured display or displays.

You can choose whether it shows:

- a clock
- a countdown
- a custom message
- dimming
- larger or smaller text
- animation

If early finishing is enabled, **I'm ready** becomes available after the configured delay.

That is the only early exit on the active break screen. **Skip Break** belongs to the warning before the break, where using it immediately begins a fresh full work interval.

This distinction matters because buttons should mean what their labels claim instead of participating in temporal bureaucracy.

Before the break:

> "Not this one. Start my next work interval now."

After the break begins:

> "I have actually taken enough of the break."

Software has now, after some negotiations, learned the difference.

---

## 🧩 Display behavior

Multiple monitors are supported.

Breaks and reminders can target different display selections, so the interruption appears where you actually need it instead of on a monitor currently displaying nothing but Slack, which arguably has suffered enough.

Reminder presentation can use either:

- full-screen mode
- compact banner mode

Banner placement is configurable.

---

## 🔄 Updates: the app can evolve without becoming a platform

LookAway checks GitHub Releases:

- shortly after launch
- every 30 minutes while running
- after your Mac wakes

The menu-bar item reports states such as:

- `Update to version x.x.x`
- `App is up to date`
- `Checking for updates…`

LookAway does **not** automatically install newly discovered updates.

When you choose the update action, LookAway:

1. downloads the release archive
2. verifies its SHA-256 checksum
3. verifies bundle metadata
4. replaces the installed application
5. relaunches itself
6. confirms the newly running version in a menu-bar popover

Updates are blocked during an active break.

There are limits even to progress.

---

## 🔐 Privacy: radical concept, your reminders stay on your computer

LookAway stores preferences locally in macOS `UserDefaults`.

It does **not** require:

- an account
- a login
- a cloud profile
- camera permission
- microphone permission
- Accessibility permission
- Screen Recording permission
- your birth date
- your productivity philosophy
- your employer's blessing
- a subscription tier called **Focus Ultra Max**

The app contacts GitHub only to check for and download releases.

Your reminder content stays on your Mac.

There is no analytics dashboard waiting somewhere to reveal that you dismissed **"Drink water"** seven times today.

We do not need that information.

Neither does civilization.

---

## 🧱 What LookAway deliberately is not

LookAway is **not**:

- a device lock
- a parental-control system
- a medical application
- an employee-monitoring tool
- a productivity surveillance suite
- a habit-tracking social network
- a gamified wellness funnel
- a replacement for sleep
- a substitute for medical advice
- a reason to buy a smart ring

It is a small utility built around a boring but apparently revolutionary idea:

> **People using computers are still people.**

---

## 🛠️ For developers

LookAway is a native macOS Swift app with a regression suite and GitHub Actions CI.

The project verifies both the test suite and a universal Release build before changes are considered healthy.

Useful documentation:

- 🧑‍💻 [Developer guide](docs/development.md)
- 🧪 [Testing guide](docs/testing.md)
- 🐛 [Report an issue](https://github.com/longnt27/lookaway/issues)

If you are changing scheduling behavior, reminder timing, overlay presentation, updater behavior, or Settings layout, add regression coverage.

Humans forget. Tests also forget, but only when we forget to write them.

---

## 🌍 The completely reasonable manifesto

There is an enormous amount of software designed to make you stay at the computer.

Notifications want you back.
Feeds want one more scroll.
Chats want one more reply.
Dashboards want one more glance.
Editors want one more change.
CI wants one more rerun.
Your browser has 43 tabs open and somehow every one of them has acquired constitutional rights.

LookAway is software pointed in the opposite direction.

It is a program whose highest aspiration is, periodically, to make itself irrelevant for thirty seconds.

To make you look across the room.

To blink.

To move your shoulders.

To remember there is depth beyond the focal plane of a laptop screen.

To stand up before standing up becomes an event requiring advance planning.

No billion-user growth target.
No engagement optimization.
No retention strategy.

If LookAway succeeds, you spend **less** time interacting with LookAway.

That is the product.

That is the business model.

There is no business model.

It is a menu-bar app telling you to go stare at a tree for half a minute.

Somehow, in 2026, this feels rebellious.

---

<div align="center">

## 👁️ Look away.

### The code will still be there when you get back.

*Probably with one more failing test, because the universe requires balance.*

</div>

---

An independent project inspired by LookAway from Mystical Bits, LLC. Not affiliated with or endorsed by the commercial app.