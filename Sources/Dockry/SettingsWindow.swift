import AppKit
import DockryCore
import ServiceManagement
import SwiftUI

enum SettingsTab: String {
    case general, profiles, spotify
}

/// Dockry's Settings window, opened from the menu bar item, the dock's menu or ⌘,.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?
    private static let selection = SettingsSelection()
    private static var makeContent: (() -> AnyView)?

    static var isOpen: Bool { window?.isVisible == true }

    static func configure(store: ProfileStore, settings: SettingsStore) {
        makeContent = { AnyView(SettingsView(store: store, settings: settings, selection: selection)) }
    }

    static func show(tab: SettingsTab? = nil) {
        if let tab {
            selection.tab = tab
        }
        if window == nil, let makeContent {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Dockry Settings"
            window.contentView = NSHostingView(rootView: makeContent())
            window.isReleasedWhenClosed = false
            window.center()
            Self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class SettingsSelection: ObservableObject {
    @Published var tab = SettingsTab.general
}

private struct SettingsView: View {
    let store: ProfileStore
    let settings: SettingsStore
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        TabView(selection: $selection.tab) {
            GeneralSettings(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProfilesSettings(store: store)
                .tabItem { Label("Profiles", systemImage: "square.stack") }
                .tag(SettingsTab.profiles)
            SpotifySettings()
                .tabItem { Label("Spotify", systemImage: "music.note") }
                .tag(SettingsTab.spotify)
        }
        .padding(.top, 8)
        .frame(minWidth: 680, minHeight: 540)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var settings: SettingsStore
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dockry").font(.title3.weight(.semibold))
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("Sync with Mac Dock settings", isOn: $settings.syncsWithMacDock)
                Text("Uses the macOS Dock’s size, magnification, position, hiding and animations. Change them in System Settings › Desktop & Dock, and Dockry follows within a couple of seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.syncsWithMacDock {
                    Button("Open Desktop & Dock Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            Section("Dock") {
                LabeledContent("Size") {
                    Slider(value: binding(\.iconSize), in: DockSettings.sizeRange) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Small")
                    } maximumValueLabel: {
                        Text("Large")
                    }
                }
                Toggle("Magnification", isOn: binding(\.magnifies))
                LabeledContent("Magnified size") {
                    Slider(value: binding(\.magnifiedSize), in: DockSettings.sizeRange) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Small")
                    } maximumValueLabel: {
                        Text("Large")
                    }
                }
                .disabled(!settings.dock.magnifies)
                Picker("Position on screen", selection: binding(\.position)) {
                    ForEach(DockPosition.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Automatically hide and show the dock", isOn: binding(\.autohides))
                Toggle("Animate opening applications", isOn: binding(\.animatesLaunch))
                Toggle("Show indicators for open applications", isOn: binding(\.showsIndicators))
            }
            .disabled(settings.syncsWithMacDock)

            Section {
                Toggle("Show open apps that aren’t in the profile", isOn: $settings.showsUnpinnedApps)
                Text("At the bottom, Dockry shows a dock on every screen. On the left or right, it’s on the screen at that edge of your display arrangement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("macOS Dock") {
                Toggle("Hide macOS Dock", isOn: $settings.hidesSystemDock)
                Text("Your Dock settings are saved first and put back when you turn this off or quit Dockry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Open Dockry at login", isOn: Binding(get: { opensAtLogin }, set: setOpensAtLogin))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Shows the settings in use (the Mac Dock's while syncing) and edits Dockry's own.
    private func binding<Value>(_ keyPath: WritableKeyPath<DockSettings, Value>) -> Binding<Value> {
        Binding(get: { settings.dock[keyPath: keyPath] }, set: { settings.own[keyPath: keyPath] = $0 })
    }

    private func setOpensAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Couldn’t change this: \(error.localizedDescription) Dockry needs to be in the Applications folder."
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Profiles

private struct ProfilesSettings: View {
    @ObservedObject var store: ProfileStore
    @State private var selectedName: String?

    var body: some View {
        VStack(spacing: 0) {
            if store.loadError != nil {
                Label("profiles.json has an error, so the default profiles are shown and changes aren’t saved. Fix the file, then choose Reload from File.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(10)
            }
            HStack(spacing: 0) {
                profileList
                    .frame(width: 180)
                Divider()
                if let profile = store.library.profiles.first(where: { $0.name == selectedName }) {
                    ProfileEditor(store: store, profile: profile) { selectedName = $0 }
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Select a profile")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                Button("Edit as JSON…") { store.openFile() }
                Button("Reload from File") { store.reload() }
                Spacer()
                Button("Show in Finder") { store.showFileInFinder() }
            }
            .padding(10)
        }
        .onAppear { selectedName = selectedName ?? store.active.name }
    }

    private var profileList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedName) {
                ForEach(store.library.profiles, id: \.name) { profile in
                    HStack {
                        Label(profile.name, systemImage: profile.symbol)
                        Spacer()
                        if profile.name == store.active.name {
                            Text("Active").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.name)
                }
            }
            HStack(spacing: 0) {
                Button { selectedName = store.addProfile() } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    .help("Add a profile")
                Button {
                    if let selectedName {
                        store.removeProfile(named: selectedName)
                        self.selectedName = store.active.name
                    }
                } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                    .help("Remove the selected profile")
                    .disabled(store.library.profiles.count < 2 || selectedName == nil)
                Spacer()
                Button { move(by: -1) } label: { Image(systemName: "chevron.up").frame(width: 24, height: 20) }
                    .help("Move up")
                Button { move(by: 1) } label: { Image(systemName: "chevron.down").frame(width: 24, height: 20) }
                    .help("Move down")
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    private func move(by offset: Int) {
        if let selectedName {
            store.moveProfile(named: selectedName, by: offset)
        }
    }
}

private struct ProfileEditor: View {
    @ObservedObject var store: ProfileStore
    let profile: Profile
    let renamed: (String) -> Void

    private static let suggestedSymbols = [
        "briefcase.fill", "cup.and.saucer.fill", "gamecontroller.fill", "paintbrush.fill",
        "book.fill", "music.note", "film.fill", "chevron.left.forwardslash.chevron.right",
        "house.fill", "graduationcap.fill", "moon.fill", "cat.fill",
    ]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: Binding(get: { profile.name }, set: rename))
                LabeledContent("Symbol") {
                    HStack {
                        Image(systemName: profile.symbol).frame(width: 20)
                        TextField("SF Symbol name", text: binding(\.symbol))
                            .labelsHidden()
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 4)], spacing: 4) {
                    ForEach(Self.suggestedSymbols, id: \.self) { symbol in
                        Button { change { $0.symbol = symbol } } label: {
                            Image(systemName: symbol)
                                .frame(width: 26, height: 22)
                                .background(symbol == profile.symbol ? Color.accentColor.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help(symbol)
                    }
                }
                Picker("Desktop", selection: binding(\.desktop)) {
                    Text("Stay on the current desktop").tag(Int?.none)
                    ForEach(1...9, id: \.self) { Text("Desktop \($0)").tag(Int?.some($0)) }
                }
                if profile.name != store.active.name {
                    Button("Make Active") { store.activate(named: profile.name) }
                }
            }

            Section("Apps") {
                ForEach(Array(profile.pinnedApps.enumerated()), id: \.element) { index, bundleID in
                    HStack {
                        if let app = AppCatalog.app(bundleID: bundleID, running: nil) {
                            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                            Text(app.name)
                        } else {
                            Image(systemName: "questionmark.app.dashed").frame(width: 22, height: 22)
                            Text(bundleID).foregroundStyle(.secondary)
                        }
                        Spacer()
                        rowButtons(index: index, count: profile.pinnedApps.count) { offset in
                            change { $0.pinnedApps.move(from: index, by: offset) }
                        } remove: {
                            change { $0.pinnedApps.remove(at: index) }
                        }
                    }
                }
                Button("Add App…", action: addApp)
            }

            Section("Widgets") {
                let enabled = profile.widgets
                let disabled = WidgetKind.allCases.filter { !enabled.contains($0) }
                ForEach(Array(enabled.enumerated()), id: \.element) { index, kind in
                    HStack {
                        Toggle(isOn: Binding(get: { true }, set: { _ in change { $0.widgets.removeAll { $0 == kind } } })) {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        Spacer()
                        rowButtons(
                            index: index, count: enabled.count,
                            move: { offset in change { $0.widgets.move(from: index, by: offset) } },
                            remove: nil)
                    }
                }
                ForEach(disabled, id: \.self) { kind in
                    Toggle(isOn: Binding(get: { false }, set: { _ in change { $0.widgets.append(kind) } })) {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func rowButtons(
        index: Int, count: Int, move: @escaping (Int) -> Void, remove: (() -> Void)?
    ) -> some View {
        HStack(spacing: 2) {
            Button { move(-1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
                .help("Move up")
            Button { move(1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == count - 1)
                .help("Move down")
            if let remove {
                Button(action: remove) { Image(systemName: "minus.circle") }
                    .help("Remove")
            }
        }
        .buttonStyle(.borderless)
    }

    private func change(_ change: (inout Profile) -> Void) {
        store.updateProfile(named: profile.name, change)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(get: { profile[keyPath: keyPath] }, set: { value in change { $0[keyPath: keyPath] = value } })
    }

    private func rename(_ newName: String) {
        change { $0.name = newName }
        // The store ignores taken and empty names; follow the profile under whichever name it has now.
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        if store.library.profiles.contains(where: { $0.name == trimmed }) {
            renamed(trimmed)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let bundleIDs = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        change { profile in
            for bundleID in bundleIDs where !profile.pinnedApps.contains(bundleID) {
                profile.pinnedApps.append(bundleID)
            }
        }
    }
}

private extension Array {
    mutating func move(from index: Int, by offset: Int) {
        let target = index + offset
        guard indices.contains(index), indices.contains(target) else { return }
        swapAt(index, target)
    }
}

// MARK: - Spotify

private struct SpotifySettings: View {
    @ObservedObject private var account = SpotifyAccount.shared

    var body: some View {
        Form {
            Section {
                Text("Searching from the Spotify widget uses your Spotify account. Spotify asks every app for its own client ID, so set one up once:")
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app. Any name works.")
                    Text("2. Under Redirect URIs, add the one below. Under APIs, choose Web API.")
                    Text("3. Copy the app’s Client ID into the field below and click Sign In.")
                }
                .font(.callout)
                LabeledContent("Redirect URI") {
                    HStack {
                        Text(SpotifyWebAPI.redirectURI)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyWebAPI.redirectURI, forType: .string)
                        }
                    }
                }
                TextField("Client ID", text: $account.clientID)
            }

            Section {
                HStack {
                    statusLabel
                    Spacer()
                    if account.status == .signedIn {
                        Button("Sign Out") { account.signOut() }
                    } else {
                        Button("Sign In…") { account.signIn() }
                            .disabled(account.clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Text("Songs you pick play in the Spotify app, which stays in the background. Playing doesn’t need Premium.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var statusLabel: some View {
        switch account.status {
        case .signedOut: Label("Not signed in", systemImage: "person.crop.circle.badge.xmark")
        case .signingIn: Label("Finish signing in in your browser…", systemImage: "safari")
        case .signedIn: Label("Signed in", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message): Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
