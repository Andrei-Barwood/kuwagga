#!/usr/bin/env swift
import AppKit
import Foundation

// Paleta solicitada para el icono de Terminal Styles.
enum IconPalette {
    static let lavenderGray = NSColor(hex: 0x9C9AAD)!
    static let white        = NSColor(hex: 0xFFFFFF)!
    static let slateGray    = NSColor(hex: 0x9291A3)!
    static let lightGray    = NSColor(hex: 0xF1F1F1)!
    static let navy         = NSColor(hex: 0x2D3558)!
    static let steelBlue    = NSColor(hex: 0x43558C)!
    static let deepNavy     = NSColor(hex: 0x233250)!
    static let midBlue      = NSColor(hex: 0x3F5085)!
}

extension NSColor {
    convenience init?(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(calibratedRed: r, green: g, blue: b, alpha: alpha)
    }
}

struct IconSpec {
    let filename: String
    let pixels: Int
}

// Tamaños exactos exigidos por actool para macOS.
let iconSpecs: [IconSpec] = [
    IconSpec(filename: "icon_16.png", pixels: 16),
    IconSpec(filename: "icon_16@2x.png", pixels: 32),
    IconSpec(filename: "icon_32.png", pixels: 32),
    IconSpec(filename: "icon_32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128.png", pixels: 128),
    IconSpec(filename: "icon_128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256.png", pixels: 256),
    IconSpec(filename: "icon_256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512.png", pixels: 512),
    IconSpec(filename: "icon_512@2x.png", pixels: 1024)
]

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/TerminalStyles/Assets.xcassets/AppIcon.appiconset")

func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func drawGradient(in rect: NSRect, radius: CGFloat, top: NSColor, bottom: NSColor) {
    guard let gradient = NSGradient(starting: top, ending: bottom) else { return }
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    gradient.draw(in: path, angle: 270)
}

/// Dibuja el icono en un contexto gráfico del tamaño exacto en píxeles.
func drawIconContent(side: CGFloat) {
    let s = side
    let canvas = NSRect(x: 0, y: 0, width: s, height: s)
    let outer = canvas.insetBy(dx: s * 0.05, dy: s * 0.05)

    drawGradient(
        in: outer,
        radius: s * 0.22,
        top: IconPalette.deepNavy,
        bottom: IconPalette.navy
    )

    let windowRect = NSRect(
        x: outer.minX + s * 0.14,
        y: outer.minY + s * 0.12,
        width: outer.width - s * 0.28,
        height: outer.height - s * 0.24
    )
    fillRoundedRect(windowRect, radius: s * 0.07, color: IconPalette.midBlue)
    strokeRoundedRect(
        windowRect.insetBy(dx: s * 0.012, dy: s * 0.012),
        radius: s * 0.065,
        color: IconPalette.steelBlue.withAlphaComponent(0.55),
        width: max(1, s * 0.012)
    )

    let titleBar = NSRect(
        x: windowRect.minX,
        y: windowRect.maxY - s * 0.16,
        width: windowRect.width,
        height: s * 0.16
    )
    fillRoundedRect(
        NSRect(x: titleBar.minX, y: titleBar.minY, width: titleBar.width, height: titleBar.height + s * 0.03),
        radius: s * 0.07,
        color: IconPalette.steelBlue
    )
    fillRoundedRect(
        NSRect(x: titleBar.minX, y: titleBar.minY - s * 0.02, width: titleBar.width, height: s * 0.06),
        radius: 0,
        color: IconPalette.steelBlue
    )

    let dotRadius = s * 0.028
    let dotY = titleBar.midY - dotRadius
    let dotStartX = titleBar.minX + s * 0.07
    let dotColors = [IconPalette.lavenderGray, IconPalette.slateGray, IconPalette.lightGray]
    for (index, color) in dotColors.enumerated() {
        let cx = dotStartX + CGFloat(index) * s * 0.075
        let dot = NSBezierPath(ovalIn: NSRect(x: cx, y: dotY, width: dotRadius * 2, height: dotRadius * 2))
        color.setFill()
        dot.fill()
    }

    let contentRect = NSRect(
        x: windowRect.minX + s * 0.08,
        y: windowRect.minY + s * 0.22,
        width: windowRect.width - s * 0.16,
        height: windowRect.height - s * 0.34
    )
    let fontSize = max(6, s * 0.17)
    let promptFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let promptAttrs: [NSAttributedString.Key: Any] = [
        .font: promptFont,
        .foregroundColor: IconPalette.white
    ]
    ">_" .draw(
        at: NSPoint(x: contentRect.minX, y: contentRect.maxY - fontSize * 1.15),
        withAttributes: promptAttrs
    )

    let lineColors = [IconPalette.lightGray, IconPalette.lavenderGray, IconPalette.white]
    let lineWidths: [CGFloat] = [0.72, 0.52, 0.38]
    for (index, widthFactor) in lineWidths.enumerated() {
        let lineY = contentRect.minY + CGFloat(2 - index) * s * 0.11
        let lineRect = NSRect(
            x: contentRect.minX,
            y: lineY,
            width: contentRect.width * widthFactor,
            height: max(2, s * 0.045)
        )
        fillRoundedRect(lineRect, radius: lineRect.height / 2, color: lineColors[index])
    }

    let swatchColors = [
        IconPalette.deepNavy,
        IconPalette.steelBlue,
        IconPalette.midBlue,
        IconPalette.lavenderGray,
        IconPalette.slateGray,
        IconPalette.lightGray,
        IconPalette.white
    ]
    let swatchHeight = max(2, s * 0.05)
    let swatchWidth = (windowRect.width - s * 0.18) / CGFloat(swatchColors.count)
    let swatchY = windowRect.minY + s * 0.07
    for (index, color) in swatchColors.enumerated() {
        let swatchRect = NSRect(
            x: windowRect.minX + s * 0.09 + CGFloat(index) * swatchWidth,
            y: swatchY,
            width: swatchWidth - s * 0.012,
            height: swatchHeight
        )
        fillRoundedRect(swatchRect, radius: swatchHeight * 0.25, color: color)
    }
}

/// Renderiza PNG con dimensiones exactas, evitando el escalado Retina de NSImage.lockFocus().
func renderPNG(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = context
    context?.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    drawIconContent(side: CGFloat(pixels))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for spec in iconSpecs {
    guard let png = renderPNG(pixels: spec.pixels) else {
        fputs("Error renderizando \(spec.filename)\n", stderr)
        exit(1)
    }
    try png.write(to: outDir.appendingPathComponent(spec.filename))
    print("Wrote \(spec.filename) (\(spec.pixels)x\(spec.pixels))")
}