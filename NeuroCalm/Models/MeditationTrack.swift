//
//  MeditationTrack.swift
//  NeuroCalm
//
//  The guided audio library. A few tracks ship inside the app so it works on
//  first launch with no internet; more are listed in the content file in
//  Firebase Storage and downloaded on first play (see ContentService).
//

import Foundation

struct MeditationTrack: Identifiable, Hashable {
    /// Where a track shows up in the app.
    enum Category: String {
        case relaxation     // the Relax screen
        case breathing      // the Relax screen's "Guided breathing" section
        case practice       // only inside a practice's "Guided audio"
    }

    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    var category: Category = .relaxation
    var resourceName: String? = nil     // file in the bundle, without extension
    var fileExtension: String = "mp3"
    var remoteURL: URL? = nil           // hosted file in Firebase Storage
    var practiceIds: [String] = []      // practices this track plays under
    var order: Int = 0
    var version: Int = 1                // bump to make phones download a new file
    var isActive: Bool = true

    /// The bundled file URL, if present.
    var bundledURL: URL? {
        guard let resourceName else { return nil }
        return Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
            ?? Bundle.main.url(forResource: resourceName, withExtension: "mp3")
    }

    /// A file on the phone that can play right now: a downloaded copy of the
    /// hosted file first (it may be a newer recording), else the bundled one.
    var url: URL? {
        AudioCache.cachedFile(for: self) ?? bundledURL
    }

    /// True when a hosted file exists that hasn't been downloaded yet.
    var needsDownload: Bool {
        remoteURL != nil && AudioCache.cachedFile(for: self) == nil
    }

    /// Can this track be played at all (now, or after a download)?
    var isPlayable: Bool {
        bundledURL != nil || remoteURL != nil
    }
}

enum MeditationLibrary {
    /// Tracks shipped inside the app.
    static let all: [MeditationTrack] = [
        MeditationTrack(
            id: "shavasana-1",
            title: "Deep Relaxation · Practice 1",
            subtitle: "Progressive relaxation",
            durationLabel: "5:30",
            resourceName: "shavasana-1",
            fileExtension: "mp3",
            order: 1
        ),
        MeditationTrack(
            id: "shavasana-2",
            title: "Deep Relaxation · Practice 2",
            subtitle: "Progressive relaxation",
            durationLabel: "8:00",
            resourceName: "shavasana-2",
            fileExtension: "mp3",
            order: 2
        ),
        MeditationTrack(
            id: "shavasana-3",
            title: "Deep Relaxation · Practice 3",
            subtitle: "Progressive relaxation",
            durationLabel: "13:00",
            resourceName: "shavasana-3",
            fileExtension: "mp3",
            order: 3
        ),
        MeditationTrack(
            id: "shavasana-powernap",
            title: "Power Nap",
            subtitle: "Deep Relaxation · Practice 4",
            durationLabel: "12:15",
            resourceName: "shavasana-powernap",
            fileExtension: "mp3",
            order: 4
        ),
        MeditationTrack(
            id: "yoga-nap",
            title: "Yoga Nap",
            subtitle: "Deep guided rest",
            durationLabel: "~15 min",
            resourceName: "yoga-nap",
            fileExtension: "mp3",
            order: 5
        )
    ]

    /// Combines the bundled tracks with the content file's list. An entry
    /// with the same id as a bundled track updates it (new title, or a better
    /// recording via `file`) and keeps the bundled file as the offline backup;
    /// `active: false` hides a track. Entries with no file anywhere are dropped.
    static func merge(bundled: [MeditationTrack], remote: [MeditationTrack]) -> [MeditationTrack] {
        var byId: [String: MeditationTrack] = [:]
        for track in bundled { byId[track.id] = track }
        for var track in remote {
            if let existing = byId[track.id] {
                track.resourceName = existing.resourceName
                if track.remoteURL == nil { track.fileExtension = existing.fileExtension }
                if track.subtitle.isEmpty, track.durationLabel.isEmpty, track.order == 0 {
                    // A bare entry (e.g. only `active: false`) keeps the bundled details.
                    track = MeditationTrack(
                        id: existing.id, title: track.title, subtitle: existing.subtitle,
                        durationLabel: existing.durationLabel, category: existing.category,
                        resourceName: existing.resourceName, fileExtension: existing.fileExtension,
                        remoteURL: track.remoteURL, practiceIds: track.practiceIds,
                        order: existing.order, version: track.version, isActive: track.isActive
                    )
                }
            }
            byId[track.id] = track
        }
        return byId.values
            .filter { $0.isActive && ($0.resourceName != nil || $0.remoteURL != nil) }
            .sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }
}
