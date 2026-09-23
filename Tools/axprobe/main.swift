// The Accessibility probe: reads the app's own windows the way a real hit test does, which is the only way
// to see a control that is drawn in one place and hit-tested in another (the shared pitfalls, *Onboarding*).
// Never shipped: scripts/make-app.sh copies one executable into the bundle, and this is not it.
//
//   swift run axprobe elements <app name or pid> [depth]   the front window's element tree, every frame
//   swift run axprobe hit <x> <y>                            what a real hit test finds at a point, and the
//                                                            chain of elements above it
//
// Points are screen points with the origin at the top-left of the primary display and y downwards, which
// is what `AXPosition` and `CGEvent.location` use. A command-line tool inherits the Accessibility grant of
// the terminal that starts it.

import AppKit
import ApplicationServices
import Foundation

enum AXProbe {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else { usage(); exit(1) }
        guard AXIsProcessTrusted() else {
            print("This terminal is not trusted for Accessibility, so nothing will answer.")
            print("System Settings > Privacy & Security > Accessibility, and add the terminal.")
            exit(1)
        }
        switch arguments[1] {
        case "elements":
            guard arguments.count >= 3 else { usage(); exit(1) }
            elements(of: arguments[2], depth: arguments.count >= 4 ? Int(arguments[3]) ?? 8 : 8)
        case "hit":
            guard arguments.count >= 4, let x = Double(arguments[2]), let y = Double(arguments[3])
            else { usage(); exit(1) }
            hit(CGPoint(x: x, y: y))
        default:
            usage(); exit(1)
        }
    }

    static func usage() {
        print("""
        usage: axprobe <command>
          elements <app name or pid> [depth]   the front window's element tree, with every frame
          hit <x> <y>                          what a real hit test finds at a point, and every element above it
        """)
    }

    /// The front window of the named process, walked to `limit` levels.
    static func elements(of app: String, depth limit: Int) {
        guard let pid = pid(for: app) else { print("no running process called \(app)"); exit(1) }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 5)
        let windows = children(of: application, attribute: kAXWindowsAttribute as String)
        guard !windows.isEmpty else { print("\(app) has no window on screen"); return }
        let front = element(application, kAXFocusedWindowAttribute as String) ?? windows[0]
        walk(front, depth: 0, limit: limit)
    }

    /// What is under a point. A frame that names a rectangle where this finds nothing is the class of bug
    /// the probe exists for.
    static func hit(_ point: CGPoint) {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 5)
        var found: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &found)
        guard error == .success, let hit = found else { print("nothing answered (\(error.rawValue))"); return }
        var current: AXUIElement? = hit
        var level = 0
        while let element = current, level < 12 {
            print(String(repeating: "  ", count: level) + describe(element))
            current = self.element(element, kAXParentAttribute as String)
            level += 1
        }
    }

    // MARK: - Reading

    static func pid(for app: String) -> pid_t? {
        if let number = Int32(app) { return number }
        return NSWorkspace.shared.runningApplications
            .first { $0.localizedName == app || $0.bundleIdentifier == app }?.processIdentifier
    }

    static func walk(_ element: AXUIElement, depth: Int, limit: Int) {
        print(String(repeating: "  ", count: depth) + describe(element))
        guard depth < limit else { return }
        for child in children(of: element, attribute: kAXChildrenAttribute as String) {
            walk(child, depth: depth + 1, limit: limit)
        }
    }

    static func describe(_ element: AXUIElement) -> String {
        var text = "\(string(element, kAXRoleAttribute as String) ?? "?")/\(string(element, kAXSubroleAttribute as String) ?? "-")"
        if let title = string(element, kAXTitleAttribute as String), !title.isEmpty {
            text += " title=\(title.prefix(40))"
        }
        if let value = string(element, kAXValueAttribute as String), !value.isEmpty {
            text += " value=\(value.prefix(40))"
        }
        if let identifier = string(element, "AXIdentifier"), !identifier.isEmpty {
            text += " id=\(identifier)"
        }
        if let frame = frame(element) {
            text += String(format: " (%.0f,%.0f %.0fx%.0f)", frame.minX, frame.minY, frame.width, frame.height)
        }
        let kids = children(of: element, attribute: kAXChildrenAttribute as String).count
        if kids > 0 { text += " kids=\(kids)" }
        return text
    }

    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var out: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &out) == .success ? out : nil
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == CFArrayGetTypeID() else { return [] }
        return (raw as! [AnyObject]).compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
        }
    }

    /// `AXFrame` in one round trip, in screen points, origin top-left.
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let raw = value(element, "AXFrame"), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(raw as! AXValue, .cgRect, &rect) ? rect : nil
    }
}

AXProbe.main()
