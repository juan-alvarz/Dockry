// CI only: drags one of Dockry's dock icons sideways with real mouse events, the way a
// person would. Arguments: the app's name (its tooltip in the dock) and how far to drag in
// points. A screenshot can be taken mid-drag: pass a path as the third argument.
import AppKit

let arguments = CommandLine.arguments
let name = arguments[1]
let distance = Double(arguments[2])!
guard let dockry = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.juan-alvarz.Dockry").first
else { fatalError("Dockry isn't running") }

func attribute<T>(_ element: AXUIElement, _ name: String, as _: T.Type) -> T? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value as? T
}

func find(in element: AXUIElement) -> AXUIElement? {
    let labels = [kAXHelpAttribute, kAXTitleAttribute, kAXDescriptionAttribute].compactMap {
        attribute(element, $0, as: String.self)
    }
    if labels.contains(name) { return element }
    let children = attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    return children.lazy.compactMap(find(in:)).first
}

guard let element = find(in: AXUIElementCreateApplication(dockry.processIdentifier)),
      let position = attribute(element, kAXPositionAttribute, as: AXValue.self),
      let size = attribute(element, kAXSizeAttribute, as: AXValue.self)
else { fatalError("The dock shows no \"\(name)\"") }
var origin = CGPoint.zero
var extent = CGSize.zero
AXValueGetValue(position, .cgPoint, &origin)
AXValueGetValue(size, .cgSize, &extent)
let start = CGPoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2)

func post(_ type: CGEventType, at point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

post(.leftMouseDown, at: start)
usleep(100_000)
let steps = 20
for step in 1...steps {
    post(.leftMouseDragged, at: CGPoint(x: start.x + distance * Double(step) / Double(steps), y: start.y))
    usleep(20_000)
}
usleep(300_000)
if arguments.count > 3 {
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", arguments[3]]
    try capture.run()
    capture.waitUntilExit()
}
post(.leftMouseUp, at: CGPoint(x: start.x + distance, y: start.y))
print("Dragged \(name) \(distance) points from \(start)")
