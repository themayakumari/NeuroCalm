//
//  AssistantView.swift
//  NeuroCalm
//
//  A conversational assistant. Conversations are stored with SwiftData so they
//  survive navigating away and app restarts, and the user can keep a history of
//  separate chats (like popular chat apps) — switch, rename, or start a new one.
//
//  On wide screens (iPad) the conversation history is a persistent second
//  sidebar beside the chat; on iPhone it opens as a slide-up list from the
//  toolbar (a phone has no room for a permanent second sidebar).
//

import SwiftUI
import SwiftData

private let greetingText = "Hi! I'm here to help. Tell me what's going on — a test, homework, stress, sleep — anything."

struct AssistantView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \AssistantConversation.updatedAt, order: .reverse)
    private var conversations: [AssistantConversation]

    @State private var current: AssistantConversation?
    @State private var input: String = ""
    @State private var showBreathing = false
    @State private var showHistory = false
    @State private var isTyping = false

    // Quick-reply suggestions
    private let suggestions = [
        "I have a test tomorrow",
        "I'm feeling overwhelmed",
        "I can't focus",
        "I'm tired but can't sleep"
    ]

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var messages: [AssistantMessage] { current?.orderedMessages ?? [] }

    var body: some View {
        Group {
            if isWide {
                // iPad: conversations as a persistent second sidebar beside the chat.
                HStack(spacing: 0) {
                    conversationSidebar
                    Divider()
                    chatPane(showsMenuButton: false)
                }
            } else {
                // iPhone: chat full-width; history opens from the toolbar.
                chatPane(showsMenuButton: true)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showBreathing) { BreathingView() }
        .sheet(isPresented: $showHistory) { historySheet }
        .onAppear(perform: ensureConversation)
    }

    // MARK: - Second sidebar (iPad)

    private var conversationSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(AppTheme.display(18))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { startNewChat() } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primaryBlue)
                }
                .accessibilityLabel("New chat")
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            Divider()
            ConversationListContent(current: $current)
        }
        .frame(width: 300)
        .background(AppTheme.background)
    }

    // MARK: - History sheet (iPhone)

    private var historySheet: some View {
        NavigationStack {
            ConversationListContent(current: $current, onPick: { showHistory = false })
                .scrollContentBackground(.hidden)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("Conversations")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { showHistory = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { startNewChat(); showHistory = false } label: {
                            Label("New chat", systemImage: "square.and.pencil")
                        }
                    }
                }
        }
    }

    // MARK: - Chat pane

    private func chatPane(showsMenuButton: Bool) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatScroll
                suggestionChips
                inputBar
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(current?.title ?? "Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsMenuButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showHistory = true } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Conversations")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { startNewChat() } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("New chat")
                    }
                }
            }
        }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages, id: \.persistentModelID) { msg in
                        MessageBubble(text: msg.text, isUser: msg.isUser, source: msg.source)
                            .id(msg.persistentModelID)
                    }
                    if isTyping {
                        TypingIndicator().id("typing")
                    }
                }
                .padding()
                .adaptiveContentWidth()
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: isTyping) { _, typing in
                if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
            .onChange(of: current?.persistentModelID) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { send(s) } label: {
                        Text(s)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.twilight2)
                            .foregroundStyle(AppTheme.textPrimary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .adaptiveContentWidth()
        }
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message NeuroCalm…", text: $input)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(12)
                .background(AppTheme.twilight2)
                .cornerRadius(20)
                .onSubmit { send(input) }
                .accessibilityIdentifier("assistantInput")

            Button { send(input) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(input.isEmpty ? AppTheme.textSecondary : AppTheme.primaryBlue)
            }
            .disabled(input.isEmpty)
            .accessibilityIdentifier("assistantSend")
        }
        .padding()
        .adaptiveContentWidth()
        .background(AppTheme.background)
    }

    // MARK: - Conversation lifecycle

    /// Make sure a conversation is loaded when the view appears: reuse the most
    /// recent chat, otherwise start a fresh one with the greeting.
    private func ensureConversation() {
        if let c = current, !c.isDeleted { return }
        if let latest = conversations.first {
            current = latest
        } else {
            startNewChat()
        }
    }

    private func startNewChat() {
        let convo = AssistantConversation()
        context.insert(convo)
        let greeting = AssistantMessage(text: greetingText, isUser: false)
        greeting.conversation = convo
        context.insert(greeting)
        try? context.save()
        current = convo
        input = ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation { proxy.scrollTo(last.persistentModelID, anchor: .bottom) }
        }
    }

    // MARK: - Sending

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if current == nil || current?.isDeleted == true { startNewChat() }
        guard let convo = current else { return }

        input = ""
        let userMsg = AssistantMessage(text: trimmed, isUser: true)
        userMsg.conversation = convo
        context.insert(userMsg)

        // Title the chat from its first user message.
        if convo.title == "New chat" {
            convo.title = String(trimmed.prefix(40))
        }
        convo.updatedAt = .now
        try? context.save()
        isTyping = true

        // Build the reply history, dropping any leading non-user turns so it
        // starts with a user message.
        var turns = convo.orderedMessages
        while let first = turns.first, !first.isUser { turns.removeFirst() }
        let history = turns.map { (role: $0.isUser ? "user" : "assistant", text: $0.text) }

        Task {
            let result = await AssistantService.generateReply(history: history)
            isTyping = false
            let reply = AssistantMessage(text: result.text, isUser: false, source: result.source.rawValue)
            reply.conversation = convo
            context.insert(reply)
            convo.updatedAt = .now
            try? context.save()
        }
    }
}

