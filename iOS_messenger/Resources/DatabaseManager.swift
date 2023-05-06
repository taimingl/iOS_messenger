//
//  DatabaseManager.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/30/23.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    // singleton -> easy read/write access
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }

}

extension DatabaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value,
                                                          with: {snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}


// MARK: - Account Management

extension DatabaseManager {
    
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value,
                                                 with: { snapshot in
            guard snapshot.exists() else {
                print("no record found")
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser,
                           completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            // Append new user to database' users array. if first user, create the array
            /**
             users schema
             users => [
                 [
                     "name": xxx,
                     "safe_email": xxx
                 ],
                 [
                     "name": xxx,
                     "safe_email": xxx
                 ]
             ]
             */
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to usersCollection
                    let newElement: [String: String] = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.emailAddress
                    ]
                    usersCollection.append(newElement)
                    self.database.child("users").setValue(usersCollection,
                                                          withCompletionBlock: {error, _ in
                        guard error == nil else {
                            print("failed to append new user to users collection array in firebase database")
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    // Create the usersCollection
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection,
                                                          withCompletionBlock: {error, _ in
                        guard error == nil else {
                            print("failed to create user collections in firebase database")
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value,
                                                   with: {snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}

// MARK: - Sending messages/conversations
extension DatabaseManager {
    
    /**
     Conversations schema
     "dsahudis": => {
        "messages": [
            {
                "id": String,
                "type": text, photo, video
                "content": String,
                "date": Date(),
                "sender_email": String,
                "is_read": Bool
            }
        ]
     }
     conversations => [
         [
             "conversationId": "dsahudis",
             "other_user_email": xxx,
             "latest_message": => {
                "date": Date(),
                "latest_message": "message",
                "is_read": Bool
             }
         ]
     ]
     */
    
    private func finishCreateConversation(otherUsername: String,
                                          conversationId: String,
                                          firstMessage: Message,
                                          completion: @escaping (Bool) -> Void) {
        var messageContent = ""
        
        switch firstMessage.kind {
        case .text(let messageText):
            messageContent = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeCurrentUserEmail = Self.safeEmail(emailAddress: currentUserEmail)
        
        let messageObject: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": messageContent,
            "date": dateString,
            "sender_email": safeCurrentUserEmail,
            "is_read": false,
            "name": otherUsername
        ]
        
        let value: [String: Any] = [
            "messages": [
                messageObject
            ]
        ]
        
        database.child("\(conversationId)").setValue(value,
                                                     withCompletionBlock: {error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Creates a new conversation with taget user email and first message sent
    public func createNewConversation(with otherUserEmail: String,
                                      otherUserName: String,
                                      firstMessage: Message,
                                      completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUserName = UserDefaults.standard.value(forKey: "userName") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        // find conversation collections
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value,
                               with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var userNode = snapshot.value as? [String: Any] else {
                print("user not found")
                completion(false)
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation-\(firstMessage.messageId)"
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": otherUserName,
                "latest_message": [
                    "date": dateString,
                    "message_content": message,
                    "is_read": false
                ] as [String : Any]
            ]
            
            let recipientNewConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentUserName,
                "latest_message": [
                    "date": dateString,
                    "message_content": message,
                    "is_read": false
                ] as [String : Any]
            ]
            
            // Update recipient user conversation entry
            let recipientRef = strongSelf.database.child("\(otherUserEmail)/conversations")
            recipientRef.observeSingleEvent(of: .value,
                                            with: {snapshot in
                if var recipientConvos = snapshot.value as? [[String: Any]] {
                    // Append new convo
                    recipientConvos.append(recipientNewConversationData)
                    recipientRef.setValue(recipientConvos)
                } else {
                    // Create
                    recipientRef.setValue([recipientNewConversationData])
                }
            })
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversations array exist for current user -> append to the array
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
            } else {
                // conversations array does not exist -> create
                userNode["conversations"] = [
                    newConversationData
                ]
            }
            ref.setValue(userNode,
                         withCompletionBlock: { [weak self] error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                self?.finishCreateConversation(otherUsername: otherUserName,
                                               conversationId: conversationId,
                                               firstMessage: firstMessage,
                                               completion: completion)
            })
        })
    }
    
    /// Fetches and returns all conversations for the user with email
    public func getAllConversations(for safeEmail: String,
                                    completion: @escaping (Result<[Conversation], Error>) -> Void) {
        let path = "\(safeEmail)/conversations"
        database.child(path).observe(.value,
                                     with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let otherUserName = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let sentDate = latestMessage["date"] as? String,
                      let messageContent = latestMessage["message_content"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    print("conversations unpack failed")
                    return nil
                }
                
                let latestMessageObj = LatestMessage(date: sentDate,
                                                     text: messageContent,
                                                     isRead: isRead)
                
                return Conversation(id: conversationId,
                                    otherUserName: otherUserName,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObj)
            })
            completion(.success(conversations))
        })
    }
    
    // TODO: - Schema in userSafeEmail/conversations/ seems to be broken now.
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String,
                                              completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value,
                                                 with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let messageId = dictionary["id"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let otherUserName = dictionary["name"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String else {
                    print("failed to get all messages for convo id: \(id)")
                    return nil
                }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: otherUserName)
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: Date(),
                               kind: .text(content))
            })
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversationId: String,
                            otherUsername: String,
                            otherUserEmail: String,
                            message: Message,
                            completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currUserSafeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        // add new message to messages
        database.child("\(conversationId)/messages").observeSingleEvent(of: .value,
                                                                        with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessage = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            var messageContent = ""
            switch message.kind {
            case .text(let messageText):
                messageContent = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrl = mediaItem.url?.absoluteString {
                    messageContent = targetUrl
                }
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let messageDate = message.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            
            let safeCurrentUserEmail = Self.safeEmail(emailAddress: currentUserEmail)
            
            let messageObject: [String: Any] = [
                "id": message.messageId,
                "type": message.kind.messageKindString,
                "content": messageContent,
                "date": dateString,
                "sender_email": safeCurrentUserEmail,
                "is_read": false,
                "name": otherUsername
            ]
            currentMessage.append(messageObject)
            strongSelf.database.child("\(conversationId)/messages").setValue(currentMessage,
                                                                             withCompletionBlock: {error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                // update latest message
                let latestMessage: [String: Any] = [
                    "date": dateString,
                    "message_content": messageContent,
                    "is_read": false
                ]
                strongSelf.updateUserLatestMessage(for: currUserSafeEmail,
                                                   with: latestMessage,
                                                   conversationId: conversationId,
                                                   completion: {success in
                    if !success {
                        completion(false)
                        return
                    }
                })
                strongSelf.updateUserLatestMessage(for: otherUserEmail,
                                                   with: latestMessage,
                                                   conversationId: conversationId,
                                                   completion: {success in
                    if !success {
                        completion(false)
                        return
                    }
                })
                completion(true)
            })
        })
    }
    
