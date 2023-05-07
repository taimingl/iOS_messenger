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
     /xxx_images/xxx-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Uploads picture to firebase storage and returns completion with url string to download
    public func uploadPicture(with data: Data,
                              databaseDir dir: String,
                              fileName: String,
                              completion: @escaping UploadPictureCompletion) {
        let path = dir + "/" + fileName
        storage.child("\(path)").putData(data,
                                         metadata: nil,
                                         completion: { [weak self] metadata, error in
            guard error == nil else {
                print("failed to upload to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("\(path)").downloadURL(
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
    
    /// Uploads video to firebase storage and returns completion with url string to download
    public func uploadVideo(with fileUrl: URL,
                            databaseDir dir: String,
                            fileName: String,
                            completion: @escaping UploadPictureCompletion) {
        let path = dir + "/" + fileName
        storage.child("\(path)").putFile(from: fileUrl,
                                         completion: { [weak self] metadata, error in
            guard error == nil else {
                print("failed to upload video to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("\(path)").downloadURL(completion: {url, error in
                guard let url = url, error == nil else {
                    print("Successfully uploaded video, but failed to get the download url")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("got back video download url: \(urlString)")
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