// MARK: - Conversation list (shared by the iPad sidebar and the iPhone sheet)

struct ConversationListContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AssistantConversation.updatedAt, order: .reverse)
    private var conversations: [AssistantConversation]

    @Binding var current: AssistantConversation?
    /// Called after the user taps a conversation (e.g. to dismiss the sheet).
    var onPick: (() -> Void)? = nil

    @State private var renaming: AssistantConversation?
    @State private var renameText: String = ""

    var body: some View {
        List {
            ForEach(conversations, id: \.persistentModelID) { convo in
                Button { current = convo; onPick?() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(convo.title)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(convo.preview)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if convo.persistentModelID == current?.persistentModelID {
                            Image(systemName: "checkmark")
                                .font(.caption).foregroundStyle(AppTheme.primaryBlue)
                        }
                    }
                }
                .listRowBackground(
                    convo.persistentModelID == current?.persistentModelID
                        ? AppTheme.twilight2.opacity(0.6)
                        : AppTheme.twilight2.opacity(0.25)
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { delete(convo) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button { beginRename(convo) } label: { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive) { delete(convo) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert("Rename chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let c = renaming {
                    let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { c.title = t; try? context.save() }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func beginRename(_ convo: AssistantConversation) {
        renameText = convo.title
        renaming = convo
    }

    private func delete(_ convo: AssistantConversation) {
        let wasCurrent = convo.persistentModelID == current?.persistentModelID
        context.delete(convo)
        try? context.save()
        // If we deleted the open chat, jump to the next most recent one.
        if wasCurrent {
            current = conversations.first(where: { $0.persistentModelID != convo.persistentModelID })
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var active = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(AppTheme.cream.opacity(active == i ? 0.95 : 0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.sageDim)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in active = (active + 1) % 3 }
    }
}

// MARK: - Message bubble

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    var source: String? = nil

    var body: some View {
        HStack {
            if isUser { Spacer() }
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .padding(12)
                    .background(isUser ? AppTheme.twilight2 : AppTheme.sageDim)
                    .foregroundStyle(AppTheme.cream)
                    .cornerRadius(16)
                if !isUser, let source {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer() }
        }
    }
}

#Preview {
    AssistantView()
        .modelContainer(for: [AssistantConversation.self, AssistantMessage.self], inMemory: true)
}
