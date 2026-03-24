import Cocoa
import ApplicationServices

extension Double {
    func clamped(to range: ClosedRange<Double>, default d: Double) -> Double {
        self == 0 ? d : Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: CFMachPort?
    private var lastWarpTime: CFAbsoluteTime = 0
    private let warpCooldown: CFAbsoluteTime = 0.3
    private var logTimer: Timer?
    private var ratioLabel: NSMenuItem!

    private var bridgeRatio: Double {
        get { UserDefaults.standard.double(forKey: "bridgeRatio").clamped(to: 0.1...0.9, default: 0.5) }
        set {
            UserDefaults.standard.set(newValue, forKey: "bridgeRatio")
            updateRatioLabel()
        }
    }

    private func updateRatioLabel() {
        ratioLabel?.title = "Bridge zone: top \(Int(bridgeRatio * 100))%"
    }

    private let logFile: FileHandle? = {
        let path = "/tmp/screenbridge.log"
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }()

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(msg)\n"
        logFile?.write(line.data(using: .utf8)!)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            showAccessibilityAlert()
        }
        setupMenuBar()
        setupEventTap()

        // Log cursor position every 0.5s
        logTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            let pos = NSEvent.mouseLocation
            let screens = NSScreen.screens
            let mainHeight = screens.first(where: { $0.frame.origin == .zero })?.frame.height ?? 0
            let cgY = mainHeight - pos.y
            self?.log("CURSOR ns=(\(Int(pos.x)), \(Int(pos.y))) cg=(\(Int(pos.x)), \(Int(cgY)))")
        }
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "ScreenBridge needs Accessibility access to monitor and move the cursor."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "ScreenBridge")
        }
        let menu = NSMenu()

        let status = NSMenuItem(title: "ScreenBridge – Active", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        ratioLabel = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        ratioLabel.isEnabled = false
        updateRatioLabel()
        menu.addItem(ratioLabel)

        let slider = NSSlider(value: bridgeRatio, minValue: 0.1, maxValue: 0.9, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 18, y: 0, width: 180, height: 24)
        slider.isContinuous = true
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 216, height: 28))
        sliderView.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        bridgeRatio = sender.doubleValue
    }

    // MARK: - Event Tap

    private func setupEventTap() {
        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let self_ = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                self_.handleMouseEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            log("FAILED to create event tap - accessibility not granted?")
            return
        }

        log("Event tap created OK")

        // Log screen geometry
        let screens = NSScreen.screens
        let mainHeight = screens.first(where: { $0.frame.origin == .zero })?.frame.height ?? 0
        let sorted = screens.sorted { $0.frame.origin.x < $1.frame.origin.x }
        for s in sorted {
            let cg = cgRect(from: s.frame, mainScreenHeight: mainHeight)
            log("Screen '\(s.localizedName)': CG x=\(Int(cg.minX))→\(Int(cg.maxX)) y=\(Int(cg.minY))→\(Int(cg.maxY))")
        }
        let leftCG = cgRect(from: sorted.first!.frame, mainScreenHeight: mainHeight)
        let rightCG = cgRect(from: sorted.last!.frame, mainScreenHeight: mainHeight)
        log("Left inner edge: x=\(Int(leftCG.maxX)), Right inner edge: x=\(Int(rightCG.minX))")
        log("Left midY=\(Int((leftCG.minY + leftCG.maxY) / 2)), Right midY=\(Int((rightCG.minY + rightCG.maxY) / 2))")

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Teleportation

    private func handleMouseEvent(_ event: CGEvent) {
        let screens = NSScreen.screens
        guard screens.count >= 2 else { return }

        let mainHeight = screens.first(where: { $0.frame.origin == .zero })?.frame.height ?? screens[0].frame.height

        let sorted = screens.sorted { $0.frame.origin.x < $1.frame.origin.x }
        let left = sorted.first!
        let right = sorted.last!

        let leftCG = cgRect(from: left.frame, mainScreenHeight: mainHeight)
        let rightCG = cgRect(from: right.frame, mainScreenHeight: mainHeight)

        let pos = event.location

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastWarpTime > warpCooldown else { return }

        let edgeZone: CGFloat = 1

        let ratio = CGFloat(bridgeRatio)

        // Inner edge of left screen (right side)
        if pos.x >= leftCG.maxX - edgeZone && pos.x <= leftCG.maxX + edgeZone
            && pos.y >= leftCG.minY && pos.y <= leftCG.maxY {
            let splitY = leftCG.minY + leftCG.height * ratio
            let zone = pos.y < splitY ? "BRIDGE" : "PASS"
            log("EDGE-LEFT pos=(\(Int(pos.x)),\(Int(pos.y))) splitY=\(Int(splitY)) \(zone)")
            if pos.y < splitY {
                let relativeY = (pos.y - leftCG.minY) / (leftCG.height * ratio)
                let newY = rightCG.minY + relativeY * (rightCG.height * ratio)
                log("WARP → right (\(Int(rightCG.minX + 50)), \(Int(newY)))")
                lastWarpTime = now
                CGWarpMouseCursorPosition(CGPoint(x: rightCG.minX + 50, y: newY))
                return
            }
        }

        // Inner edge of right screen (left side)
        if pos.x >= rightCG.minX - edgeZone && pos.x <= rightCG.minX + edgeZone
            && pos.y >= rightCG.minY && pos.y <= rightCG.maxY {
            let splitY = rightCG.minY + rightCG.height * ratio
            let zone = pos.y < splitY ? "BRIDGE" : "PASS"
            log("EDGE-RIGHT pos=(\(Int(pos.x)),\(Int(pos.y))) splitY=\(Int(splitY)) \(zone)")
            if pos.y < splitY {
                let relativeY = (pos.y - rightCG.minY) / (rightCG.height * ratio)
                let newY = leftCG.minY + relativeY * (leftCG.height * ratio)
                log("WARP → left (\(Int(leftCG.maxX - 50)), \(Int(newY)))")
                lastWarpTime = now
                CGWarpMouseCursorPosition(CGPoint(x: leftCG.maxX - 50, y: newY))
                return
            }
        }
    }

    private func cgRect(from nsRect: NSRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: nsRect.origin.x,
            y: mainScreenHeight - nsRect.origin.y - nsRect.height,
            width: nsRect.width,
            height: nsRect.height
        )
    }
}
