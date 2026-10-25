//
//  CalmRingView.swift
//  NeuroCalm
//
//  The daily "Calm Ring" — an original circular goal that fills as the student
//  breathes, relaxes, or checks in. Not a step ring; it rewards calming, not
//  activity.
//

import SwiftUI

struct CalmRingView: View {
    let progress: Double        // 0…1
    let closed: Bool
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.twilight2, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    AngularGradient(
                        colors: [AppTheme.sage, AppTheme.sage.opacity(0.7), AppTheme.ember],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                if closed {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.26, weight: .bold))
                        .foregroundStyle(AppTheme.sage)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(AppTheme.display(size * 0.24))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("calm")
                        .font(.system(size: size * 0.09))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

#Preview {
    HStack(spacing: 24) {
        CalmRingView(progress: 0.5, closed: false)
        CalmRingView(progress: 1.0, closed: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
