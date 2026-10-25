//
//  PlannerView.swift
//  NeuroCalm
//
//  Lets the user manage daily routine tasks and deadlines.
//

import SwiftUI
import SwiftData
import UIKit

struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    @Query(sort: \RoutineTask.scheduledTime) private var tasks: [RoutineTask]
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]

    @State private var showAddTask = false
    @State private var showAddDeadline = false

    @StateObject private var calendars = CalendarService()
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("parentSquareICSURL") private var parentSquareICSURL = ""

    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var calendarsOn: Bool {
        calendarSyncEnabled || !parentSquareICSURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var todaysTasks: [RoutineTask] {
        tasks.filter { Calendar.current.isDateInToday($0.scheduledTime) }
    }

    var upcomingDeadlines: [Deadline] {
        deadlines.filter { !$0.isCompleted && $0.daysUntil >= 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isRegular {
                        // iPad: both sections side by side, visible at once.
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 20) {
                                deadlinesSection
                                if calendarsOn { eventsSection }
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                            routineSection.frame(maxWidth: .infinity, alignment: .top)
                        }
                    } else {
                        // iPhone: stacked.
                        VStack(alignment: .leading, spacing: 20) {
                            deadlinesSection
                            if calendarsOn { eventsSection }
                            routineSection
                        }
                    }
                }
                .padding()
                .adaptiveContentWidth(isRegular ? 1100 : AppTheme.maxContentWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
        .sheet(isPresented: $showAddDeadline) {
            AddDeadlineSheet()
        }
        .task(id: syncKey) { await syncCalendars() }
    }

    /// Re-sync whenever the calendar settings change.
    private var syncKey: String { "\(calendarSyncEnabled)|\(parentSquareICSURL)" }

    private func syncCalendars() async {
        guard calendarsOn else { calendars.events = []; return }
        await calendars.refresh(deviceEnabled: calendarSyncEnabled, feedURL: parentSquareICSURL)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming events")
                    .font(AppTheme.display(18))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if calendars.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await syncCalendars() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primaryBlue)
                    }
                    .accessibilityLabel("Refresh events")
                }
            }

            if let err = calendars.feedError {
                calendarNotice(err, actionTitle: "Try again") {
                    Task { await syncCalendars() }
                }
            } else if calendars.deviceAccessDenied {
                calendarNotice("Calendar access is off.", actionTitle: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            } else if calendars.events.isEmpty {
                emptyState("No events in the next 30 days.")
            } else {
                ForEach(calendars.events) { event in
                    EventRow(event: event)
                }
            }
        }
        .cardStyle()
    }

    /// An empty-state message with a follow-up action button.
    private func calendarNotice(_ text: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            emptyState(text)
            Button(actionTitle, action: action)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.sage)
        }
    }

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Deadlines", action: { showAddDeadline = true })

            if upcomingDeadlines.isEmpty {
                emptyState("Nothing due. Tap + to add a deadline.")
            } else {
                ForEach(upcomingDeadlines) { d in
                    DeadlineRow(deadline: d)
                }
            }
        }
        .cardStyle()
    }

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Today's Routine", action: { showAddTask = true })

            if todaysTasks.isEmpty {
                emptyState("No tasks today. Tap + to add one.")
            } else {
                ForEach(todaysTasks) { task in
                    TaskRow(task: task)
                }
            }
        }
        .cardStyle()
    }

    private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.display(18))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button(action: action) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primaryBlue)
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.vertical, 8)
    }
}

// MARK: - Deadline Row

struct DeadlineRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var deadline: Deadline
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                deadline.isCompleted.toggle()
                try? context.save()
            } label: {
                Image(systemName: deadline.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(deadline.isCompleted ? AppTheme.softTeal : AppTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.title)
                    .font(.subheadline)
                    .strikethrough(deadline.isCompleted)
                    .foregroundStyle(AppTheme.textPrimary)
                if !deadline.subject.isEmpty {
                    Text(deadline.subject)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Text(deadline.humanReadableDue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(deadline.daysUntil <= 1 ? AppTheme.warmCoral : AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((deadline.daysUntil <= 1 ? AppTheme.warmCoral : AppTheme.textSecondary).opacity(0.1))
                .cornerRadius(8)

            Menu {
                Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) {
                    context.delete(deadline)
                    try? context.save()
                } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Deadline options")
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEdit) { AddDeadlineSheet(editing: deadline) }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// When set, the sheet edits this task in place instead of creating one.
    private let editing: RoutineTask?

    @State private var title: String
    @State private var time: Date
    @State private var category: TaskCategory

    init(editing: RoutineTask? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _time = State(initialValue: editing?.scheduledTime ?? Date())
        _category = State(initialValue: TaskCategory(rawValue: editing?.category ?? "study") ?? .study)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                }
                Section("Time") {
                    DatePicker("Scheduled for", selection: $time, displayedComponents: [.hourAndMinute])
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(title.isEmpty)
                }
            }
        }
    }

    private func save() {
        let task: RoutineTask
        if let editing {
            editing.title = title
            editing.scheduledTime = time
            editing.category = category.rawValue
            task = editing
        } else {
            task = RoutineTask(title: title, scheduledTime: time, category: category.rawValue)
            context.insert(task)
        }
        try? context.save()

        // Remind the user daily at this task's time (reschedules on edit).
        NotificationService.shared.scheduleRoutineReminder(for: task)

        dismiss()
    }
}

// MARK: - Add Deadline Sheet

struct AddDeadlineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// When set, the sheet edits this deadline in place instead of creating one.
    private let editing: Deadline?

    @State private var title: String
    @State private var subject: String
    @State private var dueDate: Date

    init(editing: Deadline? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _subject = State(initialValue: editing?.subject ?? "")
        _dueDate = State(initialValue: editing?.dueDate
                         ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deadline") {
                    TextField("e.g. Chemistry Test", text: $title)
                    TextField("Subject (optional)", text: $subject)
                }
                Section("When") {
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                }
            }
            .navigationTitle(editing == nil ? "New Deadline" : "Edit Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(title.isEmpty)
                }
            }
        }
    }

    private func save() {
        let d: Deadline
        if let editing {
            editing.title = title
            editing.dueDate = dueDate
            editing.subject = subject
            d = editing
        } else {
            d = Deadline(title: title, dueDate: dueDate, subject: subject)
            context.insert(d)
        }
        try? context.save()

        // Schedule (or reschedule) a reminder the day before.
        NotificationService.shared.scheduleDeadlineReminder(for: d)

        dismiss()
    }
}

// MARK: - Calendar Event Row (read-only)

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.source == .feed ? "building.columns.fill" : "calendar")
                .font(.subheadline)
                .foregroundStyle(AppTheme.softTeal)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(event.whenLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(event.source.rawValue)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AppTheme.background.opacity(0.5))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlannerView()
        .modelContainer(for: [RoutineTask.self, Deadline.self], inMemory: true)
}
