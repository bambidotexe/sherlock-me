#!/usr/bin/env swift
// Renders the 1024 px master the flat `.icns` inside the bundle is rasterised from.
//
//   swift scripts/make-icon-preview.swift <out.png>
//
// **This is a placeholder.** The real icon of an app of this family comes out of Icon Composer, which
// exports both `Resources/AppIcon.icon` and this master; until somebody draws one, both are generated from
// the same mark the menu-bar item draws, so that the two at least agree. Replacing the icon means
// re-exporting both from Icon Composer and deleting this script (Resources/ICON-NOTES.md).
//
// The rounded square is macOS's own proportion: a continuous corner radius of 0.2237 of the side.

import AppKit
import Foundation

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("make-icon-preview: " + message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else { die("usage: make-icon-preview.swift <out.png>") }

let side: CGFloat = 1024
let cornerRadius = side * 0.2237
// The indigo of Resources/AppIcon.icon/icon.json, lighter at the top.
let top = NSColor(srgbRed: 0.47, green: 0.51, blue: 0.93, alpha: 1)
let bottom = NSColor(srgbRed: 0.30, green: 0.33, blue: 0.76, alpha: 1)

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { die("could not allocate the bitmap") }
rep.size = NSSize(width: side, height: side)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else { die("could not open a context") }
NSGraphicsContext.current = context
context.imageInterpolation = .high

// The slab, with the mask an .icns is required to bake in.
let mask = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                        xRadius: cornerRadius, yRadius: cornerRadius)
mask.addClip()
NSGradient(starting: top, ending: bottom)?.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
                                                angle: -90)

// The mark: the SVG's numbers. A rounded outline, and a dot at its centre.
let stroke: CGFloat = 56
let outline = NSRect(x: 260, y: 260, width: 504, height: 504)
NSColor.white.setStroke()
NSColor.white.setFill()
let ring = NSBezierPath(roundedRect: outline, xRadius: 120, yRadius: 120)
ring.lineWidth = stroke
ring.stroke()
NSBezierPath(ovalIn: NSRect(x: 512 - 104, y: 512 - 104, width: 208, height: 208)).fill()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { die("could not encode the PNG") }
do { try png.write(to: URL(fileURLWithPath: arguments[1])) }
catch { die("could not write: \(error.localizedDescription)") }
