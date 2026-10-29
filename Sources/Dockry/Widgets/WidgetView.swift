import DockryCore
import SwiftUI

/// A widget Dockry can show: its description (name, icon, what it does, what it needs), its
/// view in the dock and, if it has any, its own settings. Each widget lives in its own folder
/// next to this file and adds itself to `DockWidget.all`.
struct DockWidget {
    let info: WidgetInfo
    /// The widget in the dock. It reads `\.dockMetrics` for its size and orientation.
    let makeView: @MainActor () -> AnyView
    /// Shown under the widget in Settings › Widgets.
    var makeSettings: (@MainActor () -> AnyView)?

    var kind: WidgetKind { info.kind }

    /// Every widget, in the order Settings lists them.
    @MainActor static let all: [DockWidget] = WidgetCatalog.all.map { widget(for: $0.kind) }

    @MainActor static func widget(for kind: WidgetKind) -> DockWidget {
        switch kind {
        case .clock: ClockWidget.widget
        case .date: DateWidget.widget
        case .spotify: SpotifyWidget.widget
        case .users: UsersWidget.widget
        case .claude: ClaudeUsageWidget.widget
        case .weather: WeatherWidget.widget
        }
    }
}

/// One of the profile's widgets, in the dock.
struct WidgetView: View {
    let kind: WidgetKind

    var body: some View {
        DockWidget.widget(for: kind).makeView()
    }
}

/// The rounded tile widgets sit on.
private struct WidgetTile: ViewModifier {
    @Environment(\.dockMetrics) private var metrics

    func body(content: Content) -> some View {
        content.background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
    }
}

extension View {
    func widgetTile() -> some View { modifier(WidgetTile()) }
}

/// A widget's icon: its app's icon when that app is installed, else its symbol on a tile of
/// its color, like an app icon. For Settings and the profile editor.
struct WidgetIcon: View {
    let info: WidgetInfo
    var size: CGFloat = 22

    var body: some View {
        if let id = info.appBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            symbolTile
        }
    }

    private var symbolTile: some View {
        Image(systemName: info.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background((Color(hex: info.tint) ?? .gray).gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}
