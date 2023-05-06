//
//  ChatViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/3/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
    public var sender: MessageKit.SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKit.MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    public var isNewConversation = false
    private let conversationId: String?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? = {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUserName = UserDefaults.standard.value(forKey: "userName") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let sender = Sender(photoURL: "",
                            senderId: safeEmail,
                            displayName: currentUserName)
        return sender
    }()
    
    
    init(with email: String, id: String?) {
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
        if let conversationId = conversationId {
            print("starting to listen for messages \(conversationId)")
            listenForMessages(conversationId: conversationId,
                              shouldScrollToBottom: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
    private func listenForMessages(conversationId: String,
                                   shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: conversationId,
                                                             completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        })
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else {
            return
        }
        
        print("sending \(text)")
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        // Send msg
        if isNewConversation {
            // create convo in databdase
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                         otherUserName: self.title ?? "User",
                                                         firstMessage: message,
                                                         completion: { [weak self] success in
                if success {
                    self?.isNewConversation = false
                    print("message sent")
                } else {
                    print("failed to send")
                }
            })
        } else {
            // append to existing convo data
            guard let conversationId = conversationId,
                  let otherUserName = self.title else {
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId,
                                               otherUsername: otherUserName,
                                               otherUserEmail: otherUserEmail,
                                               message: message,
                                               completion: {success in
                if success {
                    print("message sent successfully")
                } else {
                    print("message failed to send")
                }
            })
        }
    }
    
    private func createMessageId()  -> String? {
        // components we have: date, otherUserEmail, senderSemail, randomInt
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("created message id: \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource,
                              MessagesLayoutDelegate,
                              MessagesDisplayDelegate {
    
    func currentSender() -> MessageKit.SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is nil, email should've been cached")
    }
    
    func messageForItem(at indexPath: IndexPath,
                        in messagesCollectionView: MessageKit.MessagesCollectionView
    ) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
}
