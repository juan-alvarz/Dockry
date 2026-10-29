import DockryCore
import SwiftUI

/// Settings › Widgets: every widget with what it does, the profiles it's in, what it needs,
/// and its own settings.
struct WidgetsSettings: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        HStack(spacing: 0) {
            List(DockWidget.all, id: \.kind, selection: selectedKind) { widget in
                WidgetRow(info: widget.info, profiles: profiles(showing: widget.kind))
                    .tag(widget.kind)
            }
            .frame(width: 220)
            Divider()
            WidgetDetail(widget: DockWidget.widget(for: selection.widget), store: store)
                // A fresh form per widget, scrolled to the top.
                .id(selection.widget)
                .frame(maxWidth: .infinity)
        }
    }

    /// The List's selection can be cleared; the detail always shows a widget.
    private var selectedKind: Binding<WidgetKind?> {
        Binding(get: { selection.widget }, set: { if let kind = $0 { selection.widget = kind } })
    }

    private func profiles(showing kind: WidgetKind) -> [String] {
        store.library.profiles.filter { $0.widgets.contains(kind) }.map(\.name)
    }
}

private struct WidgetRow: View {
    let info: WidgetInfo
    let profiles: [String]

    var body: some View {
        HStack(spacing: 10) {
            WidgetIcon(info: info, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.name)
                Text(profiles.isEmpty ? "Not in a profile" : profiles.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct WidgetDetail: View {
    let widget: DockWidget
    @ObservedObject var store: ProfileStore

    private var info: WidgetInfo { widget.info }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    WidgetIcon(info: info, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.name).font(.title3.weight(.semibold))
                        Text(info.summary).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Badge(text: info.category.rawValue)
                            Badge(text: info.author == "Dockry" ? "Built in" : "By \(info.author)")
                        }
                    }
                }
                Text(info.details)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(store.library.profiles, id: \.name) { profile in
                    Toggle(isOn: isShown(in: profile)) {
                        Label(profile.name, systemImage: profile.symbol)
                    }
                }
            } header: {
                Text("Show in Profiles")
            } footer: {
                Text("It goes after the profile’s other widgets. Reorder them under Profiles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !info.requirements.isEmpty {
                Section("Needs") {
                    ForEach(info.requirements, id: \.text) { requirement in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: requirement.isOptional ? "plus.circle" : "checkmark.circle")
                                .foregroundStyle(requirement.isOptional ? Color.secondary : Color(hex: info.tint) ?? .accentColor)
                            Text(requirement.text)
                            if requirement.isOptional {
                                Text("Optional").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            widget.makeSettings?()
        }
        .formStyle(.grouped)
    }

    private func isShown(in profile: Profile) -> Binding<Bool> {
        let kind = info.kind
        return Binding(
            get: { profile.widgets.contains(kind) },
            set: { isOn in
                store.updateProfile(named: profile.name) { profile in
                    profile.widgets.removeAll { $0 == kind }
                    if isOn {
                        profile.widgets.append(kind)
                    }
                }
            })
    }
}

private struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}
