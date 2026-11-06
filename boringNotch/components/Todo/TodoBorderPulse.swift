//
//  TodoBorderPulse.swift
//  boringNotch
//
//  A soft glow (album color, amber fallback) that pulses along the bottom of the closed notch while
//  music hides the todo number and unfinished todos remain. The outline
//  fades out toward the top, so the screen edge and the flared top corners
//  stay clean.
//

import AppKit
import SwiftUI

struct TodoBorderPulse<S: Shape>: View {
    let shape: S
    /// Usually the album-art average color, same as the music visualizer.
    var tint: NSColor
    @State private var pulsing = false

    private static var fallback: Color { Color(red: 1.0, green: 0.62, blue: 0.04) }

    /// The tint, or amber if it is too dark to show against the black notch.
    private var glowColor: Color {
        guard let rgb = tint.usingColorSpace(.sRGB) else { return Self.fallback }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        guard brightness >= 0.25 else { return Self.fallback }
        // Lift dim colors a bit so the glow stays visible.
        return Color(nsColor: NSColor(hue: hue, saturation: saturation,
                                      brightness: max(brightness, 0.75), alpha: 1))
    }

    /// Transparent at the top, fully visible at the bottom edge.
    private var bottomFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.45),
                .init(color: .white, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Soft outer glow below the notch.
            shape
                .stroke(glowColor, lineWidth: 4)
                .blur(radius: 4)
                .opacity(0.6)
            // Thin crisp line just inside the edge (~1pt visible after clipping).
            shape
                .stroke(glowColor, lineWidth: 2)
                .clipShape(shape)
        }
        // Extend the mask past the edges so the blurred glow below isn't cut off.
        .mask { bottomFade.padding(-10) }
        .opacity(pulsing ? 0.85 : 0.2)
        .animation(
            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
            value: pulsing
        )
        .allowsHitTesting(false)
        .onAppear { pulsing = true }
        .onDisappear { pulsing = false }
    }
}
