import AppKit
import DockryCore
import SwiftUI

/// A folder in the dock, like the macOS Dock's stacks: the folder's icon, and clicking it
/// opens a grid of what's inside, newest first. Folders in the grid open in place; files open
/// in their apps.
struct FolderIconView: View {
    let path: String
    let isHovered: Bool
    let profileName: String
    let store: ProfileStore
    let itemIndex: Int

    @Environment(\.dockMetrics) private var metrics
    @State private var isOpen = false

    private var url: URL { URL(fileURLWithPath: path) }

    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(idealWidth: metrics.iconSize, idealHeight: metrics.iconSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(url.lastPathComponent)
        .overlay {
            if isHovered && !isOpen {
                NameLabel(name: FileManager.default.displayName(atPath: path), position: metrics.position)
            }
        }
        .dockPopover(isPresented: $isOpen) {
            FolderGrid(root: url) { isOpen = false }
        }
        .contextMenu {
            Button("Remove from \(profileName)") { store.updateActive { $0.removeItem(at: itemIndex) } }
            Button("Open in Finder") { NSWorkspace.shared.open(url) }
            DockEditMenu(store: store, index: itemIndex + 1)
        }
    }
}

private struct FolderGrid: View {
    let root: URL
    let close: () -> Void
    /// The folders opened inside the stack, deepest last.
    @State private var path: [URL] = []

    private var folder: URL { path.last ?? root }

    var body: some View {
        let entries = Self.contents(of: folder)
        VStack(spacing: 8) {
            HStack {
                if !path.isEmpty {
                    Button { path.removeLast() } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                        .help("Back")
                }
                Text(FileManager.default.displayName(atPath: folder.path))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            if entries.isEmpty {
                Text("Empty folder")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 6), count: 4), spacing: 10) {
                        ForEach(entries, id: \.self) { entry in
                            Button { open(entry) } label: { FolderEntry(url: entry) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry]); close() }
                                }
                        }
                    }
                }
                .frame(height: min(CGFloat((entries.count + 3) / 4) * 100, 400))
            }
            Divider()
            Button("Open in Finder") {
                NSWorkspace.shared.open(folder)
                close()
            }
            .buttonStyle(.link)
        }
        .padding(12)
        .frame(width: 380)
    }

    private func open(_ entry: URL) {
        if Self.isFolder(entry) {
            path.append(entry)
        } else {
            NSWorkspace.shared.open(entry)
            close()
        }
    }

    /// Like the Dock's "Date Added" sort: newest first, without hidden files.
    private static func contents(of folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        func added(_ url: URL) -> Date {
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
        }
        return urls.map { ($0, added($0)) }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// A folder to open inside the stack; apps and packages are files here, as in the Dock.
    private static func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}

private struct FolderEntry: View {
    let url: URL
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 48, height: 48)
            Text(FileManager.default.displayName(atPath: url.path))
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
        }
        .frame(width: 84)
        .padding(.vertical, 4)
        .background(isHovered ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(url.lastPathComponent)
    }
}
