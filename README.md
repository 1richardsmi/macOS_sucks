# macOS_sucks

**English** | [Русский](README.ru.md)

Every September Apple ships a fresh pile. On macOS that is the “reimagined” System Settings, where turning off the trackpad takes three prayers and a toggle hidden behind a toggle. On iOS it is the same phone, except Back moved again, the battery dies faster, and Dynamic Island is *even rounder*.

And people queue for it. Pay a kidney. Then post on Twitter (sorry, “X”, that is also progress): “actually, once you get used to it…” Yes. Like hemorrhoids. Then they buy an $80 case so they do not scratch the aluminum that was not supposed to scratch, because *premium*. Then they update to the new major version and discover Finder still cannot create a text file from a right-click on empty space. Twenty. Fourth. Year. Running.

iOS users happily tap “Allow Tracking” fourteen times a day and believe it is “for your safety”. Yes. Shareholder safety. Meanwhile Siri still pretends it did not hear you, and Calculator moved again so you cannot find how to tip without a subscription.

macOS users nod: “but the ecosystem.” The ecosystem is when one device cannot do what the other does unless you buy a $70 cable, and AirDrop cannot see the Mac on the next pillow. But if you pinch two fingers at the wrong angle the window flies into Mission Control and you feel stupid. That is a feature. You just failed to understand the vision.

And the important part: they like it. They tell themselves this is how it should be. That it is “by design.” That Windows is for poor people, Android is for taxi drivers, and the pilgrimage through SIP, Gatekeeper, “allow Accessibility”, “allow Input Monitoring”, “allow the Finder extension”, “no, not that AutoText, this one, minus then plus” — that *is* it just works.

This app exists because “it just works” cannot type real keystrokes into Horizon, cannot make an empty `.txt` in the current folder, and cannot swipe two fingers without seven privacy checkboxes. The name is honest. If you are offended, you recognized yourself. If you laugh, install it. If both — welcome, you are the target audience.

---

A menu-bar utility: text macros on a global hotkey, type-the-clipboard as keystrokes, two-finger swipes, and a Finder **New Text Document** item — including a right-click on empty space.

The macro is typed as real key down/up events, not ⌘V. That is how it reaches Omnissa Horizon Client. Yes, in 2026 a Mac needs a separate app for that. We are shocked too.

The interface can be **Russian or English**. In the app sidebar, under Language, pick System, Русский, or English. It opens at login by default; turn that off under **Startup** if you want.

## What it does

- Global macros: record a shortcut, and prepared text is typed into any field.
- Built-in **Clipboard** macro: the shortcut types the current clipboard as keystrokes, not ⌘V. If the clipboard is an image, a file, or empty, nothing happens. The item cannot be deleted, only turned off.
- If the layout is Russian and the text has Latin letters, the layout is switched to English for the duration and then restored. macOS itself, of course, never thought of this.
- Two-finger swipe left/right in selected apps (Finder and System Settings by default) = ⌘] / ⌘[.
- In Finder’s context menu: **New Text Document**. On a folder it expands in the same window and the file appears inside. Windows could do this while Jobs still wore a turtleneck.
- Starts at login after a reboot. The toggle is **Startup → Open at login**. A login launch stays in the menu bar and does not pop the settings window.

## Requirements

- macOS 14 or later
- Apple Silicon (`arm64`)

## Install the ready build

No Xcode. No `make`. Just the zip from [Releases](https://github.com/1richardsmi/macOS_sucks/releases/latest).

1. Download `macOS_sucks-1.1-arm64.zip`.
2. Unzip it.
3. Drag `macOS_sucks.app` into `~/Applications` (or `/Applications`).
4. Right-click the app → **Open**. Gatekeeper will complain: the signature is homemade, not from the App Store. Click **Open** anyway. A double-click is often not enough the first time.
5. Then do the permission dance below.

If macOS still refuses, in Terminal:

```bash
xattr -cr ~/Applications/macOS_sucks.app
```

Then right-click → Open again.

## Install from source

You also need [Xcode Command Line Tools](https://developer.apple.com/download/all/?q=command%20line%20tools).

```bash
xcode-select -p || xcode-select --install
```


```bash
git clone https://github.com/1richardsmi/macOS_sucks.git
cd macOS_sucks
make
```

`make` builds the app and copies it to `~/Applications/macOS_sucks.app`.

Launch right after the build:

```bash
make run
```

Or open `~/Applications/macOS_sucks.app` from Finder.

Signing uses a local self-signed certificate (files under `.certs/`, not in git). Because of that, macOS treats each build as “its own”: after a path or certificate change you may have to grant access in Settings again. *It just works*. Say it once more, maybe it helps.

## First launch: permissions

macOS will not send keys or gestures without a checkbox pilgrimage. This is not a bug, it is “privacy”: the system does not trust an app you just downloaded or built yourself.

1. **Accessibility**  
   System Settings → Privacy & Security → Accessibility → enable `macOS_sucks`.  
   If the toggle already belongs to an old copy: “−”, then “+”, and pick the current `~/Applications/macOS_sucks.app`. Relaunch the app.

2. **Input Monitoring**  
   Needed for two-finger swipes. Add `macOS_sucks` there too if the gesture does nothing.

3. **Finder extension**  
   In the app open **Finder** → **Open Finder extension settings** → enable **macOS_sucks Finder**.  
   After that you can turn the “New Text Document” item on and off inside the app.

4. If the system asks whether the app may control Finder — allow it. Otherwise the folder may not expand after the file is created. Fourth checkbox. Still here? Good, you are a real Apple user.

## How to use

1. Add a macro, enter text, click **Record**, then press the shortcut (Control+Option+key is better than Command+Option).
2. Click the target field, press the shortcut, and release the keys. Typing starts only after modifiers are up.
3. **Clipboard**: assign a shortcut to the built-in Clipboard macro, copy text, then press it in the target field. Same keystroke typing as a regular macro.
4. Swipes: in **Two-finger swipe** keep Finder / Settings or add other apps.
5. Finder: right-click empty space or a folder → **New Text Document**.
6. After a reboot the app should already be in the menu bar. If macOS asks about a new login item, allow it. To stop that: uncheck **Open at login**.

## Manual build

```bash
./scripts/build.sh
```

The bundle is `dist/macOS_sucks.app`. The same copy is installed to `~/Applications`.

## License

Do whatever you want. If you break your macOS — you saw the app name. If you break your self-esteem — the README did its job.
