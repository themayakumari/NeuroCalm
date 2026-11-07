//
//  ContentService.swift
//  NeuroCalm
//
//  Practices and guided audio come from one JSON file in Firebase Storage
//  (content/content.json), so they can be changed without an app update:
//
//    {
//      "practices": [ ...same fields as Resources/Knowledge/practices.json... ],
//      "tracks": [
//        { "id": "humming-bee-guided", "title": "Humming Bee Breath",
//          "subtitle": "Guided practice", "duration": "6:00",
//          "category": "practice",            // relaxation / breathing / practice
//          "file": "audio/humming-bee.mp3",   // path in Firebase Storage
//          "practiceIds": ["bhramari"], "order": 1, "version": 1 }
//      ]
//    }
//
//  At launch the app downloads the file and saves it on the phone. Practices
//  switch to the new list on the next launch; audio tracks update right away.
//  If the file can't be downloaded or has a mistake in it, the app keeps the
//  last good copy (or the bundled practices.json + tracks).
//

import Foundation
import FirebaseCore

@MainActor
final class ContentService: ObservableObject {
    static let shared = ContentService()

    /// Where the content file lives in Firebase Storage.
    static let contentPath = "content/content.json"

    @Published private(set) var tracks: [MeditationTrack]

    private var isRefreshing = false
    private var lastRefresh: Date?

    private init() {
        tracks = MeditationLibrary.merge(bundled: MeditationLibrary.all,
                                         remote: Self.savedContent()?.tracks ?? [])
    }

    /// Tracks for the Relax screen's main list.
    var relaxationTracks: [MeditationTrack] { tracks.filter { $0.category == .relaxation } }

    /// Tracks for the Relax screen's "Guided breathing" section.
    var breathingTracks: [MeditationTrack] { tracks.filter { $0.category == .breathing } }

    /// Tracks that play under a practice: the ones the practice lists in
    /// `audioTrackIds`, plus any track that names the practice in `practiceIds`.
    func tracks(for practice: Practice) -> [MeditationTrack] {
        let ids = Set(practice.audioTrackIds ?? [])
        return tracks.filter { ids.contains($0.id) || $0.practiceIds.contains(practice.id) }
    }

    /// Downloads the latest content file and saves it for the next launch.
    /// Quietly keeps the current content if offline or the file is broken.
    func refresh() async {
        if isRefreshing { return }
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 5 * 60 { return }
        guard let bucket = FirebaseApp.app()?.options.storageBucket,
              let url = Self.storageURL(path: Self.contentPath, bucket: bucket) else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let content = RemoteContent.decode(data, bucket: bucket) else {
                print("⚠️ content.json couldn't be read; keeping the last good copy.")
                return
            }
            lastRefresh = Date()
            if let saved = Self.savedFileURL {
                try? data.write(to: saved, options: .atomic)
            }
            tracks = MeditationLibrary.merge(bundled: MeditationLibrary.all, remote: content.tracks)
            AudioCache.removeUnused(keeping: tracks)
        } catch {
            print("⚠️ Couldn't download content: \(error.localizedDescription)")
        }
    }

    // MARK: - Saved copy

    nonisolated private static var savedFileURL: URL? {
        AudioCache.appSupportFolder?.appendingPathComponent("content.json")
    }

    /// The last good content file saved on the phone, if any.
    nonisolated static func savedContent() -> RemoteContent? {
        guard let url = savedFileURL, let data = try? Data(contentsOf: url),
              let bucket = FirebaseApp.app()?.options.storageBucket else { return nil }
        return RemoteContent.decode(data, bucket: bucket)
    }

    /// A public download link for a file in Firebase Storage. Works without a
    /// sign-in token because the Storage rules allow reading content/ and audio/.
    nonisolated static func storageURL(path: String, bucket: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")   // Storage wants the whole path as one encoded name
        guard let name = path.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(name)?alt=media")
    }
}

// MARK: - The content file

struct RemoteContent {
    var practices: [Practice]
    var tracks: [MeditationTrack]

    /// Reads a content file. One broken practice or track is skipped rather
    /// than throwing the whole file away. Returns nil if nothing usable is in it.
    static func decode(_ data: Data, bucket: String) -> RemoteContent? {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        let practices = file.practices?.compactMap(\.value) ?? []
        let tracks = file.tracks?.compactMap { $0.value?.track(bucket: bucket) } ?? []
        guard !practices.isEmpty || !tracks.isEmpty else { return nil }
        return RemoteContent(practices: practices, tracks: tracks)
    }

    private struct File: Decodable {
        let practices: [Lenient<Practice>]?
        let tracks: [Lenient<Track>]?
    }

    /// Decodes one entry, or nil if that entry has a mistake.
    private struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    private struct Track: Decodable {
        let id: String
        let title: String
        let subtitle: String?
        let duration: String?
        let category: String?
        let file: String?          // Storage path ("audio/x.mp3") or a full https link
        let practiceIds: [String]?
        let order: Int?
        let version: Int?
        let active: Bool?

        func track(bucket: String) -> MeditationTrack? {
            guard !id.isEmpty, !title.isEmpty else { return nil }
            var remoteURL: URL?
            if let file, !file.isEmpty {
                if file.hasPrefix("https://") {
                    remoteURL = URL(string: file)
                } else {
                    remoteURL = ContentService.storageURL(path: file, bucket: bucket)
                }
                guard remoteURL != nil else { return nil }
            }
            var track = MeditationTrack(
                id: id,
                title: title,
                subtitle: subtitle ?? "",
                durationLabel: duration ?? ""
            )
            if let raw = category, let category = MeditationTrack.Category(rawValue: raw.lowercased()) {
                track.category = category
            }
            track.remoteURL = remoteURL
            if let ext = remoteURL?.pathExtension, !ext.isEmpty {
                track.fileExtension = ext.lowercased()
            }
            track.practiceIds = practiceIds ?? []
            track.order = order ?? 0
            track.version = max(version ?? 1, 1)
            track.isActive = active ?? true
            return track
        }
    }
}

/// Downloaded audio files, kept in Application Support (not Caches, so iOS
/// doesn't clear them when storage is low) and left out of iCloud backups.
enum AudioCache {
    static var appSupportFolder: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var folder: URL? {
        guard var dir = appSupportFolder?.appendingPathComponent("Audio", isDirectory: true) else { return nil }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    /// The file name for a track's hosted file. The version is part of the
    /// name, so bumping `version` in the content file makes phones fetch it again.
    static func fileName(for track: MeditationTrack) -> String {
        "\(track.id)-v\(track.version).\(track.fileExtension)"
    }

    /// The downloaded copy of a track's hosted file, if it's on the phone.
    static func cachedFile(for track: MeditationTrack) -> URL? {
        guard track.remoteURL != nil, let folder else { return nil }
        let file = folder.appendingPathComponent(fileName(for: track))
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// Downloads a track's hosted file (once) and returns where it was saved.
    static func download(_ track: MeditationTrack) async throws -> URL {
        if let cached = cachedFile(for: track) { return cached }
        guard let remote = track.remoteURL, let folder else { throw URLError(.fileDoesNotExist) }

        let (temp, response) = try await URLSession.shared.download(from: remote)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: temp)
            throw URLError(.badServerResponse)
        }
        let destination = folder.appendingPathComponent(fileName(for: track))
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    /// Deletes downloads for tracks that were removed or replaced by a new version.
    static func removeUnused(keeping tracks: [MeditationTrack]) {
        guard let folder,
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        let keep = Set(tracks.filter { $0.remoteURL != nil }.map(fileName(for:)))
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
    }
}
