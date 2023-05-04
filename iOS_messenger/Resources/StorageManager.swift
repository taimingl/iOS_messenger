//
//  StorageManager.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/4/23.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    /**
     /images/xxx-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Uploads picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data: Data,
                                     fileName: String,
                                     completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data,
                                                    metadata: nil,
                                                    completion: {metadata, error in
            guard error == nil else {
                print("failed to upload to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(
                completion: {url, error in
                    guard let url = url else {
                        print("Uploaded the picture but failed to get the pic url")
                        completion(.failure(StorageErrors.failedToGetDownloadUrl))
                        return
                    }
                    let urlString = url.absoluteString
                    print("download url returned: \(urlString)")
                    completion(.success(urlString))
                })
        })
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
    public func downloadURL(for path: String,
                            completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL(completion: {url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        })
    }
}
