#!/usr/bin/env swift

import SwiftUI
import AppKit

struct IconView: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width

            let bgRect = CGRect(origin: .zero, size: canvasSize)
            context.fill(
                Path(roundedRect: bgRect, cornerRadius: 0),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.18, green: 0.08, blue: 0.45),
                        Color(red: 0.12, green: 0.38, blue: 0.85)
                    ]),
                    startPoint: .init(x: 0, y: 0),
                    endPoint: .init(x: s, y: s)
                )
            )

            let monitorWidth = s * 0.58
            let monitorHeight = s * 0.38
            let monitorX = (s - monitorWidth) / 2
            let monitorY = s * 0.16
            let monitorRect = CGRect(x: monitorX, y: monitorY, width: monitorWidth, height: monitorHeight)
            let monitorRadius = s * 0.03

            context.fill(
                Path(roundedRect: monitorRect, cornerRadius: monitorRadius),
                with: .color(Color(white: 0.12))
            )

            let screenInset = s * 0.025
            let screenRect = monitorRect.insetBy(dx: screenInset, dy: screenInset)
            context.fill(
                Path(roundedRect: screenRect, cornerRadius: monitorRadius * 0.5),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.15, green: 0.25, blue: 0.5),
                        Color(red: 0.08, green: 0.15, blue: 0.35)
                    ]),
                    startPoint: .init(x: screenRect.minX, y: screenRect.minY),
                    endPoint: .init(x: screenRect.maxX, y: screenRect.maxY)
                )
            )

            let standWidth = s * 0.06
            let standHeight = s * 0.08
            let standX = (s - standWidth) / 2
            let standY = monitorRect.maxY
            context.fill(
                Path(CGRect(x: standX, y: standY, width: standWidth, height: standHeight)),
                with: .color(Color(white: 0.15))
            )

            let baseWidth = s * 0.18
            let baseHeight = s * 0.025
            let baseX = (s - baseWidth) / 2
            let baseY = standY + standHeight
            context.fill(
                Path(roundedRect: CGRect(x: baseX, y: baseY, width: baseWidth, height: baseHeight),
                     cornerRadius: baseHeight / 2),
                with: .color(Color(white: 0.15))
            )

            let arrowCenter = CGPoint(x: s * 0.5, y: s * 0.72)
            let arrowRadius = s * 0.14
            let arrowLineWidth = s * 0.03

            let glowRect = CGRect(
                x: arrowCenter.x - arrowRadius * 1.6,
                y: arrowCenter.y - arrowRadius * 1.6,
                width: arrowRadius * 3.2,
                height: arrowRadius * 3.2
            )
            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.3),
                        Color.clear
                    ]),
                    center: arrowCenter,
                    startRadius: 0,
                    endRadius: arrowRadius * 1.6
                )
            )

            let cyanColor = Color(red: 0.3, green: 0.8, blue: 1.0)

            var topArc = Path()
            topArc.addArc(
                center: arrowCenter,
                radius: arrowRadius,
                startAngle: .degrees(-30),
                endAngle: .degrees(180),
                clockwise: true
            )
            context.stroke(topArc, with: .color(cyanColor), lineWidth: arrowLineWidth)

            let topArrowTip = CGPoint(
                x: arrowCenter.x + arrowRadius * cos(.pi * (-30) / 180),
                y: arrowCenter.y + arrowRadius * sin(.pi * (-30) / 180)
            )
            var topArrowHead = Path()
            let headSize = s * 0.05
            topArrowHead.move(to: topArrowTip)
            topArrowHead.addLine(to: CGPoint(x: topArrowTip.x - headSize, y: topArrowTip.y - headSize * 0.4))
            topArrowHead.addLine(to: CGPoint(x: topArrowTip.x - headSize * 0.2, y: topArrowTip.y + headSize * 0.8))
            topArrowHead.closeSubpath()
            context.fill(topArrowHead, with: .color(cyanColor))

            var bottomArc = Path()
            bottomArc.addArc(
                center: arrowCenter,
                radius: arrowRadius,
                startAngle: .degrees(150),
                endAngle: .degrees(0),
                clockwise: true
            )
            context.stroke(bottomArc, with: .color(cyanColor), lineWidth: arrowLineWidth)

            let bottomArrowTip = CGPoint(
                x: arrowCenter.x + arrowRadius * cos(.pi * 150 / 180),
                y: arrowCenter.y + arrowRadius * sin(.pi * 150 / 180)
            )
            var bottomArrowHead = Path()
            bottomArrowHead.move(to: bottomArrowTip)
            bottomArrowHead.addLine(to: CGPoint(x: bottomArrowTip.x + headSize, y: bottomArrowTip.y + headSize * 0.4))
            bottomArrowHead.addLine(to: CGPoint(x: bottomArrowTip.x + headSize * 0.2, y: bottomArrowTip.y - headSize * 0.8))
            bottomArrowHead.closeSubpath()
            context.fill(bottomArrowHead, with: .color(cyanColor))
        }
        .frame(width: size, height: size)
    }
}

let _ = NSApplication.shared

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

let files: [(String, Int)] = [
    ("DisplayIcon16.png", 16),
    ("DisplayIcon32 1.png", 32),
    ("DisplayIcon32.png", 32),
    ("DisplayIcon-64.png", 64),
    ("DisplayIcon-128.png", 128),
    ("DisplayIcon-256 1.png", 256),
    ("DisplayIcon-256.png", 256),
    ("DisplayIcon-512 1.png", 512),
    ("DisplayIcon-512.png", 512),
    ("DisplayIcon.png", 1024),
]

@MainActor
func generateIcons() {
    var generated = 0
    for (filename, pixels) in files {
        let view = IconView(size: CGFloat(pixels))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0

        guard let cgImage = renderer.cgImage else {
            print("FAIL: \(filename) — no cgImage")
            continue
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("FAIL: \(filename) — no PNG data")
            continue
        }

        let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")
        do {
            try pngData.write(to: url)
            print("OK: \(filename) (\(pixels)px) — \(pngData.count) bytes")
            generated += 1
        } catch {
            print("FAIL: \(filename) — \(error)")
        }
    }
    print("\nGenerated \(generated)/\(files.count) icons")
    exit(generated == files.count ? 0 : 1)
}

Task { @MainActor in
    generateIcons()
}

RunLoop.main.run()
