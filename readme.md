LookAway - Save your office life (MacOS)
---

# Introduction

This app was motivated from the LookAway app from Mystical Bits, LLC.
I found that app really helpful, but I was too broke for it, so I replicated
the core features into this app. It is recommended to use the official app
to support the authors, and for better compatibility and usage experience.

# Core futures

As introduced, this app replicated core futures from the LookAway app from
Mystical Bits, LLC. Those include:

1. Run a 30-minute timer, followed by a 30-second break, repeatedly
2. The break session blocks all interactions by creating an overlay on screen
3. User has the choice to skip break session after 3 seconds
4. Every 3 and 5 minutes, an overlay shows up to remind user to blink and adjust
posture, respectively
5. 1 minute before the start of the break session, there is a pop up showing to
let user add 5 minutes to current working session, or ignore the next break session.

# Installation

Open with XCode and compile an executable, then move it to Application

# Future work

The app currently has several bugs:

1. It takes away focus. Everytime it appears by any kind (popup, overlay),
the current app loses its focus, and user needs to click on it again, it's
kinda annoying
2. The ignoring next break session does not work.

However, due to the deprecation of my laptop, it's a nightmare to work with XCode,
so I will stop developing this until I get a new computer.
