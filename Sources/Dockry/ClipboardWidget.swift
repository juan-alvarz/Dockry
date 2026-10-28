import AppKit
import DockryCore
import SwiftUI

/// A clipboard tile in the dock; clicking it (or ⌃⌥V) shows the copy history next to it.
struct ClipboardWidget: View {
    @ObservedObject private var monitor = ClipboardMonitor.shared
    @Environment(\.dockMetrics) private var metrics
    @State private var isShown = false
    @State private var window: NSWindow?

    var body: some View {
        Button { monitor.isShowingHistory.toggle() } label: {
            Image(systemName: "list.clipboard")
                .font(.system(size: 20 * metrics.unit))
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clipboard History (⌃⌥V)")
        .background(WindowReader { window = $0 })
        .dockPopover(isPresented: $isShown) { ClipboardHistoryList(monitor: monitor) }
        // With a dock on every screen, the history opens on the screen the pointer is on.
        .onChange(of: monitor.isShowingHistory) { _, isShowing in
            isShown = isShowing && isOnPointerScreen
        }
        .onChange(of: isShown) { _, isShown in
            if !isShown {
                monitor.isShowingHistory = false
            }
        }
        .onAppear { monitor.widgetAppeared() }
        .onDisappear { monitor.widgetDisappeared() }
    }

    private var isOnPointerScreen: Bool {
        let docks = NSApp.windows.filter { $0 is DockPanel && $0.isVisible }
        return docks.count <= 1 || window?.screen?.frame.contains(NSEvent.mouseLocation) == true
    }
}

/// Hands over the window a view is in.
private struct WindowReader: NSViewRepresentable {
    let found: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { found(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

private struct ClipboardHistoryList: View {
    @ObservedObject var monitor: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                Spacer()
                Button("Clear") { monitor.clear() }
                    .disabled(monitor.history.items.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()
            if monitor.history.items.isEmpty {
                Text("Text you copy shows up here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(monitor.history.items, id: \.self) { text in
                            ClipboardRow(text: text) { monitor.copy(text) }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 320)
    }
}

private struct ClipboardRow: View {
    let text: String
    let copy: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: copy) {
            Text(ClipboardHistory.preview(of: text))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Copy")
    }
}
