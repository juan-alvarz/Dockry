import AppKit
import DockryCore
import ImageIO
import QuartzCore

enum WallpaperTransition: String, CaseIterable {
    case fade
    /// Comes into focus as it fades in.
    case blur
    /// Settles from slightly larger as it fades in.
    case zoom

    var title: String {
        switch self {
        case .fade: "Fade"
        case .blur: "Blur"
        case .zoom: "Zoom"
        }
    }
}

/// Each profile's desktop picture, on every screen, set whenever the profile becomes active
/// (and at launch, and when a screen is plugged in). A profile without one shows the macOS
/// default picture: nothing is learned from the screens or restored, so no profile's picture
/// can stay behind in another.
///
/// macOS takes a moment to show a new desktop picture, so the new one fades in right away in
/// a window just above the desktop (below its icons), from pictures decoded ahead of time,
/// and goes once macOS has caught up.
@MainActor
enum Wallpapers {
    static let macOSDefault = "/System/Library/CoreServices/DefaultDesktop.heic"
    private static var decoded: [String: CGImage] = [:]
    private static var fades: [NSWindow] = []

    /// Off, nothing is decoded or animated, and the pictures already decoded are let go.
    static var fadesIn = true {
        didSet { if !fadesIn { decoded = [:] } }
    }
    static var transition = WallpaperTransition.fade
    /// Seconds, at most 1.
    static var duration = 0.3

    static func show(_ profile: Profile, fading: Bool) {
        let picture = profile.wallpaper ?? macOSDefault
        set(fading: fading) { _ in picture }
    }

    /// Older versions showed "your own" picture in profiles without a wallpaper. Once, those
    /// profiles get the picture showing now as their own wallpaper, unless it's another
    /// profile's, so nothing changes on screen for them.
    static func giveOwnPictureToProfilesWithout(_ store: ProfileStore) {
        let key = "wallpapersGivenToProfiles"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard let screen = NSScreen.screens.first, let current = NSWorkspace.shared.desktopImageURL(for: screen)?.path,
              !store.library.profiles.contains(where: { $0.wallpaper == current })
        else { return }
        for profile in store.library.profiles where profile.wallpaper == nil {
            store.updateProfile(named: profile.name) { $0.wallpaper = current }
        }
    }

    /// Decodes the pictures switching may show, off the main thread, so they fade in at once.
    static func prepare(_ profiles: [Profile]) {
        guard fadesIn else { return }
        let paths = Set(profiles.map { $0.wallpaper ?? macOSDefault }).subtracting(decoded.keys)
        let size = NSScreen.screens.map { max($0.frame.width, $0.frame.height) * $0.backingScaleFactor }.max() ?? 3000
        for path in paths {
            Task.detached(priority: .utility) {
                guard let image = decode(path, maxPixels: size) else { return }
                await MainActor.run { if fadesIn { decoded[path] = image } }
            }
        }
    }

    private static func set(fading: Bool, _ picture: (String) -> String?) {
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let path = picture(String(id)),
                  URL(fileURLWithPath: path) != NSWorkspace.shared.desktopImageURL(for: screen)
            else { continue }
            if fading && fadesIn {
                fade(in: path, on: screen)
            }
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            do {
                try NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: options)
            } catch {
                NSLog("Dockry: couldn't set the desktop picture to \(path): \(error)")
            }
        }
    }

    private static func fade(in path: String, on screen: NSScreen) {
        let maxPixels = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        guard let image = decoded[path] ?? decode(path, maxPixels: maxPixels) else { return }
        decoded[path] = image
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        // On every desktop, so it shows through a desktop switch that's under way.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alphaValue = 0
        let view = NSView()
        view.wantsLayer = true
        view.layerUsesCoreImageFilters = true
        let picture = CALayer()
        picture.contents = image
        picture.contentsGravity = .resizeAspectFill
        picture.frame = CGRect(origin: .zero, size: screen.frame.size)
        view.layer?.addSublayer(picture)
        window.contentView = view
        window.setFrame(screen.frame, display: false)
        window.orderFront(nil)
        fades.append(window)

        let duration = min(max(duration, 0.1), 1)
        switch transition {
        case .fade:
            break
        case .blur:
            let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 0])!
            blur.name = "blur"
            picture.filters = [blur]
            animate(picture, "filters.blur.inputRadius", from: 40, to: 0, duration: duration)
        case .zoom:
            animate(picture, "transform.scale", from: 1.06, to: 1, duration: duration)
        }
        NSAnimationContext.runAnimationGroup { $0.duration = duration; window.animator().alphaValue = 1 }
        // By then macOS shows the same picture underneath.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1.5, duration + 0.8)) {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; window.animator().alphaValue = 0 }) {
                MainActor.assumeIsolated {
                    window.orderOut(nil)
                    fades.removeAll { $0 === window }
                }
            }
        }
    }

    private static func animate(_ layer: CALayer, _ keyPath: String, from: Double, to: Double, duration: Double) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.setValue(to, forKeyPath: keyPath)
        layer.add(animation, forKey: keyPath)
    }

    /// The picture at screen size, fully decoded; dynamic pictures give their first image.
    nonisolated private static func decode(_ path: String, maxPixels: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
