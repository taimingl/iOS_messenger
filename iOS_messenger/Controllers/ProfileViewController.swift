//
//  ProfileViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/27/23.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage


enum ProfileViewModelType {
    case info
    case logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)? // handling when user taps the cell
}

class ProfileViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: UserDefaults.standard.value(forKey: "userName") as? String ?? "No Name",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: UserDefaults.standard.value(forKey: "email") as? String ?? "No Email",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout,
                                     title: "Log Out",
                                     handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = UIAlertController(title: "Log out",
                                          message: "Are you sure you wanna leave?",
                                          preferredStyle: .actionSheet
            )
            
            actionSheet.addAction(UIAlertAction(title: "Log Out",
                                                style: .destructive,
                                                handler: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                
                // Log out Facebook
                FBSDKLoginKit.LoginManager().logOut()
                
                // Log out google
                GIDSignIn.sharedInstance.signOut()
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    // Signed out -> show signup/login page again
                    if FirebaseAuth.Auth.auth().currentUser == nil {
                        // Purge cached user info
                        UserDefaults.standard.setValue(nil, forKey: "email")
                        UserDefaults.standard.setValue(nil, forKey: "userName")
                        let vc = LoginViewController()
                        let nav = UINavigationController(rootViewController: vc)
                        nav.modalPresentationStyle = .pageSheet
                        strongSelf.present(nav, animated: true)
                    }
                } catch {
                    print("Failed out to log out")
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel,
                                                handler: nil))
            strongSelf.present(actionSheet, animated: true)
        }))
        
        tableView.register(ProfileTableViewCell.self,
                           forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("user email not cached")
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "profile_images/" + fileName
        
        let headerView = UIView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: self.view.width,
                                        height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (view.width - 150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.backgroundColor = .white
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width/2
        headerView.addSubview(imageView)
        
        // Get the download url from storage
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("failed to get download url from firebase \(error)")
            }
        })
        
        return headerView
    }
    
    func downloadImage(imageView: UIImageView, url: URL) {
        // download the picture
        URLSession.shared.dataTask(with: url,
                                   completionHandler: {data, _, error in
            guard let data = data, error == nil else {
                print("failed to download image from download url")
                return
            }

            // convert downloaded data into an image and update UI on main thread
            DispatchQueue.main.async {
                let image = UIImage(data: data)
                imageView.image = image
            }
        }).resume()
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier,
                                                 for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = data[indexPath.row]
        viewModel.handler?()
    }
}