    private func updateUserLatestMessage(for userSafeEmail: String,
                                         with latestMessage: [String: Any],
                                         conversationId: String,
                                         completion: @escaping (Bool) -> Void) {
        self.database.child("\(userSafeEmail)/conversations").observeSingleEvent(of: .value,
                                                                                 with: {snapshot in
            guard var userConversations = snapshot.value as? [[String: Any]] else {
                print("failed to fetch usr's convo array for user: \(userSafeEmail)")
                completion(false)
                return
            }
            var latestMsgPosition = 0
            var targetConvo: [String: Any]?
            for (idx, convo) in userConversations.enumerated() {
                if let convoId = convo["id"] as? String, convoId == conversationId {
                    latestMsgPosition = idx
                    targetConvo = convo
                    break
                }
            }
            targetConvo?["latest_message"] = latestMessage
            guard let targetConvo = targetConvo else {
                print("failed to find target convo for user \(userSafeEmail)")
                completion(false)
                return
            }
            userConversations[latestMsgPosition] = targetConvo
            self.database.child("\(userSafeEmail)/conversations").setValue(userConversations,
                                                                           withCompletionBlock: {error, _ in
                guard error == nil else {
                    print("failed to set current user latest msg")
                    completion(false)
                    return
                }
            })
            completion(true)
        })
    }
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
