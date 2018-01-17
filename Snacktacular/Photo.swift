//
//  Photo.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/12/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class Photo {
    var image: UIImage!
    var imageDocumentID: String!
    var imageDescription: String
    var postedBy: String
    var date: Date
    
    var dictionary: [String: Any] {
        return ["imageDocumentID": imageDocumentID, "imageDescription": imageDescription, "postedBy": postedBy, "date": date]
    }
    
    convenience init(dictionary: [String: Any]) {
        let image = UIImage()
        let imageDocumentID = dictionary["imageDocumentID"] as! String? ?? ""
        let imageDescription = dictionary["imageDescription"] as! String? ?? ""
        let postedBy = dictionary["postedBy"] as! String? ?? ""
        let date = dictionary["date"] as! Date? ?? Date()
        self.init(image: image, imageDocumentID: imageDocumentID, imageDescription: imageDescription, postedBy: postedBy, date: date)
    }
    
    init(image: UIImage, imageDocumentID: String, imageDescription: String, postedBy: String, date: Date) {
        self.image = image
        self.imageDocumentID = imageDocumentID
        self.imageDescription = imageDescription
        self.postedBy = postedBy
        self.date = date
    }
    
    convenience init(postedBy: String) {
        let postedBy = Auth.auth().currentUser?.uid ?? "" // New review? It must be posted by the current user.
        self.init(image: UIImage(), imageDocumentID: "", imageDescription: "", postedBy: postedBy, date: Date())
    }
    
    private func savePhotoRef(leadingRef: DocumentReference) {
        // 1. What's the data we're going to save? photoToSave
        // images are never updated, just saved or deleted, so no need to deal with updating.
        let photoToSave = self.dictionary
        // 2. Where are we going to save it? photoRef
        let photoRef = leadingRef.collection("images").document(self.imageDocumentID)
        // 3. Save it & check the result
        photoRef.setData(photoToSave) { (error) in
            if let error = error {
                print("ERROR: adding document \(error.localizedDescription)")
            } else {
                print("Document added for place \(leadingRef.documentID) and image \(photoRef.documentID)")
            }
        }
    }
    
    func savePhoto(leadingRef: DocumentReference) {
        // Get a unique name for the Photo
        self.imageDocumentID = NSUUID().uuidString+".jpg" // always creates a unique string in part based on time/date
        // 1. What's the data we're going to save (to Storage)? photoData
        // Convert image to type Data so it can be saved to Storage
        guard let photoData = UIImageJPEGRepresentation(self.image, 0.8) else {
            print("*** ERROR: creating imageData from JPEGRepresentation")
            return
        }
        // 2. Where are we going to save it (to Storage, not Firestore)? placeStorageRef
        let storage = Storage.storage()
        let placeStorageRef = storage.reference().child(leadingRef.documentID)
        // Create a ref to the file you want to upload
        let photoStorageRef = placeStorageRef.child(self.imageDocumentID)
        // 3. Save it & check the result
        photoStorageRef.putData(photoData, metadata: nil) { (metadata, error) in
            if let error = error {
                print("*** ERROR: \(error.localizedDescription) saving image \(self.imageDocumentID) to StorageReference \(placeStorageRef).")
            }
            self.savePhotoRef(leadingRef: leadingRef)
        }
    }
    
    func getPostedBy(completion: @escaping (SnackUser?) -> ()) {
        var postingUser: SnackUser?
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(self.postedBy)
        userRef.getDocument { (document, error) in
            guard let document = document else {
                print("ERROR: couldn't find user \(self.postedBy)")
                completion(nil)
                return
            }
            if document.exists {
                postingUser = SnackUser(dictionary: document.data())
            } else {
                postingUser = nil
            }
            completion(postingUser)
        }
    }
    
    func deletePhoto(leadingRef: DocumentReference) {
        let storage = Storage.storage()
        let photoRef = leadingRef.collection("images").document(self.imageDocumentID)
        photoRef.delete() { err in
            if let err = err {
                print("Error removing document: \(self.imageDocumentID), error: \(err)")
            } else {
                print("^^^ Document \(self.imageDocumentID) successfully removed!")
            }
        }
        let placeStorageRef = storage.reference().child(leadingRef.documentID).child(self.imageDocumentID)
        // Delete the file
        placeStorageRef.delete { error in
            if let error = error {
                print("*** ERROR: \(error.localizedDescription) In deletePhoto trying to delete \(placeStorageRef)")
            } else {
                print("Successfully deleted selected photo")
            }
        }
    }
}
