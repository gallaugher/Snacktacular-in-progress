//
//  Place.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import Firebase

class Place: NSObject, MKAnnotation {
    var placeName: String
    var address: String
    var postingUserID: String
    var coordinate: CLLocationCoordinate2D
    var placeDocumentID: String
    var averageRating: Double
    var numberOfReviews: Int
    
    var title: String? {
        return placeName
    }
    
    var subtitle: String? {
     return address
    }
    
    var latitude: CLLocationDegrees {
        return coordinate.latitude
    }
    
    var longitude: CLLocationDegrees {
        return coordinate.longitude
    }
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var dictionary: [String: Any] {
        return ["placeName": placeName, "address": address, "postingUserID": postingUserID, "latitude": latitude, "longitude": longitude, "averageRating": averageRating, "numberOfReviews": numberOfReviews]
    }
    
    init(placeName: String, address: String, coordinate: CLLocationCoordinate2D, postingUserID: String, placeDocumentID: String, averageRating: Double, numberOfReviews: Int) {
        self.placeName = placeName
        self.address = address
        self.coordinate = coordinate
        self.postingUserID = postingUserID
        self.placeDocumentID = placeDocumentID
        self.averageRating = averageRating
        self.numberOfReviews = numberOfReviews
    }
    
    convenience override init() {
        let db = Firestore.firestore()
        let placeDocRef = db.collection("places").document().documentID
        let postingUserID = Auth.auth().currentUser?.uid ?? ""
        self.init(placeName: "", address: "", coordinate: CLLocationCoordinate2D(), postingUserID: postingUserID, placeDocumentID: placeDocRef, averageRating: 0.0, numberOfReviews: 0)
    }
    
    convenience init(dictionary: [String: Any]) {
        let placeName = dictionary["placeName"] as! String? ?? ""
        let address = dictionary["address"] as! String? ?? ""
        let postingUserID = dictionary["postingUserID"] as! String? ?? ""
        let latitude = dictionary["latitude"] as! CLLocationDegrees? ?? 0.0
        let longitude = dictionary["longitude"] as! CLLocationDegrees? ?? 0.0
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placeDocumentID = dictionary["placeDocumentID"] as! String? ?? ""
        let averageRating = dictionary["averageRating"] as! Double? ?? 0.0
        let numberOfReviews = dictionary["numberOfReviews"] as! Int? ?? 0
        self.init(placeName: placeName, address: address, coordinate: coordinate, postingUserID: postingUserID, placeDocumentID: placeDocumentID, averageRating: averageRating, numberOfReviews: numberOfReviews)
    }
    
    func documentReference() -> DocumentReference {
        let db = Firestore.firestore()
        let placeRef: DocumentReference!
//         placeDocumentID was set during Place()
        placeRef = db.collection("places").document(self.placeDocumentID)
//        if self.placeDocumentID == "" {
//            placeRef = db.collection("places").document()
//            self.placeDocumentID = placeRef.documentID
//        } else { // otherwise get the ref for the existing review
//            placeRef = db.collection("places").document(self.placeDocumentID)
//        }
        return placeRef
    }
    
    func getAvgReview(completed: @escaping (Double) -> ()) {
        let db = Firestore.firestore()
        var dictionary = [String: Any]()
        let placeRef = db.collection("places").document(self.placeDocumentID)
        placeRef.getDocument { (document, error) in
            guard let document = document else {
                print("*** ERROR: Document \(self.placeDocumentID) does not exist. \(error!.localizedDescription)")
                return
            }
            if document.exists {
                dictionary = document.data()
            }
            completed(dictionary["averageRating"] as! Double? ?? 0.0)
        }
    }
    
    func saveData(completion: @escaping () -> ())  {
        let db = Firestore.firestore()
        
         // Grab the unique userID
                if let postingUserID = (Auth.auth().currentUser?.uid) {
                    self.postingUserID = postingUserID
                } else {
                    self.postingUserID = "unknown user"
                }
        
        // Create the dictionary representing data we want to save
        let dataToSave: [String: Any] = self.dictionary
        
        // if we HAVE saved a record, we'll have an ID
        if self.placeDocumentID != "" {
            let ref = db.collection("places").document(self.placeDocumentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("ERROR: updating document \(error.localizedDescription)")
                } else {
                    print("Document updated with reference ID \(ref.documentID)")
                }
                completion()
            }
        } else { // Otherwise we don't have a document ID so we need to create the ref ID and save a new document
            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
            ref = db.collection("places").addDocument(data: dataToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                } else {
                    self.placeDocumentID = "\(ref!.documentID)"
                }
                completion()
            }
        }
    }
}
