//
//  TodoBorderPulse.swift
//  boringNotch
//
//  A thin amber outline that pulses around the closed notch while music
//  hides the todo number and unfinished todos remain.
//

import SwiftUI

struct TodoBorderPulse<S: Shape>: View {
    let shape: S
    @State private var pulsing = false

    var body: some View {
        shape
            .stroke(Color.orange, lineWidth: 3) // half is clipped away -> ~1.5pt visible
            .clipShape(shape)
            .opacity(pulsing ? 0.9 : 0.25)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .allowsHitTesting(false)
            .onAppear { pulsing = true }
            .onDisappear { pulsing = false }
    }
}
