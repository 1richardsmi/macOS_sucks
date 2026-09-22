# macOS_sucks

**English** | [Русский](README.ru.md)

Every September Apple ships a fresh pile. On macOS that is the “reimagined” System Settings, where turning off the trackpad takes three prayers and a toggle hidden behind a toggle. On iOS it is the same phone, except Back moved again, the battery dies faster, and Dynamic Island is *even rounder*. Apple will call this innovation.

Then they sell an $80 case so the aluminum that was not supposed to scratch does not scratch, because *premium*. Then they ship a new major version, and Finder still cannot create a text file from a right-click on empty space. Twenty. Fourth. Year. Running. The keynote had a slide about it, surely.

Apple asks for “Allow Tracking” fourteen times a day and writes that it is “for your safety”. Yes. Shareholder safety. Meanwhile Siri still pretends it did not hear the question, and Calculator moved again so tipping without a subscription is a scavenger hunt. Very 2026.

Apple sells “the ecosystem.” The ecosystem is when one device cannot do what the other does unless you buy a $70 cable, and AirDrop cannot see the Mac on the next pillow. Pinch two fingers at the wrong angle and the window flies into Mission Control. That is a feature. That is the vision.

And the important part: Apple will say this is how it should be. That it is “by design.” The pilgrimage through SIP, Gatekeeper, “allow Accessibility”, “allow Input Monitoring”, “allow the Finder extension”, “no, not that AutoText, this one, minus then plus” — that *is* it just works.

Their public API is a museum. Finder Sync still talks like 2015. Half the menus are private. The other half are documented as three kinds that do not match what you see on screen. WWDC says “extensible.” The slide is lying. SwiftUI is for Settings windows they redesigned twice and still cannot search. The actual plugin is AppKit, `pluginkit`, a binary Automator plist from 2005, and a sheet called `showExtensionManagementInterface()` that opens a dialog from another decade. System Settings hide the toggle behind Extensions, or Added Extensions, or Login Items — pick a hallway, they all look the same and none of them are labeled.

The UI is the same joke. A toggle behind a toggle. A toolbar from 2003 with a new SF Symbol glued on. Five places that look like “actions” and share nothing: not items, not the current folder, not a century. That is not a design language. That is a company that shipped the aluminum and forgot the methods.

This app exists because “it just works” cannot make an empty `.txt` in the current folder, cannot swipe two fingers without seven privacy checkboxes, and still thinks a mouse wheel is a rumor. The name is honest.

---

A menu-bar utility: text macros on a global hotkey, a clipboard macro, two-finger swipes, a three-finger click as the middle mouse button (yes, the one Apple never shipped), and Finder items for **New Text Document**, **Open Terminal Here**, and **Copy Path** — including a right-click on empty space.

The interface can be **Russian or English**. In the app sidebar, under Language, pick System, Русский, or English. It opens at login by default; turn that off under **Startup** if you want.

## What it does

- Global macros: record a shortcut, and prepared text is typed into any field.
- Built-in **Clipboard** macro: the shortcut types the current clipboard as keystrokes, not ⌘V. If the clipboard is an image, a file, or empty, nothing happens. The item cannot be deleted, only turned off.
- If the layout is Russian and the text has Latin letters, the layout is switched to English for the duration and then restored.
- Two-finger swipe left/right in selected apps (Finder and System Settings by default) = ⌘] / ⌘[.
- Three-finger click (a normal press, not Force Click) = middle mouse button, in every app. Useful in Chrome and Firefox: a link opens in a new tab, a tab closes. Safari often ignores the middle button. Turn it off under **Gestures → Three-finger click** if you want stock behavior back.
- In Finder’s context menu: **New Text Document**. On a folder it expands in the same window and the file appears inside.
- On a Finder right-click (empty space or a file/folder): **Open Terminal Here** and **Copy Path**. Toggle them under **Finder → Path and Terminal**.
- Starts at login after a reboot. The toggle is **Startup → Open at login**. A login launch stays in the menu bar and does not pop the settings window.

## Requirements

- macOS 14 or later
- Apple Silicon (`arm64`)

## Install the ready build

No Xcode. No `make`. Just the zip from [Releases](https://github.com/1richardsmi/macOS_sucks/releases/latest).

1. Download `macOS_sucks-1.3-arm64.zip`.
2. Unzip it.
3. Drag `macOS_sucks.app` into `~/Applications` (or `/Applications`).
4. Right-click the app → **Open**. Gatekeeper will complain: the signature is homemade, not from the App Store. Click **Open** anyway. A double-click is often not enough the first time.
5. Then grant the permissions below.

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

Signing uses a local self-signed certificate (files under `.certs/`, not in git). Because of that, macOS treats each build as its own: after a path or certificate change you may have to grant access in Settings again.

## First launch: permissions

macOS will not send keys or gestures until the app is allowed in System Settings.

1. **Accessibility**  
   System Settings → Privacy & Security → Accessibility → enable `macOS_sucks`.  
   If the toggle already belongs to an old copy: “−”, then “+”, and pick the current `~/Applications/macOS_sucks.app`. Relaunch the app.

2. **Input Monitoring**  
   Needed for two-finger swipes and the three-finger middle click. Add `macOS_sucks` there too if a gesture does nothing.

3. **Finder extension**  
   In the app open **Finder** → **Open Finder extension settings** → enable **macOS_sucks Finder**.  
   After that you can turn the “New Text Document” item on and off inside the app.

4. If the system asks whether the app may control Finder — allow it. Otherwise the folder may not expand after the file is created.

## How to use

1. Add a macro, enter text, click **Record**, then press the shortcut (Control+Option+key is better than Command+Option).
2. Click the target field, press the shortcut, and release the keys. Typing starts only after modifiers are up.
3. **Clipboard**: assign a shortcut to the built-in Clipboard macro, copy text, then press it in the target field. Same keystroke typing as a regular macro.
4. Swipes: in **Two-finger swipe** keep Finder / Settings or add other apps.
5. Middle click: press the trackpad with three fingers — not a Force Click. Try it on a Chrome link. Disable under **Gestures → Three-finger click** to roll back.
6. Finder: right-click empty space or a folder → **New Text Document**.
7. Finder: right-click empty space or a file/folder → **Open Terminal Here** or **Copy Path**. Disable under **Finder → Path and Terminal**.
8. After a reboot the app should already be in the menu bar. If macOS asks about a new login item, allow it. To stop that: uncheck **Open at login**.

## Manual build

```bash
./scripts/build.sh
```

The bundle is `dist/macOS_sucks.app`. The same copy is installed to `~/Applications`.

## License

Do whatever you want.
