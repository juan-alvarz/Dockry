import AppKit
import DockryCore
import SwiftUI

/// Fast User Switching: the Mac's other accounts; click one to switch to it.
struct UsersWidget: View {
    static let widget = DockWidget(info: WidgetKind.users.info) { AnyView(UsersWidget()) }

    @ObservedObject private var users = MacUsers.shared
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let u = metrics.unit
        let stack = metrics.axis == .vertical
            ? AnyLayout(VStackLayout(spacing: 6 * u))
            : AnyLayout(HStackLayout(spacing: 6 * u))
        stack {
            ForEach(users.others) { user in
                Button { UserSwitching.switchTo(user) } label: {
                    UserAvatar(user: user, size: 34 * u)
                }
                .buttonStyle(.plain)
                .help("Switch to \(user.fullName)")
            }
            if users.others.isEmpty {
                Button { UserSwitching.showLoginWindow() } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14 * u))
                        .frame(width: 34 * u, height: 34 * u)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Switch User…")
            }
        }
        .padding(metrics.axis == .vertical ? .vertical : .horizontal, 7 * u)
        .frame(
            width: metrics.axis == .vertical ? metrics.iconSize : nil,
            height: metrics.axis == .vertical ? nil : metrics.iconSize)
        .widgetTile()
    }
}

private struct UserAvatar: View {
    let user: MacUser
    let size: CGFloat

    var body: some View {
        Group {
            if let path = user.picturePath, let picture = NSImage(contentsOfFile: path) {
                Image(nsImage: picture).resizable().scaledToFill()
            } else {
                // Like macOS's own avatars for accounts without a picture.
                Text(user.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
