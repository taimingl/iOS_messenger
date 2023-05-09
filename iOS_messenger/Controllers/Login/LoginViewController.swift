//
//  LoginViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/27/23.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

final class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var loginObserver: NSObjectProtocol?
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .systemYellow
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    // Facebook login button
    private let fbLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["email","public_profile"]
        return button
    }()
    
    // Google login button
    private let googleSignButton: GIDSignInButton = {
        let button = GIDSignInButton()
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNofication,
                                                               object: nil,
                                                               queue: .main,
                                                               using: { [weak self] _ in
            guard let strongsSelf = self else{
                return
            }
            strongsSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
        
        title = "Log In"
        view.backgroundColor = .cyan
        navigationController?.navigationBar.backgroundColor = .systemYellow
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegister))
        
        loginButton.addTarget(self,
                              action: #selector(loginButtonTapped),
                              for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        fbLoginButton.delegate = self
        
        // Google sign in button delegate
        googleSignButton.addTarget(self,
                                   action: #selector(handleGoogleLoginButton),
                                   for: .touchUpInside)
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(fbLoginButton)
        scrollView.addSubview(googleSignButton)
    }
    
    deinit {
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    @objc private func handleGoogleLoginButton() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Goole Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard error == nil else {
                print("Failed to sign in with google with error: \(error.debugDescription)")
                return
            }
            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                print("failed to get the user object from google")
                return
            }
            guard let email = user.profile?.email as? String,
                  let firstName = user.profile?.givenName as? String,
                  let lastName = user.profile?.familyName as? String else {
                print("failed to get user details from google")
                return
            }
            
            // Cache user info to device
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "userName")
            
            
            // Create firebase user object if new
            DatabaseManager.shared.userExists(with: email,
                                              completion: { exists in
                print(DatabaseManager.safeEmail(emailAddress: email))
                if !exists {
                    print("singing up with a new user")
                    let chatUser = ChatAppUser(firstName: firstName,
                                               lastName: lastName,
                                               emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser,
                                                      completion: { success in
                        if success {
                            // user google account profile pic if user has one
                            guard let profile = user.profile else {
                                return
                            }
                            if profile.hasImage {
                                guard let url = profile.imageURL(withDimension: 200) else {
                                    print("failed to get google profile pic url")
                                    return
                                }
                                print("Got the google profile pic url. downloading pic")
                                // Downloading google profile pic bites and uploading to firebase
                                URLSession.shared.dataTask(with: url,
                                                           completionHandler: {data, _, _ in
                                    guard let data = data else {
                                        print("failed to download pic bites from google")
                                        return
                                    }
                                    // upload downloaded pic to firebase
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadPicture(with: data,
                                                                        databaseDir: "profile_images",
                                                                        fileName: fileName,
                                                                        completion: { result in
                                        switch (result) {
                                        case .success(let downloadUrl):
                                            UserDefaults.standard.setValue(downloadUrl,
                                                                           forKeyPath: "profile_picture_url")
                                            print(downloadUrl)
                                        case .failure(let error):
                                            print("Storage manager error: \(error)")
                                        }
                                    })
                                }).resume()
                            }
                        }
                    })
                }
            })
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            // Trade google credential to sign in to firebase
            FirebaseAuth.Auth.auth().signIn(with: credential,
                                            completion: { [weak self] authResult, error in
                guard let strongSelf = self else {
                    return
                }
                guard authResult != nil, error == nil else {
                    if let error = error {
                        print("google credential login failed. MFA may be needed \(error)")
                    }
                    return
                }
                
                print("successfully logged user in with firebase")
                NotificationCenter.default.post(name: .didLogInNofication, object: nil)
                strongSelf.navigationController?.dismiss(animated: true,
                                                         completion: nil)
            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (view.width-size)/2,
                                 y: 40,
                                 width: size,
                                 height: size)
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom+10,
                                  width: scrollView.width-60,
                                  height: 52)
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom+10,
                                     width: scrollView.width-60,
                                     height: 52)
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom+10,
                                   width: scrollView.width-60,
                                   height: 52)
        fbLoginButton.frame = CGRect(x: 30,
                                     y: loginButton.bottom+10,
                                     width: scrollView.width-60,
                                     height: 52)
        googleSignButton.frame = CGRect(x: 30,
                                        y: fbLoginButton.bottom+10,
                                        width: scrollView.width-60,
                                        height: 52)
    }
    
    @objc private func loginButtonTapped() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6
        else {
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        // Firebase login
        FirebaseAuth.Auth.auth().signIn(withEmail: email,
                                        password: password,
                                        completion: { [weak self] authResult, error in
            guard let strongSelf = self else {
                return
            }
            
            // Call back function works on the background thread. UI changes should be on main thread
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            guard let result = authResult,
                  error == nil else {
                print("error signing in the suer")
                strongSelf.alertUserLoginError()
                return
            }
            
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail,
                                              completion: { [weak self] result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let firstname = userData["first_name"] as? String,
                          let lastname = userData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(firstname) \(lastname)", forKey: "userName")
                case .failure(let error):
                    print("failed to read data with error: \(error)")
                }
            })
            // Cache user info to device to fast access
            UserDefaults.standard.set(email, forKey: "email")
            
            
            print("Logged in user: \(user)")
            NotificationCenter.default.post(name: .didLogInNofication, object: nil)
            strongSelf.navigationController?.dismiss(animated: true,
                                                     completion: nil)
        })
    }
    
    func alertUserLoginError() {
        let alert = UIAlertController(title: "Woops",
                                      message: "Please enter all information to log in.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true)
    }
    
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
}


extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController: LoginButtonDelegate {
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
        // no operations
    }
    
    func loginButton(_ loginButton: FBSDKLoginKit.FBLoginButton, didCompleteWith result: FBSDKLoginKit.LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("user failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields":
                                                                        "email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token,
                                                         version: nil,
                                                         httpMethod: .get
        )
        
        facebookRequest.start(completion: { _, result, error in
            guard let result = result as? [String: Any], error == nil else {
                print("failed to make facebook graph request")
                return
            }
            
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String:Any],
                  let data = picture["data"] as? [String:Any],
                  let pictureUrl = data["url"] as? String else {
                print("failed to get email and name from fb result")
                return
            }
            
            // Cache user info to device
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "userName")
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstName: firstName,
                                               lastName: lastName,
                                               emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser,
                                                      completion: {success in
                        if success {
                            // Download facebook profile picture bites from pictureUrl
                            guard let url = URL(string: pictureUrl) else {
                                return
                            }
                            
                            print("downloading picture bites from facebook image")
                            URLSession.shared.dataTask(with: url,
                                                       completionHandler: {data, _, error in
                                guard let data = data else {
                                    print("failed to download picture bites from facebook")
                                    return
                                }
                                print("Got picture bites from fb, uploading to firebase")
                                // upload downloaded pic to firebase
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadPicture(with: data,
                                                                    databaseDir: "profile_images",
                                                                    fileName: fileName,
                                                                    completion: { result in
                                    switch (result) {
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.setValue(downloadUrl,
                                                                       forKeyPath: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage manager error: \(error)")
                                    }
                                })
                            }).resume()
                        }
                    })
                }
            })
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential,
                                            completion: { [weak self] authResult, error in
                guard let strongSelf = self else {
                    return
                }
                guard authResult != nil, error == nil else {
                    if let error = error {
                        print("facebook credential login failed. MFA may be needed \(error)")
                    }
                    return
                }
                
                print("successfully logged user in")
                NotificationCenter.default.post(name: .didLogInNofication, object: nil)
                strongSelf.navigationController?.dismiss(animated: true,
                                                         completion: nil)
            })
        })
    }
}
