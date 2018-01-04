//
//  ReviewTableViewCell.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/2/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet weak var reviewHeadlineLabel: UILabel!
    // @IBOutlet weak var reviewerLabel: UILabel!    
    @IBOutlet weak var reviewTextLabel: UILabel!

    @IBOutlet var starCollection: [UIImageView]!
    
}
