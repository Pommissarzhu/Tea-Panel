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

        var entranceDuration: TimeInterval { self == .reminder ? 0.36 : 0.22 }
        var exitDuration: TimeInterval { self == .reminder ? 0.22 : 0.16 }
        var entranceOffset: CGFloat { self == .reminder ? -12 : 6 }
        var exitOffset: CGFloat { self == .reminder ? 6 : 4 }
    }

    private let panel: NSPanel
    private let style: Style
    private var generation = 0
    private(set) var isPresented = false

    init(panel: NSPanel, style: Style) {
        self.panel = panel
        self.style = style
    }

    func show(at frame: NSRect) {
        generation += 1
        isPresented = true
        panel.ignoresMouseEvents = false
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.setFrame(reduceMotion ? frame : frame.offsetBy(dx: 0, dy: style.entranceOffset), display: false)
        }
        if style == .menu { panel.makeKeyAndOrderFront(nil) }
        else { panel.orderFrontRegardless() }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.1 : style.entranceDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
    }

    func hide() {
        guard isPresented else { return }
        isPresented = false
        generation += 1
        let dismissal = generation
        let frame = panel.frame
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.panel.setFrame(frame, display: false)
            }
        })
    }
}
