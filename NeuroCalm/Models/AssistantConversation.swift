//
//  AssistantConversation.swift
//  NeuroCalm
//
//  Persistent storage for the Assistant chat so conversations survive
//  navigating away and app restarts, and so the user can keep a history of
//  separate chats (like popular chat apps).
//

import Foundation
import SwiftData

@Model
final class AssistantConversation {
    var title: String
    var createdAt: Date
    var updatedAt: Date

    // Deleting a conversation removes all its messages.
    @Relationship(deleteRule: .cascade, inverse: \AssistantMessage.conversation)
    var messages: [AssistantMessage] = []

    init(title: String = "New chat", createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Messages in chronological order (SwiftData relationships are unordered).
    var orderedMessages: [AssistantMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// First user message, used to auto-title the chat.
    var firstUserText: String? {
        orderedMessages.first(where: { $0.isUser })?.text
    }

    /// A short preview of the latest message for the conversation list.
    var preview: String {
        orderedMessages.last?.text ?? "New chat"
    }
}

@Model
final class AssistantMessage {
    var text: String
    var isUser: Bool
    var source: String?          // which engine replied (assistant messages only)
    var timestamp: Date
    var conversation: AssistantConversation?

    init(text: String, isUser: Bool, source: String? = nil, timestamp: Date = .now) {
        self.text = text
        self.isUser = isUser
        self.source = source
        self.timestamp = timestamp
    }
}
