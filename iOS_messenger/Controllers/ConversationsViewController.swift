//
//  ViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/27/23.
//

import UIKit
import FirebaseAuth

class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth() 
//        let isLoggedIn = UserDefaults.standard.bool(forKey: "logged_in")
        
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        }
    }
}

