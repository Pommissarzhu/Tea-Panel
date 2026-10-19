import AppKit
import SwiftUI

@main
enum TeaMotionTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        func advance(_ seconds: TimeInterval) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }

        // A panel may already have been ordered in by activation before its first animated show.
        for style in [TeaPanelMotion.Style.menu, .reminder] {
            for previsible in [false, true] {
                let frame = NSRect(x: -10000, y: -10000, width: 384, height: 300)
                let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                panel.animationBehavior = .none
                panel.hasShadow = false
                let motion = TeaPanelMotion(panel: panel, style: style, reduceMotion: { false })
                if previsible { panel.orderFrontRegardless() }
                motion.show(at: frame)
                advance(0.055)
                check(panel.alphaValue > 0 && panel.alphaValue < 0.98,
                      "An entrance must fade through intermediate opacity even when already ordered in")
                advance(0.45)
                check(panel.isVisible && motion.isPresented && abs(panel.alphaValue - 1) < 0.01,
                      "Entrance should finish fully visible")
                check(abs(panel.frame.minY - frame.minY) < 1, "Entrance should finish at the anchor")
                motion.show(at: frame)
                check(panel.alphaValue > 0.99, "Repeated show must not restart a settled entrance")
                motion.hide()
                check(panel.ignoresMouseEvents && !motion.isPresented, "Outgoing panels must reject repeated actions")
                advance(0.04)
                motion.show(at: frame)
                advance(0.5)
                check(panel.isVisible && motion.isPresented && !panel.ignoresMouseEvents,
                      "A stale close completion must not hide a reopened panel")
                check(panel.alphaValue > 0.99 && abs(panel.frame.minY - frame.minY) < 1,
                      "Interrupted close should recover full opacity and the original anchor")
                motion.hide()
                motion.hide()
                advance(0.3)
                check(!panel.isVisible && !motion.isPresented, "Repeated dismissal should settle hidden")
                motion.show(at: frame)
                advance(0.02)
                motion.hide()
                advance(0.45)
                check(!panel.isVisible && !motion.isPresented, "Dismissal during entrance must remain hidden")
            }
        }

        // Inject the accessibility preference without changing the user's system settings.
        for style in [TeaPanelMotion.Style.menu, .reminder] {
            let frame = NSRect(x: -10000, y: -10000, width: 384, height: 300)
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            let motion = TeaPanelMotion(panel: panel, style: style, reduceMotion: { true })
            motion.show(at: frame)
            advance(0.04)
            check(panel.frame.origin == frame.origin, "Reduced-motion entrance must not translate")
            advance(0.16)
            check(panel.isVisible && panel.alphaValue > 0.99, "Reduced-motion fade should finish")
            motion.hide()
            advance(0.04)
            check(panel.frame.origin == frame.origin, "Reduced-motion exit must not translate")
            advance(0.16)
            check(!panel.isVisible, "Reduced-motion dismissal should finish")
        }

        let suite = "local.teapanel.motion-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TeaStore(defaults: defaults, now: { now })
        let delegate = TeaAppDelegate(store: store, opensOnLaunch: false)
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let menu = app.windows.compactMap { $0 as? TeaMenuPanel }.first!
        let button = delegate.statusButtonForTesting

        // Exercise the real status button target/action, including an unexpectedly visible panel.
        for previsible in [false, true] {
            if previsible { menu.orderFrontRegardless() }
            button.performClick(nil)
            advance(0.055)
            check(menu.alphaValue > 0 && menu.alphaValue < 0.98, "Status-button opening must animate")
            advance(0.45)
            let anchor = menu.frame.origin
            store.selectTea(.tieguanyin)
            advance(0.25)
            check(menu.frame.origin == anchor, "Changing tea must not move an open menu")
            store.selectTea(.gardenia)
            store.startNewRound()
            advance(0.25)
            check(menu.frame.origin == anchor, "Changing timer phase must not move an open menu")
            store.endRound()
            button.performClick(nil)
            advance(0.3)
            check(!menu.isVisible, "Status-button closing must finish hidden")
        }
        button.performClick(nil)
        advance(0.45)
        menu.cancelOperation(nil)
        advance(0.3)
        check(!menu.isVisible, "Esc must use the same dismissal lifecycle")
        button.performClick(nil)
        advance(0.45)
        delegate.applicationDidResignActive(Notification(name: NSApplication.didResignActiveNotification))
        advance(0.3)
        check(!menu.isVisible, "Switching apps must dismiss the menu")

        store.enterCustomMode()
        store.updateRecipe(for: store.tea) { $0.coolingSeconds = 1; $0.firstBrewSeconds = 1 }
        store.setConfigurationName("动效回归")
        check(store.saveConfiguration(), "Saving should work with the animated view attached")
        check(store.saveConfiguration(asNew: true), "Save-as-new should retain the original configuration")
        check(store.customConfigurations.count == 2, "Both saved configurations should remain")
        store.deleteSelectedConfiguration()
        check(store.customConfigurations.count == 1 && store.isCustomMode, "Delete should retain a draft")
        store.startNewRound()
        now.addTimeInterval(2)
        store.tick()
        advance(0.45)
        let reminder = app.windows.compactMap { $0 as? ReminderPanel }.first!
        check(store.phase == .waitingForLeaves && reminder.isVisible, "Cooling completion must show the real reminder")
        check(!reminder.canBecomeKey && !reminder.isKeyWindow, "A real reminder must not take keyboard focus")
        store.confirmLeaves()
        advance(0.3)
        check(store.phase == .brewing && !reminder.isVisible, "Confirming leaves must dismiss and start brewing")
        now.addTimeInterval(2)
        store.tick()
        advance(0.45)
        check(store.phase == .ready && reminder.isVisible, "Brewing completion must show tea-ready reminder")
        store.prepareRefill()
        advance(0.3)
        check(store.phase == .preparingRefill && !reminder.isVisible, "Preparing refill must dismiss the reminder")
        store.startRefill()
        check(store.phase == .cooling, "Refill should return to cooling")
        store.skipCooling()
        check(store.phase == .brewing && store.displayedInfusion == 2, "Skipping cooling must retain the refill number")
        store.endRound()
        store.previewReminder()
        advance(0.45)
        check(store.phase == .idle && reminder.isVisible, "Preview should animate without starting a timer")
        store.dismissReminder()
        advance(0.3)
        check(!reminder.isVisible && store.phase == .idle, "Preview confirmation must preserve idle state")
        check(menu.contentView?.fittingSize == NSSize(width: 384, height: 668), "Menu dimensions must remain fixed")
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        print("通过 \(checks) 项窗口动效与状态栏入口回归检查")
    }
}
