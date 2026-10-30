import AppKit
import DockryCore
import ServiceManagement
import SwiftUI

enum SettingsTab: String {
    case general, profiles, widgets
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
        showWindow()
    }

    /// Opens Settings › Profiles on one profile.
    static func show(profile: String) {
        selection.tab = .profiles
        selection.profile = profile
        showWindow()
    }

    /// Opens Settings › Widgets on one widget.
    static func show(widget: WidgetKind) {
        selection.tab = .widgets
        selection.widget = widget
        showWindow()
    }

    private static func showWindow() {
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
    /// The widget shown in Settings › Widgets.
    @Published var widget = WidgetCatalog.all[0].kind
    /// A profile to show in Settings › Profiles, until it's shown.
    @Published var profile: String?
}

private struct SettingsView: View {
    let store: ProfileStore
    let settings: SettingsStore
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        TabView(selection: $selection.tab) {
            GeneralSettings(settings: settings, store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProfilesSettings(store: store, settings: settings, selection: selection)
                .tabItem { Label("Profiles", systemImage: "square.stack") }
                .tag(SettingsTab.profiles)
            WidgetsSettings(store: store, selection: selection)
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.widgets)
        }
        .padding(.top, 8)
        .frame(minWidth: 680, minHeight: 540)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var settings: SettingsStore
    let store: ProfileStore
    @ObservedObject private var windowSpace = AppWindows.shared
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

