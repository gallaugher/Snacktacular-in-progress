//
//  Review.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/2/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import Foundation

class Review {
    var reviewHeadline: String
    var reviewText: String
    var rating: Int
    var reviewBy: String
    var reviewDocumentID: String
    
    var dictionary: [String: Any] {
        return ["reviewHeadline": reviewHeadline, "reviewText": reviewText, "rating": rating, "reviewBy": reviewBy]
    }
    
    init(reviewHeadline: String, reviewText: String, rating: Int, reviewBy: String, reviewDocumentID: String) {
        self.reviewHeadline = reviewHeadline
        self.reviewText = reviewText
        self.rating = rating
        self.reviewBy = reviewBy
        self.reviewDocumentID = reviewDocumentID
    }
    
    convenience init(dictionary: [String: Any]) {
        let reviewHeadline = dictionary["reviewHeadline"] as! String? ?? ""
        let reviewText = dictionary["reviewText"] as! String? ?? ""
        let rating = dictionary["rating"] as! Int? ?? 0
        let reviewBy = dictionary["reviewBy"] as! String? ?? ""
        self.init(reviewHeadline: reviewHeadline, reviewText: reviewText, rating: rating, reviewBy: reviewBy, reviewDocumentID: "")
    }
}
