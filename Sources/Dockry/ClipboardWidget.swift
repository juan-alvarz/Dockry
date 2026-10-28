import DockryCore
import SwiftUI

/// A clipboard tile in the dock; clicking it (or ⌃⌥V) shows the copy history above it.
struct ClipboardWidget: View {
    @ObservedObject private var monitor = ClipboardMonitor.shared

    var body: some View {
        Button { monitor.isShowingHistory.toggle() } label: {
            Image(systemName: "list.clipboard")
                .font(.system(size: 20))
                .frame(width: 48, height: 48)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clipboard History (⌃⌥V)")
        .popover(isPresented: $monitor.isShowingHistory, arrowEdge: .top) {
            ClipboardHistoryList(monitor: monitor)
        }
    }
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
