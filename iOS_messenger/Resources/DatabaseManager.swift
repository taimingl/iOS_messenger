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

// MARK: - Account Management

extension DatabaseManager {
    
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value,
                                                 with: { snapshot in
            guard snapshot.value as? String != nil else {
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
