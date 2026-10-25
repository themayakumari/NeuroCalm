//
//  SupportView.swift
//  NeuroCalm
//
//  Crisis and mental-health support resources. NeuroCalm is a wellbeing
//  companion, not a treatment tool — this screen makes real human help one tap
//  away, which is a basic responsibility for any app in this space. Always
//  reachable from Home and Settings. US resources; phone/text links open the
//  dialer/Messages on a real device.
//

import SwiftUI

struct SupportView: View {
    struct Resource: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let actionLabel: String
        let systemImage: String
        let url: URL?
        let tint: Color
    }

    // Ordered gentlest first-step → most urgent, so the simplest way to reach
    // out (a text) comes first and emergency services come last.
    private let resources: [Resource] = [
        Resource(
            name: "Crisis Text Line",
            detail: "Text HOME to 741741 to reach a trained crisis counselor by text.",
            actionLabel: "Text 741741",
            systemImage: "message.fill",
            url: URL(string: "sms:741741"),
            tint: AppTheme.primaryBlue
        ),
        Resource(
            name: "988 Suicide & Crisis Lifeline",
            detail: "Free, confidential support 24/7 for anyone in distress. Call or text.",
            actionLabel: "Call or text 988",
            systemImage: "phone.fill",
            url: URL(string: "tel:988"),
            tint: AppTheme.sage
        ),
        Resource(
            name: "The Trevor Project",
            detail: "Crisis support for LGBTQ+ young people, 24/7.",
            actionLabel: "Call 1-866-488-7386",
            systemImage: "heart.fill",
            url: URL(string: "tel:18664887386"),
            tint: AppTheme.ember
        ),
        Resource(
            name: "Emergency (911)",
            detail: "If you or someone else is in immediate danger, call 911.",
            actionLabel: "Call 911",
            systemImage: "cross.case.fill",
            url: URL(string: "tel:911"),
            tint: AppTheme.warmCoral
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                ForEach(resources) { r in
                    resourceCard(r)
                }

                Text("NeuroCalm is a wellbeing companion, not medical care or a crisis service. If something feels serious, please reach out to one of the lines above or a trusted adult — a parent, teacher, or school counselor.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Get support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sage)
            Text("You're not alone")
                .font(AppTheme.display(26))
                .foregroundStyle(AppTheme.cream)
            Text("If you're going through a hard time, talking to someone helps. Reaching out is a sign of strength, not weakness.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mist)
        }
        .padding(.bottom, 4)
    }

    private func resourceCard(_ r: Resource) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(r.tint.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: r.systemImage)
                        .font(.title3).foregroundStyle(r.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name)
                        .font(.headline).foregroundStyle(AppTheme.cream)
                    Text(r.detail)
                        .font(.caption).foregroundStyle(AppTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let url = r.url {
                Link(destination: url) {
                    Text(r.actionLabel)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(r.tint)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }
}

#Preview {
    NavigationStack { SupportView() }
        .preferredColorScheme(.dark)
}
