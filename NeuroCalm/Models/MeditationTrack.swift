//
//  MeditationTrack.swift
//  NeuroCalm
//
//  The bundled guided-relaxation audio library (Deep Relaxation + Yoga Nap).
//  Tracks are shipped inside the app for now; a hosted/streamed catalog
//  can replace this list later without changing the player or the UI.
//

import Foundation

struct MeditationTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    let resourceName: String        // file in the bundle, without extension
    let fileExtension: String

    /// The bundled file URL, if present.
    var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }
}

enum MeditationLibrary {
    static let all: [MeditationTrack] = [
        MeditationTrack(
            id: "shavasana-1",
            title: "Deep Relaxation · Practice 1",
            subtitle: "Progressive relaxation",
            durationLabel: "5:30",
            resourceName: "shavasana-1",
            fileExtension: "mp3"
        ),
        MeditationTrack(
            id: "shavasana-2",
            title: "Deep Relaxation · Practice 2",
            subtitle: "Progressive relaxation",
            durationLabel: "8:00",
            resourceName: "shavasana-2",
            fileExtension: "mp3"
        ),
        MeditationTrack(
            id: "shavasana-3",
            title: "Deep Relaxation · Practice 3",
            subtitle: "Progressive relaxation",
            durationLabel: "13:00",
            resourceName: "shavasana-3",
            fileExtension: "mp3"
        ),
        MeditationTrack(
            id: "shavasana-powernap",
            title: "Power Nap",
            subtitle: "Deep Relaxation · Practice 4",
            durationLabel: "12:15",
            resourceName: "shavasana-powernap",
            fileExtension: "mp3"
        ),
        MeditationTrack(
            id: "yoga-nap",
            title: "Yoga Nap",
            subtitle: "Deep guided rest",
            durationLabel: "~15 min",
            resourceName: "yoga-nap",
            fileExtension: "mp3"
        )
    ]
}
