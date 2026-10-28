// CI only: finds the on-screen element of Dockry whose text contains the argument and clicks
// its center with a real mouse click, the way a person would. (Pressing it through
// Accessibility would skip what's being checked: that a first click works in Dockry, which
// is never the active app.)
import AppKit

let text = CommandLine.arguments[1]
guard let dockry = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.juan-alvarz.Dockry").first
else { fatalError("Dockry isn't running") }

func attribute<T>(_ element: AXUIElement, _ name: String, as _: T.Type) -> T? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value as? T
}

func find(in element: AXUIElement) -> AXUIElement? {
    let labels = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap {
        attribute(element, $0, as: String.self)
    }
    if labels.contains(where: { $0.contains(text) }) { return element }
    let children = attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    return children.lazy.compactMap(find(in:)).first
}

guard let element = find(in: AXUIElementCreateApplication(dockry.processIdentifier)),
      let position = attribute(element, kAXPositionAttribute, as: AXValue.self),
      let size = attribute(element, kAXSizeAttribute, as: AXValue.self)
else { fatalError("Dockry shows nothing containing \"\(text)\"") }
var origin = CGPoint.zero
var extent = CGSize.zero
AXValueGetValue(position, .cgPoint, &origin)
AXValueGetValue(size, .cgSize, &extent)
let center = CGPoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2)

for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
}
print("Clicked \"\(text)\" at \(center)")
