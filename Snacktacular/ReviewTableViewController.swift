//
//  ReviewTableViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/3/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit
import Firebase

class ReviewTableViewController: UITableViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var reviewContentView: UITextView!
    @IBOutlet weak var reviewTitleLabel: UITextField!
    @IBOutlet var starButtonCollection: [UIButton]!
    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    @IBOutlet weak var starBackgroundView: UIView!
    @IBOutlet weak var reviewedByLabel: UILabel!
    @IBOutlet weak var deleteReviewButton: UIButton!
    
    var review: Review!
    var name: String!
    var address: String!
    var currentUser = Auth.auth().currentUser
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        if (review) != nil {
            configureUserInterface()
        } else {
            // This is a new review
            // Temporarily set reviewDocumentID to an empty string. We'll create an ID when saving the review in DeetailViewController
            review = Review(reviewHeadline: "", reviewText: "", rating: 0, reviewBy: Auth.auth().currentUser?.email ?? "", reviewDocumentID: "")
        }
    }
    
    func configureUserInterface() {
        reviewTitleLabel.text = review.reviewHeadline
        reviewContentView.text = review.reviewText
        nameLabel.text = name
        addressLabel.text = address
        // update buttons
        for button in starButtonCollection {
            if button.tag <= review.rating-1 {
                button.setImage(UIImage(named: "star-filled"), for: .normal)
            }
        }
        //TODO: - update below so instead of string, it compares against real UserID
        //If person viewing left the review, show save & cancel and get rid of the < button
        if review.reviewBy == "\((currentUser?.email)!)" {
            saveBarButton.title = "Update"
            self.navigationItem.leftItemsSupplementBackButton = false
            addBorder(view: reviewContentView, alpha: 1.0)
            addBorder(view: reviewTitleLabel, alpha: 1.0)
            addBorder(view: starBackgroundView, alpha: 1.0)
            deleteReviewButton.isHidden = false
        } else { // hide save & cancel
            reviewedByLabel.text = "review by: " + review.reviewBy
            self.saveBarButton.title = ""
            self.cancelBarButton.title = ""
            reviewTitleLabel.isUserInteractionEnabled = false
            reviewContentView.isEditable = false
            reviewTitleLabel.backgroundColor = UIColor.clear
            reviewTitleLabel.borderStyle = UITextBorderStyle.none
            reviewContentView.backgroundColor = UIColor.clear
            starBackgroundView.backgroundColor = UIColor.clear
            for button in starButtonCollection {
                button.adjustsImageWhenDisabled = false
                button.isEnabled = false
            }
        }
    }
    
    func addBorder(view: UIView, alpha: CGFloat) {
        let borderColor : UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: alpha)
        view.layer.borderWidth = 0.5
        view.layer.borderColor = borderColor.cgColor
        view.layer.cornerRadius = 5.0
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        review.reviewHeadline = reviewTitleLabel.text!
        review.reviewText = reviewContentView.text!
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        let isPrestingInAddMode = presentingViewController is UINavigationController
        if isPrestingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func starPressed(_ sender: UIButton) {
        review.rating = Int(sender.tag)
        for button in starButtonCollection {
            if button.tag <= sender.tag {
                button.setImage(UIImage(named: "star-filled"), for: .normal)
            } else {
                button.setImage(UIImage(named: "star-empty"), for: .normal)
            }
        }
    }
    
    @IBAction func deleteReviewPressed(_ sender: UIButton) {
        
    }
}