            Section("Keyboard") {
                LabeledContent("Profile switcher") {
                    ShortcutRecorder(shortcut: $settings.profileSwitcherShortcut) {
                        shortcutOwner(of: $0, store: store, settings: settings, except: nil)
                    }
                }
                Text("Opens the profile switcher. Hold the modifier keys and press the key again to move to the next profile; let go to switch. Each profile can also have its own shortcut, under Profiles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Profiles") {
                Toggle("Give each profile its own open apps", isOn: $settings.separatesProfileApps)
                Text("Like desktops on Linux: an app belongs to the profile that was active when it opened, and switching profiles hides the other profiles’ apps. Bringing an app forward moves it to the profile you’re in. Finder is in every profile. The profile switcher and menu show which profile is playing sound.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Fresh profile badge") {
                    FreshBadgePicker()
                }
                Toggle("Show animation on switch profiles when wallpaper is present", isOn: $settings.fadesWallpapers)
                Text("Fades a profile’s wallpaper in as you switch, so it shows at once. Off, the wallpaper changes when macOS gets to it, and Dockry doesn’t keep the pictures ready in memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Group {
                    Picker("Animation", selection: $settings.wallpaperTransition) {
                        ForEach(WallpaperTransition.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Duration") {
                        HStack {
                            Slider(value: $settings.wallpaperTransitionDuration, in: 0.1...1, step: 0.05)
                            Text(String(format: "%.2g s", settings.wallpaperTransitionDuration))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                .disabled(!settings.fadesWallpapers)
                Toggle("Open a new app instance", isOn: $settings.opensNewAppInstances)
                    .disabled(!settings.separatesProfileApps)
                Text("Each window stays in the profile it opened in, like desktops on a Mac. Clicking an app in the dock that only has windows in other profiles opens a new window of it here (its New Window, ⌘N); apps without one bring their window over. Switching shows only the profile’s windows: apps with none in it hide, and the others’ windows wait just off screen, which Mission Control still shows for apps with windows in both. Bringing forward an app whose windows are all in another profile switches to that profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Windows") {
                Toggle("Keep windows out of the dock’s space", isOn: $settings.keepsWindowsClear)
                Text("As with the macOS Dock, windows stop at the dock’s edge: a zoomed window fills the space above it, and a window dragged behind it moves back out. Not while the dock hides automatically, which keeps no space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.keepsWindowsClear && !windowSpace.isTrusted {
                    HStack {
                        Label("Needs Accessibility access to move windows.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Allow…") { windowSpace.requestAccess() }
                    }
                    Text("If Dockry is already in the list and turned on, it’s from an older version: remove it with −, then turn on the new one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

/// Which other of Dockry's shortcuts has the same keys: a profile, by name, or the profile
/// switcher. `profile` is the one being set, nil for the switcher's own.
@MainActor
private func shortcutOwner(of shortcut: KeyShortcut, store: ProfileStore, settings: SettingsStore, except profile: String?) -> String? {
    if let other = store.library.profiles.first(where: { $0.name != profile && $0.shortcut?.sameKeys(as: shortcut) == true }) {
        return other.name
    }
    if profile != nil, settings.profileSwitcherShortcut?.sameKeys(as: shortcut) == true {
        return "the profile switcher"
    }
    return nil
}

// MARK: - Profiles

private struct ProfilesSettings: View {
    @ObservedObject var store: ProfileStore
    let settings: SettingsStore
    let selection: SettingsSelection
    @State private var selectedName: String?
    @State private var isCreating = false

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
                    ProfileEditor(store: store, settings: settings, profile: profile) { selectedName = $0 }
                        // A fresh editor per profile, so a name being typed ends with it.
                        .id(profile.name)
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
        .onReceive(selection.$profile.compactMap { $0 }) { profile in
            selectedName = profile
            selection.profile = nil
        }
    }

    private var profileList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedName) {
                ForEach(store.library.profiles, id: \.name) { profile in
                    HStack {
                        Label(profile.name, systemImage: profile.symbol)
                        if profile.freshApps {
                            FreshAppsBadge()
                        }
                        Spacer()
                        if profile.name == store.active.name {
                            Text("Active").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.name)
                }
            }
            HStack(spacing: 0) {
                Button { isCreating = true } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    .help("Add a profile")
                    .sheet(isPresented: $isCreating) {
                        NewProfileSheet { freshApps in
                            isCreating = false
                            if let freshApps { selectedName = store.addProfile(freshApps: freshApps) }
                        }
                    }
                Button {
                    if let selectedName {
                        remove(selectedName)
                    }
                } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                    .help("Remove the selected profile")
                    .disabled(store.library.profiles.count < 2 || selectedName == nil)
                Button {
                    if let selectedName, let copy = store.duplicateProfile(named: selectedName) {
                        self.selectedName = copy
                    }
                } label: { Image(systemName: "plus.square.on.square").frame(width: 24, height: 20) }
                    .help("Duplicate the selected profile")
                    .disabled(selectedName == nil)
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

    /// A fresh profile's app data goes too, unless the user keeps it.
    private func remove(_ name: String) {
        let fresh = store.library.profiles.first { $0.name == name }?.freshApps ?? false
        var keepData = true
        if fresh {
            let alert = NSAlert()
            alert.messageText = "Remove \u{201C}\(name)\u{201D}?"
            alert.informativeText = "This will remove all the data associated, you want to proceed?"
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "I want to preserve the data"
            alert.suppressionButton?.state = .off
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            keepData = alert.suppressionButton?.state == .on
        }
        store.removeProfile(named: name)
        // Only once the profile is really gone.
        if !keepData, !store.library.profiles.contains(where: { $0.name == name }) {
            AppInstances.trashData(of: name)
        }
        selectedName = store.active.name
    }

    private func move(by offset: Int) {
        if let selectedName {
            store.moveProfile(named: selectedName, by: offset)
        }
    }
}

/// Asks which kind of profile to create, since it can't change afterwards.
private struct NewProfileSheet: View {
    /// The kind chosen (fresh apps or not), or nil to cancel.
    let done: (Bool?) -> Void
    @State private var freshApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Profile").font(.headline)
            Picker("", selection: $freshApps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared apps")
                    Text("Uses your apps as they are, with your sign-ins, history and tabs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .tag(false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fresh apps")
                    Text("Starts apps from scratch, like on a new Mac. The profile runs its own copies of apps, and browsers and Electron apps (Zen, Chrome, Slack…) keep their own sign-ins, history and tabs, apart from your other profiles. Other apps still share their data. This can’t be changed later.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel") { done(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { done(freshApps) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// Marks profiles with fresh apps (Profile.freshApps): a symbol the user picks in
/// Settings › General › Profiles, a white circle unless they do.
struct FreshAppsBadge: View {
    static let symbolKey = "freshAppsBadge"
    static let defaultSymbol = "circle.fill"
    static let choices = [
        "circle.fill", "circle", "square.fill", "diamond.fill", "triangle.fill", "seal.fill",
        "leaf.fill", "lock.fill", "shield.fill", "bolt.fill", "flame.fill", "moon.fill",
    ]
    static var symbol: String { UserDefaults.standard.string(forKey: symbolKey) ?? defaultSymbol }

    @AppStorage(symbolKey) private var symbol = defaultSymbol

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(.primary)
            .help("Fresh apps: this profile runs its own copies of apps, with their own data")
    }
}

private struct FreshBadgePicker: View {
    @AppStorage(FreshAppsBadge.symbolKey) private var symbol = FreshAppsBadge.defaultSymbol

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FreshAppsBadge.choices, id: \.self) { choice in
                Button { symbol = choice } label: {
                    Image(systemName: choice)
                        .frame(width: 22, height: 20)
                        .background(choice == symbol ? Color.accentColor.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(choice)
            }
        }
    }
}

private struct ProfileEditor: View {
    @ObservedObject var store: ProfileStore
    let settings: SettingsStore
    let profile: Profile
    let renamed: (String) -> Void
    /// The name being typed; the profile is renamed once editing ends.
    @State private var draftName: String?
    @FocusState private var isEditingName: Bool

    private static let suggestedColors = ["#3563E9", "#7C3AED", "#E2457A", "#F08A4B", "#F5B83D", "#22A06B", "#0EA5A4"]

    private static let suggestedSymbols = [
        "briefcase.fill", "cup.and.saucer.fill", "gamecontroller.fill", "paintbrush.fill",
        "book.fill", "music.note", "film.fill", "chevron.left.forwardslash.chevron.right",
        "house.fill", "graduationcap.fill", "moon.fill", "cat.fill",
    ]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: Binding(get: { draftName ?? profile.name }, set: { draftName = $0 }))
                    .focused($isEditingName)
                    .onSubmit(commitName)
                    .onChange(of: isEditingName) { _, isEditing in
                        if !isEditing { commitName() }
                    }
                    .onDisappear(perform: commitName)
                LabeledContent("Shortcut") {
                    ShortcutRecorder(shortcut: binding(\.shortcut)) {
                        shortcutOwner(of: $0, store: store, settings: settings, except: profile.name)
                    }
                }
                LabeledContent("Symbol") {
                    Image(systemName: profile.symbol).help(profile.symbol)
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
                LabeledContent("Color") {
                    HStack(spacing: 6) {
                        // A few to pick with one click; the color well has the rest.
                        ForEach(Self.suggestedColors, id: \.self) { hex in
                            Button { change { $0.color = hex } } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(.primary.opacity(profile.color == hex ? 0.8 : 0), lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        ColorPicker("Other color", selection: colorBinding, supportsOpacity: false)
                            .labelsHidden()
                        Button("None") { change { $0.color = nil } }
                            .controlSize(.small)
                            .disabled(profile.color == nil)
                    }
                }
                Picker("Desktop", selection: binding(\.desktop)) {
                    Text("Stay on the current desktop").tag(Int?.none)
                    ForEach(1...9, id: \.self) { Text("Desktop \($0)").tag(Int?.some($0)) }
                }
                LabeledContent("Wallpaper") {
                    HStack {
                        if let wallpaper = profile.wallpaper {
                            Image(nsImage: NSImage(contentsOfFile: wallpaper) ?? NSWorkspace.shared.icon(forFile: wallpaper))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .help(wallpaper)
                        } else {
                            Text("Your own").foregroundStyle(.secondary)
                        }
                        Button("Choose…", action: chooseWallpaper)
                        Button("None") { change { $0.wallpaper = nil } }
                            .disabled(profile.wallpaper == nil)
                    }
                    .controlSize(.small)
                }
                Toggle("Open its apps when switching to it", isOn: binding(\.opensAppsOnSwitch))
                if profile.freshApps {
                    LabeledContent("Apps") {
                        HStack(spacing: 4) {
                            FreshAppsBadge()
                            Text("Fresh: its own copies, with their own data")
                        }
                    }
                    Button("Show App Data in Finder") {
                        let folder = AppInstances.dataFolder(of: profile.name)
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
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
                let disabled = WidgetCatalog.all.map(\.kind).filter { !enabled.contains($0) }
                ForEach(Array(enabled.enumerated()), id: \.element) { index, kind in
                    HStack {
                        Toggle(isOn: Binding(get: { true }, set: { _ in change { $0.widgets.removeAll { $0 == kind } } })) {
                            WidgetLabel(info: kind.info)
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
                        WidgetLabel(info: kind.info)
                    }
                }
                Button("About Widgets…") { SettingsWindow.show(tab: .widgets) }
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

    private var colorBinding: Binding<Color> {
        Binding(
            get: { profile.color.flatMap(Color.init(hex:)) ?? .gray },
            set: { color in change { $0.color = color.hexString } })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(get: { profile[keyPath: keyPath] }, set: { value in change { $0[keyPath: keyPath] = value } })
    }

    /// Renames the profile to the name typed, once. The store ignores taken and empty names,
    /// and the field then shows the name the profile still has.
    private func commitName() {
        guard let draftName else { return }
        self.draftName = nil
        guard draftName != profile.name,
              let name = store.updateProfile(named: profile.name, { $0.name = draftName }),
              name != profile.name
        else { return }
        renamed(name)
    }

    private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.directoryURL = URL(fileURLWithPath: profile.wallpaper ?? "/System/Library/Desktop Pictures")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        change { $0.wallpaper = url.path }
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

/// A widget's icon and name, with what it does as the tooltip.
private struct WidgetLabel: View {
    let info: WidgetInfo

    var body: some View {
        HStack(spacing: 8) {
            WidgetIcon(info: info, size: 20)
            Text(info.name)
        }
        .help(info.summary)
    }
}
