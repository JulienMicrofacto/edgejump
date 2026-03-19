# ScreenBridge

A macOS menu bar app that teleports the cursor between the inner edges of two external monitors, bridging only the top portion of the screen (the bottom portion lets macOS handle the transition to a central screen).

## Use case

3-screen setup: 2 large monitors (left/right) + MacBook centered below.

```
┌──────────┐┌──────────┐
│   Left   ││  Right   │
│          ││          │
└────┬─────┘└─────┬────┘
     │ ┌────────┐ │
     └─│MacBook │─┘
       └────────┘
```

In macOS Display Settings, the two large monitors are placed side by side. The MacBook is placed below, between them. The problem: the top half of the monitors has nothing physically between them, but macOS can't route the cursor to two different destinations depending on the vertical position.

ScreenBridge solves this:
- **Top zone**: cursor hits the inner edge → teleports directly to the other large monitor
- **Bottom zone**: macOS handles it normally (transition to the MacBook)

## Requirements

- macOS 13+
- Accessibility permission (prompted on first launch)

## Build

```bash
cd ScreenBridge
make
```

Produces `build/ScreenBridge.app`.

## Run

```bash
make run
# or
open build/ScreenBridge.app
```

On first launch, grant Accessibility access in:
**System Settings → Privacy & Security → Accessibility**

## Install

```bash
cp -R build/ScreenBridge.app /Applications/
```

To launch at login:
**System Settings → General → Login Items → add ScreenBridge**

## Configuration

The menu bar dropdown includes a slider to adjust the bridge zone ratio (10% to 90%, default 50%).

- **High ratio** (e.g. 70%): teleportation covers most of the screen height
- **Low ratio** (e.g. 30%): only the very top teleports, the rest goes through the MacBook

The setting is persisted via `UserDefaults`.

## How it works

- Menu bar icon: ↔ (`arrow.left.arrow.right`)
- Menu: status, ratio slider, Quit
- Automatic screen detection via `NSScreen.screens`
- Cursor monitoring via `CGEventTap`
- Teleportation via `CGWarpMouseCursorPosition`
- 0.3s cooldown to prevent loops
- 6px edge detection zone
- Logs in `/tmp/screenbridge.log`

## Project structure

```
ScreenBridge/
├── Makefile
├── LICENSE
├── .gitignore
└── ScreenBridge/
    ├── main.swift          # Entry point
    ├── AppDelegate.swift   # Main logic
    └── Info.plist          # LSUIElement=true (no Dock icon)
```

## Limitations

- Designed for the 3-screen setup described above
- Requires the two large monitors to be the leftmost and rightmost in macOS display arrangement

## License

MIT
