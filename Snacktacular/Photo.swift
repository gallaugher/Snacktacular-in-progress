//
//  Photo.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/12/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import Foundation
import UIKit

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
}
