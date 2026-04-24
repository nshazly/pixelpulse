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
                        Color(red: 0.0, green: 0.55, blue: 0.55),
                        Color(red: 0.05, green: 0.15, blue: 0.55)
                    ]),
                    startPoint: .init(x: 0, y: 0),
                    endPoint: .init(x: s, y: s)
                )
            )

            let center = CGPoint(x: s * 0.5, y: s * 0.48)

            let arcColor = Color(red: 0.3, green: 0.9, blue: 0.9)
            for i in 0..<4 {
                let radius = s * (0.28 + Double(i) * 0.08)
                let opacity = 0.5 - Double(i) * 0.1
                let lineWidth = s * (0.02 - Double(i) * 0.003)

                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-55),
                    endAngle: .degrees(55),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(arcColor.opacity(opacity)),
                    lineWidth: lineWidth
                )

                var arcLeft = Path()
                arcLeft.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(125),
                    endAngle: .degrees(235),
                    clockwise: false
                )
                context.stroke(
                    arcLeft,
                    with: .color(arcColor.opacity(opacity)),
                    lineWidth: lineWidth
                )
            }

            let fontSize = s * 0.32
            let text = Text("Hz")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            context.draw(
                context.resolve(text),
                at: center,
                anchor: .center
            )

            let pulseY = center.y + s * 0.22
            let pulseLeft = s * 0.25
            let pulseRight = s * 0.75
            let pulseMid = s * 0.5
            let pulseAmp = s * 0.06

            var pulse = Path()
            pulse.move(to: CGPoint(x: pulseLeft, y: pulseY))
            pulse.addLine(to: CGPoint(x: pulseMid - s * 0.1, y: pulseY))
            pulse.addLine(to: CGPoint(x: pulseMid - s * 0.05, y: pulseY - pulseAmp))
            pulse.addLine(to: CGPoint(x: pulseMid, y: pulseY + pulseAmp))
            pulse.addLine(to: CGPoint(x: pulseMid + s * 0.05, y: pulseY - pulseAmp * 0.5))
            pulse.addLine(to: CGPoint(x: pulseMid + s * 0.1, y: pulseY))
            pulse.addLine(to: CGPoint(x: pulseRight, y: pulseY))

            context.stroke(
                pulse,
                with: .color(Color(red: 0.3, green: 0.9, blue: 0.9)),
                lineWidth: s * 0.02
            )
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
