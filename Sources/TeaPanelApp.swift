import AppKit
import SwiftUI
import Combine

final class TeaMenuPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() }
        else { orderOut(sender) }
    }
}

final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TeaAppDelegate: NSObject, NSApplicationDelegate {
    private let store: TeaStore
    private let opensOnLaunch: Bool
    private var statusItem: NSStatusItem!
    private let menuPanel = TeaMenuPanel(
        contentRect: NSRect(x: 0, y: 0, width: 384, height: 668),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    private lazy var menuMotion = TeaPanelMotion(panel: menuPanel, style: .menu)
    private var reminderPanel: ReminderPanel?
    private var reminderMotion: TeaPanelMotion?
    private var observation: AnyCancellable?
    private var reminderObservation: AnyCancellable?
    private var outsideClickMonitor: Any?
    private var clock: Timer?
    private var wakeObservation: NSObjectProtocol?
    private var lastStatusSymbol: String?
    private var isQuitting = false

    init(store: TeaStore = TeaStore(), opensOnLaunch: Bool = true) {
        self.store = store
        self.opensOnLaunch = opensOnLaunch
        super.init()
    }

    #if TEA_PANEL_TESTING
    var statusButtonForTesting: NSStatusBarButton { statusItem.button! }
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = TeaStyle.statusImage(for: store.displaySymbol)
            lastStatusSymbol = store.displaySymbol
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(toggleMenu)
            button.setAccessibilityLabel("Tea Panel 泡茶提醒")
        }

        menuPanel.isFloatingPanel = true
        menuPanel.hidesOnDeactivate = false
        menuPanel.animationBehavior = .none
        menuPanel.isReleasedWhenClosed = false
        menuPanel.level = .statusBar
        menuPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        menuPanel.backgroundColor = .clear
        menuPanel.isOpaque = false
        menuPanel.hasShadow = true
        menuPanel.onCancel = { [weak self] in self?.hideMenu() }
        menuPanel.setAccessibilityLabel("Tea Panel 泡茶面板")
        menuPanel.contentView = NSHostingView(rootView: TeaMenuView(
            store: store,
            onPrimary: { [weak self] in self?.performPrimary() },
            onSkipCooling: { [weak self] in self?.skipCooling() },
            onEnd: { [weak self] in self?.store.endRound() },
            onPreview: { [weak self] in
                self?.hideMenu()
                self?.store.previewReminder()
            },
            onQuit: { [weak self] in self?.quit() }
        ))
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // A status-button click belongs to toggleMenu; do not close on mouse-down
                // and then reopen on the button's mouse-up action.
                if self.statusButtonFrame?.contains(NSEvent.mouseLocation) == true { return }
                self.hideMenu()
            }
        }

        observation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }
        reminderObservation = store.$reminder.sink { [weak self] reminder in
            guard let self else { return }
            if let reminder { self.showReminder(reminder) }
            else { self.reminderMotion?.hide() }
        }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
        wakeObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.tick() }
        }
        updateStatus()
        if opensOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showMenu() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenu()
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
    }

    @objc private func toggleMenu() {
        if menuMotion.isPresented { hideMenu() }
        else { showMenu() }
    }

    private func showMenu() {
        guard let window = statusItem.button?.window, let anchor = statusButtonFrame,
              let screen = window.screen ?? NSScreen.main else { return }
        // Position only when opening. Status text and template changes cannot move an open panel.
        var frame = menuPanel.frame
        if !menuMotion.isPresented {
            let visibleFrame = screen.visibleFrame
            let size = menuPanel.frame.size
            let x = min(max(anchor.midX - size.width / 2, visibleFrame.minX + 8),
                        visibleFrame.maxX - size.width - 8)
            let y = max(visibleFrame.minY + 8,
                        min(anchor.minY, visibleFrame.maxY) - size.height - 8)
            frame.origin = NSPoint(x: x, y: y)
        }
        if !menuMotion.isPresented { menuMotion.show(at: frame) }
        else {
            NSApp.activate(ignoringOtherApps: true)
            menuPanel.makeKeyAndOrderFront(nil)
        }
    }

    private var statusButtonFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func hideMenu() {
        menuMotion.hide()
    }

    private func quit() {
        guard !isQuitting else { return }
        isQuitting = true
        menuMotion.hide()
        reminderMotion?.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { NSApp.terminate(nil) }
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }
        if lastStatusSymbol != store.displaySymbol {
            button.image = TeaStyle.statusImage(for: store.displaySymbol)
            lastStatusSymbol = store.displaySymbol
        }
        let title = store.statusText.isEmpty ? "" : " \(store.statusText)"
        if button.title != title {
            button.title = title
        }
        let toolTip = store.isActive
            ? "\(store.displayName) · 第 \(store.displayedInfusion) 泡 · \(store.statusText)"
            : "Tea Panel · \(store.displayName)"
        if button.toolTip != toolTip { button.toolTip = toolTip }
    }

    private func performPrimary() {
        switch store.phase {
        case .idle: store.startNewRound()
        case .waitingForLeaves: store.confirmLeaves()
        case .ready: store.prepareRefill()
        case .preparingRefill: store.startRefill()
        case .cooling: store.skipCooling()
        case .brewing: break
        }
        if store.phase == .cooling || store.phase == .brewing { hideMenu() }
    }

    private func skipCooling() {
        store.skipCooling()
        if store.phase == .brewing { hideMenu() }
    }

    private func showReminder(_ reminder: TeaReminder) {
        // Nonactivating panel: show the reminder without interrupting typing in another app.
        let panel = reminderPanel ?? ReminderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 330),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.setAccessibilityLabel("Tea Panel 泡茶到点提醒")

        let host = NSHostingView(rootView: TeaReminderView(
            reminder: reminder,
            onConfirm: { [weak self] in
                guard let self, self.store.reminder?.id == reminder.id else { return }
                if reminder.isPreview || reminder.kind == .teaReady { self.store.dismissReminder() }
                else { self.store.confirmLeaves() }
            },
            onEnd: { [weak self] in
                guard let self, self.store.reminder?.id == reminder.id else { return }
                self.store.endRound()
            }
        ))
        panel.contentView = host
        let height = max(300, ceil(host.fittingSize.height))
        var frame = NSRect(origin: panel.frame.origin, size: NSSize(width: 440, height: height))
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            frame.origin = NSPoint(x: visibleFrame.midX - 220,
                                   y: visibleFrame.maxY - height - 26)
        }
        reminderPanel = panel
        if reminderMotion == nil { reminderMotion = TeaPanelMotion(panel: panel, style: .reminder) }
        reminderMotion?.show(at: frame)
    }
}

#if !TEA_PANEL_TESTING
@main
enum TeaPanelMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = TeaAppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
#endif
