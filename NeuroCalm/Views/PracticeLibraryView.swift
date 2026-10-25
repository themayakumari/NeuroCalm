//
//  PracticeLibraryView.swift
//  NeuroCalm
//
//  A browsable library of traditional yoga breathing and relaxation practices,
//  each explained in short, teen-friendly language, opening a full "About this
//  practice" detail. Content comes from the KnowledgeBase (practices.json).
//

import SwiftUI

struct PracticeLibraryView: View {
    private let practices = KnowledgeBase.shared.practices

    /// Category order for the sections.
    private let categoryOrder = [
        "Breathing techniques",
        "Relaxation techniques",
        "Short meditation practices"
    ]

    /// Practices grouped into ordered category sections.
    private var groups: [(category: String, items: [Practice])] {
        let byCategory = Dictionary(grouping: practices, by: { $0.category })
        var ordered = categoryOrder.compactMap { cat in
            byCategory[cat].map { (category: cat, items: $0) }
        }
        // Include any categories not in the known order, at the end.
        for (cat, items) in byCategory where !categoryOrder.contains(cat) {
            ordered.append((category: cat, items: items))
        }
        return ordered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Calming yoga breathing and relaxation practices — tap one to learn it.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                ForEach(groups, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.category)
                            .font(AppTheme.mono(11))
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.mist)

                        ForEach(group.items) { practice in
                            NavigationLink {
                                PracticeDetailView(practice: practice)
                            } label: {
                                row(practice)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Practices")
    }

    private func row(_ practice: Practice) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(practice.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.cream)
                Text(practice.teenFriendly)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mist)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.mist)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }
}

#Preview {
    NavigationStack { PracticeLibraryView() }
        .preferredColorScheme(.dark)
}
