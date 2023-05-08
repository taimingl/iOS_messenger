//
//  ChatViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/3/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation
import MapKit

struct Message: MessageType {
    public var sender: MessageKit.SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
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

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm:ss a zzz"
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
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setUpMultiMediaInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
    private func setUpMultiMediaInputButton() {
        // create and configure the button
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip.circle.fill"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentMultiMediaInputActionSheet()
        }
        
        // attach the button to messageInputBar
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button],
                                          forStack: .left,
                                          animated: false)
    }
    
    private func presentMultiMediaInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { [weak self] _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "Where would you like to attach photo from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentVideoActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Video",
                                            message: "Where would you like to attach video from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick a location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            print("long = \(longitude) | lat = \(latitude)")
            // sending the localtion msg
            guard let strongSelf = self,
                  let selfSender = strongSelf.selfSender,
                  let messageId = strongSelf.createMessageId(),
                  let otherUserName = strongSelf.title,
                  let conversationId = strongSelf.conversationId else {
                return
            }
            let locationItem = Location(location: CLLocation(latitude: latitude,
                                                             longitude: longitude),
                                        size: .zero)
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(locationItem))
            DatabaseManager.shared.sendMessage(to: conversationId,
                                               otherUsername: otherUserName,
                                               otherUserEmail: strongSelf.otherUserEmail,
                                               message: message,
                                               completion: { success in
                if success {
                    print("sent location message")
                } else {
                    print("failed to send location message")
                }
            })
        }
        navigationController?.pushViewController(vc, animated: true)
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

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let selfSender = self.selfSender,
              let otherUserName = self.title else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage,
           let imageData = image.pngData() {
            // for photos
            let fileName = "photo_conversation_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // upload image: get data and send data
            StorageManager.shared.uploadPicture(with: imageData,
                                                databaseDir: "conversation_images",
                                                fileName: fileName,
                                                completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // ready to send the message
                    guard let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    print("Uploaded message photo to: \(urlString)")
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUsername: otherUserName,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       message:  message,
                                                       completion: { success in
                        if success {
                            print("sent photo message")
                        } else {
                            print("failed to send photo message")
                        }
                    })
                case .failure(let error):
                    print("message photo upload error: \(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            // for videos
            let fileName = "video_conversation_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            // upload video
            StorageManager.shared.uploadVideo(with: videoUrl,
                                              databaseDir: "conversation_videos",
                                              fileName: fileName,
                                              completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // ready to send the message
                    guard let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    print("Uploaded message video to: \(urlString)")
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUsername: otherUserName,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       message:  message,
                                                       completion: { success in
                        if success {
                            print("sent video message")
                        } else {
                            print("failed to send video message")
                        }
                    })
                case .failure(let error):
                    print("message video upload error: \(error)")
                }
            })
        }
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else {
            return
        }
        inputBar.inputTextView.text = ""
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
    
    func configureMediaMessageImageView(_ imageView: UIImageView,
                                        for message: MessageType,
                                        at indexPath: IndexPath,
                                        in messagesCollectionView: MessagesCollectionView) {
        // Download image and update the imageView
        // get the message and get the url from the message
        guard let message = message as? Message else {
            return
        }
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                print("failed to get image url from message")
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }

}

extension ChatViewController: MessageCellDelegate {
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        if case let .location(locationitem) = message.kind {
            let coordinates = locationitem.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
//            let pin = MKPointAnnotation()
//            pin.coordinate = locationitem.location.coordinate
//            vc.map.addAnnotation(pin)
            vc.title = "Localtion"
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        if case let .photo(media) = message.kind {
            guard let imageUrl = media.url else {
                print("failed to get image url from message")
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        if case let .video(media) = message.kind {
            guard let videoUrl = media.url else {
                print("failed to get video url when rendering")
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            //self.navigationController?.pushViewController(vc, animated: true)
            present(vc, animated: true)
        }
    }
}
