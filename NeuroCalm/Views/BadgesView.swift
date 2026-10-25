//
//  BadgesView.swift
//  NeuroCalm
//
//  A grid of achievement badges — earned ones lit up, the rest a locked hint
//  of what to aim for.
//

import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query private var logs: [CalmLog]

    private var earned: Set<String> {
        BadgeLogic.earned(logs: logs)
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(earned.count) of \(BadgeCatalog.all.count) earned")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(BadgeCatalog.all) { badge in
                        card(badge, unlocked: earned.contains(badge.id))
                    }
                }
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Badges")
    }

    private func card(_ badge: Badge, unlocked: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? AppTheme.sage.opacity(0.18) : AppTheme.twilight2)
                    .frame(width: 64, height: 64)
                Image(systemName: unlocked ? badge.symbol : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(unlocked ? AppTheme.sage : AppTheme.textSecondary)
            }
            Text(badge.title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(unlocked ? AppTheme.cream : AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text(badge.detail)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.twilight2.opacity(unlocked ? 1 : 0.5))
        .cornerRadius(AppTheme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(unlocked ? AppTheme.sage.opacity(0.4) : .clear, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack { BadgesView() }
        .modelContainer(for: CalmLog.self, inMemory: true)
        .preferredColorScheme(.dark)
}
