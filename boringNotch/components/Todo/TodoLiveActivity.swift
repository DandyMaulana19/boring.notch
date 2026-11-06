//
//  TodoLiveActivity.swift
//  boringNotch
//

import SwiftUI

/// Closed-notch indicator: checklist icon on the left, the number of the
/// next unfinished todo on the right, pulsing. Mirrors the layout of
/// `BoringFaceAnimation()` so it fits the same chin width.
struct TodoLiveActivity: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var manager = TodoManager.shared
    @State private var pulsing = false

    var body: some View {
        if let number = manager.nextPendingNumber {
            let side = max(0, vm.effectiveClosedNotchHeight - 12)
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: side, height: side)

                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)

                Text("\(number)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: side, height: side)
                    .opacity(pulsing ? 0.45 : 1.0)
                    .scaleEffect(pulsing ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulsing
                    )
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
            .onAppear { pulsing = true }
            .onDisappear { pulsing = false }
        }
    }
}
