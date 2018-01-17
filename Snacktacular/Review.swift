//
//  Review.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/2/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import Foundation
import Firebase

class Review {
    var reviewHeadline: String
    var reviewText: String
    var rating: Int
    var reviewBy: String
    var reviewDocumentID: String
    var date: Date
    
    var dictionary: [String: Any] {
        return ["reviewHeadline": reviewHeadline, "reviewText": reviewText, "rating": rating, "reviewBy": reviewBy, "date": date]
    }
    
    init(reviewHeadline: String, reviewText: String, rating: Int, reviewBy: String, reviewDocumentID: String, date: Date) {
        self.reviewHeadline = reviewHeadline
        self.reviewText = reviewText
        self.rating = rating
        self.reviewBy = reviewBy
        self.reviewDocumentID = reviewDocumentID
        self.date = Date()
    }
    
    convenience init(dictionary: [String: Any]) {
        let reviewHeadline = dictionary["reviewHeadline"] as! String? ?? ""
        let reviewText = dictionary["reviewText"] as! String? ?? ""
        let rating = dictionary["rating"] as! Int? ?? 0
        let reviewBy = dictionary["reviewBy"] as! String? ?? ""
        let date = dictionary["date"] as! Date? ?? Date()
        self.init(reviewHeadline: reviewHeadline, reviewText: reviewText, rating: rating, reviewBy: reviewBy, reviewDocumentID: "", date: date)
    }
    
    convenience init(reviewBy: String) {
        let reviewBy = Auth.auth().currentUser?.uid ?? "" // New review? It must be posted by the current user.
        self.init(reviewHeadline: "", reviewText: "", rating: 0, reviewBy: reviewBy, reviewDocumentID: "", date: Date())
    }
    
    func getPostedBy(completion: @escaping (SnackUser?) -> ()) {
        var postingUser: SnackUser?
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(self.reviewBy)
        userRef.getDocument { (document, error) in
            guard let document = document else {
                print("ERROR: couldn't find user \(self.reviewBy)")
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
    
    func documentReference(leadingRef: DocumentReference) -> DocumentReference {
        var reviewRef: DocumentReference!
        // if new review, create documentID
        if self.reviewDocumentID == "" {
            reviewRef = leadingRef.collection("reviews").document()
            self.reviewDocumentID = reviewRef.documentID
        } else { // otherwise get the ref for the existing review
            reviewRef = leadingRef.collection("reviews").document(self.reviewDocumentID)
        }
        return reviewRef
    }
    
    func saveReview(place: Place){
        let reviewRef = documentReference(leadingRef: place.documentReference())
        let reviewToSave: [String: Any] = self.dictionary
        reviewRef.setData(reviewToSave) { (error) in
            if let error = error {
                print("ERROR: updating review \(error.localizedDescription)")
            } else {
                print("Review updated with reviewDocumentID \(self.reviewDocumentID)")
            }
        }
    }
    
    func deleteReview(leadingRef: DocumentReference) {
        let reviewRef = leadingRef.collection("reviews").document(self.reviewDocumentID)
        reviewRef.delete() { err in
            if let err = err {
                print("Error removing document: \(self.reviewDocumentID), error: \(err)")
            } else {
                print("^^^ Document \(self.reviewDocumentID) successfully removed!")
            }
        }
    }
    
}
