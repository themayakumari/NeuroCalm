//
//  CalendarService.swift
//  NeuroCalm
//
//  Brings outside calendar events into the Planner, read-only, from two
//  sources the student can turn on:
//    1. The iPhone's built-in Calendar (EventKit) — whatever accounts are on
//       the device (Apple / Google / school).
//    2. A pasted .ics / webcal subscription link (e.g. a ParentSquare calendar).
//
//  Events are merged, de-duplicated by title+start, and shown alongside tasks
//  and deadlines. Nothing is written back to any calendar.
//

import Foundation
import EventKit

struct CalendarEvent: Identifiable, Hashable {
    enum Source: String { case device = "Calendar", feed = "ParentSquare" }

    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
    let source: Source

    var daysUntil: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                  to: cal.startOfDay(for: start)).day ?? 0
    }

    var whenLabel: String {
        if isAllDay {
            let d = daysUntil
            if d == 0 { return "Today" }
            if d == 1 { return "Tomorrow" }
            let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
            return f.string(from: start)
        }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d · h:mm a"
        return f.string(from: start)
    }
}

@MainActor
final class CalendarService: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var deviceAccessDenied = false
    @Published var feedError: String?
    @Published var isLoading = false

    private let store = EKEventStore()
    private let horizonDays = 30

    /// Pull from whichever sources are enabled and publish a merged list.
    func refresh(deviceEnabled: Bool, feedURL: String) async {
        // Don't trip the system permission prompt during UI tests.
        let underTest = ProcessInfo.processInfo.arguments.contains("UI-TESTING")
        isLoading = true
        defer { isLoading = false }

        var all: [CalendarEvent] = []
        if deviceEnabled && !underTest {
            all += await fetchDeviceEvents()
        }
        let trimmed = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !underTest, let url = URL(string: normalizedFeed(trimmed)) {
            all += await fetchFeedEvents(url)
        } else if trimmed.isEmpty {
            feedError = nil
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let horizon = cal.date(byAdding: .day, value: horizonDays, to: today) ?? today

        // Window to the next 30 days, de-dupe, sort.
        var seen = Set<String>()
        events = all
            .filter { $0.start >= today && $0.start <= horizon }
            .filter { seen.insert("\($0.title)|\($0.start.timeIntervalSince1970)").inserted }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Device calendar (EventKit)

    private func fetchDeviceEvents() async -> [CalendarEvent] {
        guard await requestAccess() else { deviceAccessDenied = true; return [] }
        deviceAccessDenied = false
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: horizonDays, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map {
            CalendarEvent(id: $0.eventIdentifier ?? UUID().uuidString,
                          title: ($0.title?.isEmpty == false ? $0.title! : "Event"),
                          start: $0.startDate, isAllDay: $0.isAllDay, source: .device)
        }
    }

    private func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }

    // MARK: - ICS / webcal feed

    private func normalizedFeed(_ s: String) -> String {
        if s.hasPrefix("webcal://") { return "https://" + s.dropFirst("webcal://".count) }
        return s
    }

    private func fetchFeedEvents(_ url: URL) async -> [CalendarEvent] {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                feedError = "Calendar link returned an error (\(http.statusCode))."
                return []
            }
            guard let text = String(data: data, encoding: .utf8) else {
                feedError = "Couldn't read that calendar link."
                return []
            }
            feedError = nil
            return ICSParser.parse(text)
        } catch {
            feedError = "Couldn't load that calendar link."
            return []
        }
    }
}

// MARK: - Minimal ICS parser

enum ICSParser {
    static func parse(_ raw: String) -> [CalendarEvent] {
        let text = unfold(raw)
        var events: [CalendarEvent] = []
        var inEvent = false
        var summary = ""
        var start: (date: Date, allDay: Bool)?

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l == "BEGIN:VEVENT" { inEvent = true; summary = ""; start = nil; continue }
            if l == "END:VEVENT" {
                if let s = start {
                    events.append(CalendarEvent(id: UUID().uuidString,
                                                title: summary.isEmpty ? "Event" : summary,
                                                start: s.date, isAllDay: s.allDay, source: .feed))
                }
                inEvent = false; continue
            }
            guard inEvent else { continue }
            if l.hasPrefix("SUMMARY") { summary = propertyValue(l) }
            else if l.hasPrefix("DTSTART") { start = parseDate(l) }
        }
        return events
    }

    /// RFC 5545 line unfolding: a line starting with a space/tab continues the
    /// previous one.
    private static func unfold(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
         .replacingOccurrences(of: "\r", with: "\n")
         .replacingOccurrences(of: "\n ", with: "")
         .replacingOccurrences(of: "\n\t", with: "")
    }

    private static func propertyValue(_ line: String) -> String {
        guard let idx = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: idx)...])
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parseDate(_ line: String) -> (Date, Bool)? {
        guard let idx = line.firstIndex(of: ":") else { return nil }
        let params = String(line[..<idx])            // e.g. DTSTART;VALUE=DATE;TZID=America/Los_Angeles
        let value = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        let isDateOnly = params.contains("VALUE=DATE") || (value.count == 8 && !value.contains("T"))

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if isDateOnly {
            f.dateFormat = "yyyyMMdd"
            f.timeZone = TimeZone.current
            return f.date(from: value).map { ($0, true) }
        }
        if value.hasSuffix("Z") {
            f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            f.timeZone = TimeZone(identifier: "UTC")
        } else {
            f.dateFormat = "yyyyMMdd'T'HHmmss"
            f.timeZone = TimeZone.current
        }
        return f.date(from: value).map { ($0, false) }
    }
}
