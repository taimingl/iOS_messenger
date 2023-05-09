//
//  ViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/27/23.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

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

class ConversationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private var loginObserver: NSObjectProtocol?
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self,
                       forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations. \n Tap Edit Button to start a new chat."
        label.numberOfLines = 2
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTapComposeButton))
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        fetchConversations()
        setupTableView()
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNofication,
                                                               object: nil,
                                                               queue:  .main,
                                                               using: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.startListeningConversations()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
        
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        } else {
            NotificationCenter.default.post(name: .didLogInNofication, object: nil)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func fetchConversations() {
        tableView.isHidden = false
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = {[weak self] result in
            guard let strongSelf = self else {
                return
            }
            // first check if the target convo is already in current convo array
            let currentConversations = strongSelf.conversations
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.otherUsuerEmail)
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserEmail,
                                            id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.otherUserName
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
                strongSelf.createNewConversation(result: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    private func createNewConversation(result: SearchResult) {
        let name = result.otherUserName
        let email = result.otherUsuerEmail
        // check in database if conversation with these two users exists
        DatabaseManager.shared.conversationExists(with: email,
                                                  completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .failure(_):
                // No -> create new conversation
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .success(let conversationId):
                // Yes -> reuse conversation id
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    
    private func startListeningConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("starting conversation fetch...")
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail,
                                                   completion: { [weak self] result in
            switch result {
            case .success(let conversations):
                print("successfully got conversation models")
                guard !conversations.isEmpty else {
//                    self?.noConversationsLabel.isHidden = true
//                    self?.tableView.isHidden = false
                    return
                }
                self?.conversations = conversations
//                self?.noConversationsLabel.isHidden = true
//                self?.tableView.isHidden = false
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    self?.showNoConversationLabel()
                }
            case .failure(let error):
//                self?.noConversationsLabel.isHidden = true
//                self?.tableView.isHidden = false
                self?.showNoConversationLabel()
                print("failed to get convos: \(error)")
            }
        })
    }
    
    private func showNoConversationLabel() {
        let toHide = !conversations.isEmpty
        DispatchQueue.main.async {
            self.noConversationsLabel.isHidden = toHide
        }
    }
    
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,
                                                 for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.otherUserName
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            DatabaseManager.shared.deleteConversation(with: conversationId,
                                                      completion: { success in
                if !success {
                    // TODO: add model and row back and show alert
                }
            })
            conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            if conversations.isEmpty {
                noConversationsLabel.isHidden = false
            }
            tableView.endUpdates()
        }
    }
    
}

