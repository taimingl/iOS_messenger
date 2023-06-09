//
//  NewConversationViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/27/23.
//

import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> (Void))?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    private var results = [SearchResult]()
    private var hasFetched = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(NewConversationCell.self,
                       forCellReuseIdentifier: NewConversationCell.identifier)
        return table
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultsLabel)
        setupTableView()
        view.addSubview(tableView)
        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4,
                                      y: (view.height - 200) / 2,
                                      width: view.width/2,
                                      height: 200)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }

    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

extension NewConversationViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text,
              !text.isEmpty,
              !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        
        searchUsers(query: text)
    }
    
    /**
     Only queries from firebase the first time the user searches and caches the users array collection locally for subsequent searches
     */
    func searchUsers(query: String) -> Void {
        // check if user has firebase results
        if hasFetched {
            // filter the result
            filterUsers(with: query)
        } else {
            // search and filter
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let usersCollection):
                    strongSelf.hasFetched = true
                    strongSelf.users = usersCollection
                    strongSelf.filterUsers(with: query)
                case .failure(let error):
                    print("failed to get users: \(error)")
                }
            })
        }
    }
    
    func filterUsers(with term: String) {
        // update the UI: either show results or show noResultsLabel
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              hasFetched else {
            return
        }
        spinner.dismiss()
        
        let currentUserSafeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let results: [SearchResult] = self.users.filter({
            guard let email = $0["email"], email != currentUserSafeEmail else {
                return false
            }
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"],
                  let name = $0["name"] else {
                return nil
            }
            return SearchResult(otherUserName: name,
                                otherUsuerEmail: email)
        })
        self.results = results
        
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        } else {
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier,
                                                 for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        
        let targetUserData = results[indexPath.row]
        // Check if conversation with resulting user exists
        // Yes -> resume conversation; No -> create new conversation
        dismiss(animated: true, completion: {[weak self] in
            self?.completion?(targetUserData)
        })
        let vc = ChatViewController(with: "fake-gmail-com", id: "")
        vc.title = "New Chat"
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
