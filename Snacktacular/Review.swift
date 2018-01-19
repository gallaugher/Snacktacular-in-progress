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
//
//        let db = Firestore.firestore()
//
//
//        // Create the dictionary representing data we want to save
//        let dataToSave: [String: Any] = place.dictionary
//
//        // if we HAVE saved a record, we'll have an ID
//        if place.placeDocumentID != "" {
//            let ref = db.collection("places").document(place.placeDocumentID)
//            ref.setData(dataToSave) { (error) in
//                if let error = error {
//                    print("ERROR: updating document \(error.localizedDescription)")
//                } else {
//                    print("Document updated with reference ID \(ref.documentID)")
//                }
//            }
//        } else { // Otherwise we don't have a document ID so we need to create the ref ID and save a new document
//            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
//            ref = db.collection("places").addDocument(data: dataToSave) { (error) in
//                if let error = error {
//                    print("ERROR: adding document \(error.localizedDescription)")
//                } else {
//                    place.placeDocumentID = "\(ref!.documentID)"
//                }
//            }
//        }
//
        
        let db = Firestore.firestore()
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            // Read data from Firestore inside the transaction, so we don't accidentally
            // update using stale client data. Error if we're unable to read here.
            // let placeRef = place.documentReference()
            
            let placeRef = db.collection("places").document(place.placeDocumentID)
//            let placeSnapshot = try? transaction.getDocument(placeRef)

            transaction.setData(place.dictionary, forDocument: placeRef)
//            do {
//                // try placeSnapshot = transaction.getDocument(placeRef)
//            } catch let error as NSError {
//                errorPointer?.pointee = error
//                print("*** ERROR: in updateReview trying to get place documentReference: \(error.localizedDescription)")
//                return nil
//            }
            
            // Get latest place data in case something was recently updated.
            // Save it in a separate tempPlace object so we keep our reference to the original place (which has a valid documentReference
//            let tempPlace = Place(dictionary: placeSnapshot.data())
            
            // Update the restaurant's rating and rating count and post the new review at the
            // same time.
            let newAverage = (Double(place.numberOfReviews) * place.averageRating + Double(self.rating))
                / Double(place.numberOfReviews + 1)
            place.averageRating = newAverage
            place.numberOfReviews += 1
            print(" >>> newAverage = \(place.averageRating)")
            print(" >>> place.numberOfReviews = \(place.numberOfReviews)")
            let reviewRef = self.documentReference(leadingRef: place.documentReference())
            transaction.setData(self.dictionary, forDocument: reviewRef)
            transaction.updateData([
                "averageRating": place.averageRating,
                "numberOfReviews": place.numberOfReviews
                ], forDocument: place.documentReference())
            return nil
        }) { (object, error) in
            if let error = error {
                print("*** ERROR: problem executing transaction in review.saveReview. \(error.localizedDescription)")
            } else {
                print("^^^ Looks like transaction save succeeded!")
            }
        }
    }
    
    func updateReview(place: Place){
        let db = Firestore.firestore()
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            // getOldReview value
            let reviewSnapshot: DocumentSnapshot
            do {
                try reviewSnapshot = transaction.getDocument(self.documentReference(leadingRef: place.documentReference()))
            } catch let error as NSError {
                errorPointer?.pointee = error
                print("*** ERROR: in saveReview trying to get place documentReference: \(error.localizedDescription)")
                return nil
            }
            guard let oldRating = reviewSnapshot.data()["rating"] as? Int else {
                print("*** ERROR: getting oldRating in Review.updateReview")
                return nil
            }
            
            // Read data from Firestore inside the transaction, so we don't accidentally
            // update using stale client data. Error if we're unable to read here.
            let placeSnapshot: DocumentSnapshot
            do {
                try placeSnapshot = transaction.getDocument(place.documentReference())
            } catch let error as NSError {
                errorPointer?.pointee = error
                print("*** ERROR: in updateReview trying to get place documentReference: \(error.localizedDescription)")
                return nil
            }
            
            // Get latest place data in case something was recently updated.
            // Save it in a separate tempPlace object so we keep our reference to the original place (which has a valid documentReference
            let tempPlace = Place(dictionary: placeSnapshot.data())
            
            // Update the restaurant's rating and rating count and post the new review at the
            // same time.
            let newSumOfRatings = Double(tempPlace.numberOfReviews) * tempPlace.averageRating - Double(oldRating) + Double(self.rating)
            let newAverage = newSumOfRatings / Double(tempPlace.numberOfReviews)
            place.averageRating = newAverage
            print(" >>> newAverage = \(place.averageRating)")
            print(" >>> place.numberOfReviews = \(place.numberOfReviews)")
            let reviewRef = self.documentReference(leadingRef: place.documentReference())
            transaction.setData(self.dictionary, forDocument: reviewRef)
            transaction.updateData([
                "averageRating": place.averageRating
                ], forDocument: place.documentReference())
            return nil
        }) { (object, error) in
            if let error = error {
                print("*** ERROR: problem executing transaction in review.updateReview. \(error.localizedDescription)")
            } else {
                print("^^^ Looks like transaction save succeeded!")
            }
        }
    }
    
    func deleteReview(place: Place) {
        let db = Firestore.firestore()
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Read data from Firestore inside the transaction, so we don't accidentally
            // update using stale client data. Error if we're unable to read here.
            let placeSnapshot: DocumentSnapshot
            do {
                try placeSnapshot = transaction.getDocument(place.documentReference())
            } catch let error as NSError {
                errorPointer?.pointee = error
                print("*** ERROR: in saveReview trying to get place documentReference: \(error.localizedDescription)")
                return nil
            }
            
            // Get latest place data in case something was recently updated.
            // Save it in a separate tempPlace object so we keep our reference to the original place (which has a valid documentReference
            let tempPlace = Place(dictionary: placeSnapshot.data())
            
            // Update the restaurant's rating and rating count and post the new review at the
            // same time.
            let newAverage = (Double(tempPlace.numberOfReviews) * tempPlace.averageRating - Double(self.rating))
                / Double(tempPlace.numberOfReviews - 1)
            place.averageRating = newAverage
            place.numberOfReviews -= 1
            print(" >>> newAverage = \(place.averageRating)")
            print(" >>> place.numberOfReviews = \(place.numberOfReviews)")
            let reviewRef = self.documentReference(leadingRef: place.documentReference())
            transaction.deleteDocument(reviewRef)
            transaction.updateData([
                "averageRating": place.averageRating,
                "numberOfReviews": place.numberOfReviews
                ], forDocument: place.documentReference())
            return nil
        }) { (object, error) in
            if let error = error {
                print("*** ERROR: problem executing transaction in review.deleteReview. \(error.localizedDescription)")
            } else {
                print("^^^ Looks like transaction deletion succeeded!")
            }
        }
        
        
//        let reviewRef = leadingRef.collection("reviews").document(self.reviewDocumentID)
//        reviewRef.delete() { err in
//            if let err = err {
//                print("Error removing document: \(self.reviewDocumentID), error: \(err)")
//            } else {
//                print("^^^ Document \(self.reviewDocumentID) successfully removed!")
//            }
//        }
    }
    
}
