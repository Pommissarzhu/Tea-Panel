import AppKit
import QuartzCore
import SwiftUI

// Use the property wrapper on SDKs that also export a State macro unavailable in Command Line Tools.
typealias TeaViewState<Value> = SwiftUI.State<Value>

enum TeaMotion {
    static let feedback = Animation.easeOut(duration: 0.12)
    static let selection = Animation.easeInOut(duration: 0.18)
    static let content = Animation.timingCurve(0.22, 0.8, 0.25, 1, duration: 0.24)

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6))
    }

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.1) : animation
    }
}

struct TeaValueChange: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    var numeric = false

    func body(content: Content) -> some View {
        content
            .contentTransition(numeric && !reduceMotion ? .numericText() : .opacity)
            .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: value)
    }
}

struct TeaHoverFeedback: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @TeaViewState private var isHovering = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(color.opacity(isEnabled && isHovering ? 0.4 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onHover { isHovering = $0 }
            .animation(TeaMotion.animation(TeaMotion.feedback, reduceMotion: reduceMotion), value: isHovering)
    }
}

struct TeaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(TeaButtonFeedback(isPressed: configuration.isPressed))
    }
}

private struct TeaButtonFeedback: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @TeaViewState private var isHovering = false
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isEnabled && isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled && isPressed ? 0.82 : 1)
            .brightness(isEnabled && isHovering ? 0.025 : 0)
            .animation(TeaMotion.animation(TeaMotion.feedback, reduceMotion: reduceMotion), value: isPressed)
            .animation(TeaMotion.animation(TeaMotion.feedback, reduceMotion: reduceMotion), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Owns visibility as well as animation so an interrupted dismissal cannot hide a reopened panel.
@MainActor
final class TeaPanelMotion {
    enum Style {
        case menu, reminder

        var entranceDuration: TimeInterval { self == .reminder ? 0.36 : 0.3 }
        var exitDuration: TimeInterval { self == .reminder ? 0.22 : 0.16 }
        var entranceOffset: CGFloat { self == .reminder ? -12 : 10 }
        var exitOffset: CGFloat { self == .reminder ? 6 : 4 }
    }

    private let panel: NSPanel
    private let style: Style
    private let reduceMotion: () -> Bool
    private var generation = 0
    private var isDismissing = false
    private(set) var isPresented = false

    init(panel: NSPanel, style: Style,
         reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.panel = panel
        self.style = style
        self.reduceMotion = reduceMotion
    }

    func show(at frame: NSRect) {
        // App activation can order a panel in before this method runs. Logical visibility,
        // rather than NSWindow.isVisible alone, determines whether to prepare an entrance.
        let continuesDismissal = isDismissing && panel.isVisible
        let startsEntrance = (!isPresented && !continuesDismissal) || !panel.isVisible
        generation += 1
        isPresented = true
        isDismissing = false
        panel.ignoresMouseEvents = false
        let reduceMotion = reduceMotion()
        if startsEntrance {
            panel.alphaValue = 0
            panel.setFrame(reduceMotion ? frame : frame.offsetBy(dx: 0, dy: style.entranceOffset), display: false)
        }
        if style == .menu {
            // Prepare opacity and position before activation can make the panel visible.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
        else { panel.orderFrontRegardless() }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.1 : style.entranceDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
    }

    func hide() {
        guard isPresented else { return }
        isPresented = false
        isDismissing = true
        generation += 1
        let dismissal = generation
        let frame = panel.frame
        let reduceMotion = reduceMotion()
        // The outgoing card must not accept a second confirmation during its fade.
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.1 : style.exitDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            if !reduceMotion {
                panel.animator().setFrame(frame.offsetBy(dx: 0, dy: style.exitOffset), display: true)
            }
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == dismissal, !self.isPresented else { return }
                self.isDismissing = false
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.panel.setFrame(frame, display: false)
            }
        })
    }
}
