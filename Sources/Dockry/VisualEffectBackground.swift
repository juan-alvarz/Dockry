import AppKit
import SwiftUI

/// Real behind-window blur; SwiftUI materials only blur content inside the same window.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active  // stay blurred while Dockry isn't the active app, which is always
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
