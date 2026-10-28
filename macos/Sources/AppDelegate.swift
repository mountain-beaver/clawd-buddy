import AppKit
import Combine

private final class BuddyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Prefs.shared
    private var panel: BuddyPanel!
    private var view: BuddyView!
    private var brain: Brain!
    private var statusItem: NSStatusItem!
    private var settings: SettingsWindowController?
    private var timer: Timer?
    private var prefsSub: AnyCancellable?
    private var manuallyHidden = false

    private var panelSize: NSSize {
        let s = prefs.size.scale
        return NSSize(width: BuddyView.size.width * s, height: BuddyView.size.height * s)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        view = BuddyView(frame: NSRect(origin: .zero, size: BuddyView.size))
        brain = Brain(view: view, prefs: prefs)
        view.onPoke = { [weak self] in self?.brain.poked() }
        view.onDragStart = { [weak self] in self?.brain.dragStarted() }
        view.onDropped = { [weak self] in
            guard let self else { return }
            self.prefs.anchor = NSPoint(x: self.panel.frame.maxX, y: self.panel.frame.maxY)
            self.brain.dropped()
        }
        view.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }

        panel = BuddyPanel(contentRect: NSRect(origin: .zero, size: panelSize),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSView(frame: NSRect(origin: .zero, size: panelSize))
        panel.contentView?.addSubview(view)
        applyPrefs()
        placePanel()
        panel.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BuddyView.statusIcon()
        statusItem.menu = buildMenu()

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(onHookEvent(_:)), name: Bridge.notificationName,
            object: nil, suspensionBehavior: .deliverImmediately)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // @Published fires before the value lands, so apply on the next runloop turn.
        prefsSub = prefs.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.applyPrefs(); self?.refreshMenu() }
        }

        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        if let info = launchEvent() { brain.handle(info) } else { brain.greet() }
    }

    /// The hook launches the app with the event that woke it up, so that first event isn't lost.
    private func launchEvent() -> [String: String]? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--event"), i + 1 < args.count,
              let data = args[i + 1].data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
    }

    @objc private func onHookEvent(_ n: Notification) {
        guard let info = n.userInfo as? [String: String] else { return }
        brain.handle(info)
    }

    private func tick() {
        let local = view.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        view.mouse = local
        brain.tick()

        let target: CGFloat = (prefs.hideWhenSleeping && view.mood == .sleeping) ? 0 : 1
        if panel.alphaValue != target {
            panel.alphaValue += max(-0.05, min(0.05, target - panel.alphaValue))
        }

        // Click-through everywhere except the crab and its bubble.
        let interactive = view.isDragging || view.isInteractive(at: local)
        let ignore = !interactive || panel.alphaValue < 0.5
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }
    }

    private func applyPrefs() {
        view.style = prefs.bubbleStyle
        view.followMouse = prefs.followMouse

        let size = panelSize
        if panel.frame.size != size {
            let old = panel.frame
            let anchored = old.width > 0 && old.maxX > 0
            let origin = anchored ? NSPoint(x: old.maxX - size.width, y: old.maxY - size.height) : old.origin
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        view.setFrameSize(size)
        view.setBoundsSize(BuddyView.size)
        view.needsDisplay = true
    }

    // MARK: Placement

    private func defaultAnchor() -> NSPoint {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: vf.maxX - 6, y: vf.maxY - 2)
    }

    private func placePanel() {
        let size = panelSize
        var anchor = prefs.anchor ?? defaultAnchor()
        let frame = NSRect(x: anchor.x - size.width, y: anchor.y - size.height, width: size.width, height: size.height)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersection(frame).width > 100 }) {
            anchor = defaultAnchor()
            prefs.anchor = nil
        }
        panel.setFrameOrigin(NSPoint(x: anchor.x - size.width, y: anchor.y - size.height))
    }

    @objc private func screensChanged() { placePanel() }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let m = NSMenu()
        let title = NSMenuItem(title: "Clawd Buddy", action: nil, keyEquivalent: "")
        title.isEnabled = false
        m.addItem(title)
        m.addItem(.separator())

        let settingsItem = item(L10n.ui(.settings), #selector(openSettings))
        settingsItem.keyEquivalent = ","
        m.addItem(settingsItem)

        let langItem = NSMenuItem(title: L10n.ui(.language), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (lang, name) in [(Lang.en, "English"), (Lang.ru, "Русский")] {
            let it = item(name, #selector(setLanguage(_:)))
            it.representedObject = lang.rawValue
            it.state = prefs.lang == lang ? .on : .off
            sub.addItem(it)
        }
        langItem.submenu = sub
        m.addItem(langItem)

        let hide = item(L10n.ui(.hideWhenSleeping), #selector(toggleHideWhenSleeping))
        hide.state = prefs.hideWhenSleeping ? .on : .off
        m.addItem(hide)
        m.addItem(.separator())
        m.addItem(item(L10n.ui(.sayHi), #selector(sayHi)))
        m.addItem(item(L10n.ui(.playDemo), #selector(playDemo)))
        m.addItem(item(L10n.ui(manuallyHidden ? .show : .hide), #selector(toggleVisible)))
        m.addItem(item(L10n.ui(.resetPosition), #selector(resetPosition)))
        m.addItem(.separator())
        m.addItem(item(L10n.ui(.quit), #selector(quit)))
        return m
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    private func refreshMenu() { statusItem.menu = buildMenu() }

    @objc private func openSettings() {
        if settings == nil {
            settings = SettingsWindowController(prefs: prefs) { [weak self] in self?.playDemo() }
        }
        settings?.present()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let lang = Lang(rawValue: raw) else { return }
        prefs.lang = lang
        DispatchQueue.main.async { self.brain.greet() }
    }

    @objc private func toggleHideWhenSleeping() { prefs.hideWhenSleeping.toggle() }

    @objc private func toggleVisible() {
        manuallyHidden.toggle()
        if manuallyHidden { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        refreshMenu()
    }

    private func ensureVisible() { if manuallyHidden { toggleVisible() } }

    @objc private func sayHi() {
        ensureVisible()
        brain.greet()
    }

    @objc private func playDemo() {
        ensureVisible()
        brain.demo()
    }

    @objc private func resetPosition() {
        prefs.anchor = nil
        placePanel()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
