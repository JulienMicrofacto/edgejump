# ScreenBridge

macOS menu bar app in Swift. Teleports cursor between two external monitors when in the top portion of the inner edge.

## Build

```bash
cd ScreenBridge && make
```

No Xcode project, no SPM — just `swiftc` via the Makefile.

## Architecture

Single logic file: `ScreenBridge/AppDelegate.swift`.

- `setupEventTap()`: creates a `CGEventTap` to intercept mouse movements
- `handleMouseEvent()`: detects if cursor is at the inner edge of one of the two external screens, within the bridge zone (configurable via `bridgeRatio`) → teleports to the other screen
- `bridgeRatio`: configurable ratio (0.1-0.9, default 0.5), persisted in `UserDefaults`
- `cgRect(from:mainScreenHeight:)`: converts NSScreen coordinates (origin bottom-left) to CG coordinates (origin top-left)

## Coordinates

NSScreen uses Y=0 at bottom, CG uses Y=0 at top. Conversion: `mainScreenHeight - y - height`.

## Logs

Logs go to `/tmp/screenbridge.log`. Cursor position logged every 0.5s + teleportation events.

## Testing

No automated tests. To test manually: move cursor to inner edge of both large screens and verify teleportation in the top zone. Verify the bottom zone does not teleport.
