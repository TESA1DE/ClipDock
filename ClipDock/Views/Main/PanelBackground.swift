import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

extension AppTint {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .graphite: return .gray
        }
    }
}

struct FrostedBackdrop: NSViewRepresentable {
    var radius: CGFloat
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.isEmphasized = false
        view.wantsLayer = true
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
    }
}

struct PanelBackground: View {
    var appearance: AppAppearance
    var tint: AppTint
    var radius: CGFloat = 18
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        switch appearance {
        case .light: shape.fill(Color.white)
        case .dark: shape.fill(Color(white: 0.10))
        case .transparent, .tinted:
            if reduceTransparency {
                shape.fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(shape.fill(appearance == .tinted ? tint.color.opacity(0.08) : .clear))
            } else {
                ZStack {
                    FrostedBackdrop(radius: radius)
                    shape.fill(colorScheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.16))
                    if appearance == .tinted {
                        shape.fill(tint.color.opacity(colorScheme == .dark ? 0.07 : 0.045))
                    }
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.16 : 0.55), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.75
                    )
                }.clipShape(shape)
            }
        case .system: shape.fill(.regularMaterial)
        }
    }
}
