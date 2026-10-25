//
//  ShareCardView.swift
//  NeuroCalm
//
//  A branded card a student can share to Instagram, Messages, etc. Rendered to
//  an image and handed to the iOS share sheet — no third-party SDK or keys.
//

import SwiftUI
import UIKit

struct ShareCardView: View {
    let headline: String
    let subline: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 46))
                .foregroundStyle(AppTheme.sage)
            Text(headline)
                .font(AppTheme.display(34))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subline)
                .font(.headline)
                .foregroundStyle(AppTheme.mist)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 2) {
                Text("NeuroCalm")
                    .font(AppTheme.mono(15, weight: .semibold))
                    .foregroundStyle(AppTheme.sage)
                Text("student stress & focus companion")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(30)
        .frame(width: 360, height: 360)
        .background(
            LinearGradient(
                colors: [AppTheme.twilight2, AppTheme.background],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    /// Render this card to a shareable image.
    @MainActor
    static func render(headline: String, subline: String) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(headline: headline, subline: subline))
        renderer.scale = 3   // ~1080px — crisp for Instagram
        return renderer.uiImage
    }
}

/// Presents the iOS share sheet for the given items (image + caption).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareCardView(headline: "🔥 5-day calm streak", subline: "Taking care of my mind.")
        .preferredColorScheme(.dark)
}
