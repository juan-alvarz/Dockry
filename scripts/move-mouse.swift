// Moves the pointer to a point given relative to the main screen, posting real mouse-moved
// events (which is what Dockry's magnification follows). Usage:
//   swift scripts/move-mouse.swift <x from the left> <y from the bottom>
// Negative x counts from the middle of the screen instead: -1 is the middle, -1-n is n
// points right of it.
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments.dropFirst().compactMap(Double.init)
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: move-mouse.swift <x> <y from the bottom>\n".utf8))
    exit(2)
}
let screen = CGDisplayBounds(CGMainDisplayID())
let x = arguments[0] < 0 ? screen.midX + (-arguments[0] - 1) : arguments[0]
let target = CGPoint(x: x, y: screen.maxY - arguments[1])  // CG's origin is at the top left
// A few steps, the way a real pointer arrives, ending on the target.
let start = CGPoint(x: target.x - 60, y: target.y - 60)
for step in 0...6 {
    let fraction = Double(step) / 6
    let point = CGPoint(x: start.x + (target.x - start.x) * fraction, y: start.y + (target.y - start.y) * fraction)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
    usleep(30_000)
}
