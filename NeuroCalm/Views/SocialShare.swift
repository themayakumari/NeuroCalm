//
//  SocialShare.swift
//  NeuroCalm
//
//  Branded social buttons for the "Share your progress" card. Instagram gets a
//  direct hand-off to Stories (the one platform that lets an app pass an image
//  in); every other button opens the iOS share sheet, which surfaces that app
//  if it's installed. This uses no third-party SDKs or API keys — just the
//  public URL scheme and the standard share sheet.
//
//  Note: SF Symbols ships no brand logos, so the glyphs below are drawn with
//  simple shapes + brand colors (recognizable, and no trademarked artwork
//  bundled in the app).
//

import SwiftUI
import UIKit

enum SocialPlatform: String, CaseIterable, Identifiable {
    case instagram, snapchat, tiktok, whatsapp, x, facebook, messages, more
    var id: String { rawValue }

    var label: String {
        switch self {
        case .instagram: return "Instagram"
        case .snapchat:  return "Snapchat"
        case .tiktok:    return "TikTok"
        case .whatsapp:  return "WhatsApp"
        case .x:         return "X"
        case .facebook:  return "Facebook"
        case .messages:  return "Messages"
        case .more:      return "More"
        }
    }
}

enum SocialShare {
    /// Hand an image straight to Instagram Stories as the background. Returns
    /// false if Instagram isn't installed so the caller can fall back.
    @MainActor
    static func shareToInstagramStories(image: UIImage) -> Bool {
        let appID = Bundle.main.bundleIdentifier ?? "NeuroCalm"
        guard let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
              UIApplication.shared.canOpenURL(url),
              let data = image.pngData() else { return false }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )
        UIApplication.shared.open(url)
        return true
    }
}

// MARK: - Tile

struct SocialTile: View {
    let platform: SocialPlatform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(background)
                    glyph
                }
                .frame(width: 56, height: 56)
                Text(platform.label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mist)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share to \(platform.label)")
    }

    // Brand backgrounds.
    private var background: some ShapeStyle {
        switch platform {
        case .instagram:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0x833AB4), Color(hex: 0xE1306C),
                         Color(hex: 0xF77737), Color(hex: 0xFCAF45)],
                startPoint: .bottomLeading, endPoint: .topTrailing))
        case .snapchat: return AnyShapeStyle(Color(hex: 0xFFFC00))
        case .tiktok:   return AnyShapeStyle(Color.black)
        case .whatsapp: return AnyShapeStyle(Color(hex: 0x25D366))
        case .x:        return AnyShapeStyle(Color.black)
        case .facebook: return AnyShapeStyle(Color(hex: 0x1877F2))
        case .messages:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0x5BF675), Color(hex: 0x1FAD53)],
                startPoint: .top, endPoint: .bottom))
        case .more:     return AnyShapeStyle(Color(hex: 0x3A3A3C))
        }
    }

    // Brand glyphs (drawn, not bundled artwork).
    @ViewBuilder private var glyph: some View {
        switch platform {
        case .instagram:
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white, lineWidth: 3).frame(width: 30, height: 30)
                Circle().stroke(.white, lineWidth: 3).frame(width: 14, height: 14)
                Circle().fill(.white).frame(width: 4, height: 4).offset(x: 9, y: -9)
            }
        case .snapchat:
            SnapGhost().fill(.white).frame(width: 28, height: 30)
                .shadow(color: .black.opacity(0.12), radius: 0.5)
        case .tiktok:
            ZStack {
                noteGlyph(Color(hex: 0x25F4EE)).offset(x: -1.6, y: -1.6)
                noteGlyph(Color(hex: 0xFE2C55)).offset(x: 1.6, y: 1.6)
                noteGlyph(.white)
            }
        case .whatsapp:
            Image(systemName: "phone.fill").font(.system(size: 24)).foregroundStyle(.white)
        case .x:
            Image(systemName: "xmark").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
        case .facebook:
            Text("f").font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white).offset(y: 2)
        case .messages:
            Image(systemName: "message.fill").font(.system(size: 24)).foregroundStyle(.white)
        case .more:
            Image(systemName: "ellipsis").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func noteGlyph(_ color: Color) -> some View {
        Image(systemName: "music.note").font(.system(size: 24, weight: .bold)).foregroundStyle(color)
    }
}

/// A simple Snapchat-style ghost: rounded top, scalloped bottom.
struct SnapGhost: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.9))
        p.addLine(to: CGPoint(x: 0, y: h * 0.45))
        p.addArc(center: CGPoint(x: w / 2, y: h * 0.45),
                 radius: w / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: w, y: h * 0.9))
        // Scalloped bottom: three little bumps back to the start.
        let bumps = 3
        let bw = w / CGFloat(bumps)
        for i in 0..<bumps {
            let toX = w - CGFloat(i + 1) * bw
            p.addQuadCurve(to: CGPoint(x: toX, y: h * 0.9),
                           control: CGPoint(x: toX + bw / 2, y: h * 1.05))
        }
        p.closeSubpath()
        return p
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
