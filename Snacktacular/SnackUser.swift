//
//  SnackUser.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/15/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import Foundation
import Firebase

class SnackUser {
    var email: String
    var displayName: String
    var photoURL: String
    var userSince: Date
    
    var dictionary: [String: Any] {
        return ["email": email, "displayName": displayName, "photoURL": photoURL, "userSince": userSince]
    }
    
    init(email: String, displayName: String, photoURL: String, userSince: Date) {
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.userSince = userSince
    }
    
    convenience init (user: User) {
        self.init(email: user.email ?? "", displayName: user.displayName ?? "", photoURL: ((user.photoURL != nil) ? "\(user.photoURL!)" : ""), userSince: Date())
    }
    
    func saveData()  {
        let db = Firestore.firestore()
        
        // Grab the unique userID
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ERROR: in SnackUser.saveData - couldn't get currentUser.uid")
            return // this should never happen
        }
        // Create the dictionary representing data we want to save
        let dataToSave: [String: Any] = self.dictionary
        let userRef = db.collection("users").document(userID).setData(dataToSave) { (error) in
            if let error = error {
                print("ERROR: adding user \(error.localizedDescription) with userID \(userID)")
            }
        }
    }
}
