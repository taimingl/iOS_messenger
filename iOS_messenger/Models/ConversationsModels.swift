//
//  ConversationsModels.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/8/23.
//

import Foundation

struct Conversation {
    let id: String
    let otherUserName: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
