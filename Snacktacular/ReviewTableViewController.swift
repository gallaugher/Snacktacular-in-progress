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
    @IBOutlet weak var reviewDateLabel: UILabel!
    
    var review: Review!
    var place: Place!
    var postingUser: SnackUser?
//    var name: String!
//    var address: String!
    var currentUser = Auth.auth().currentUser
    let dateFormatter = DateFormatter()
    var newReview = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Clear out all buttons in navigation bar, otherwise they'll flash a bit since configuration doesn't happen until after a Firestore call for review.getPostedBy()
        self.saveBarButton.title = ""
        self.cancelBarButton.title = ""
        
        // Set up DateFormatter
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        guard place != nil else {
            print("*** ERROR: for some reason place was nil when ReviewTableViewController loaded.")
            return
        }
        
        if review == nil {
            newReview = true
            // Hide the back button & show Save & Cancel
            self.navigationItem.leftItemsSupplementBackButton = false
            self.saveBarButton.title = "Save"
            self.cancelBarButton.title = "Cancel"
            // Create new review by currentUser
            review = Review(reviewBy: currentUser!.uid)
        } else {
            if review.reviewBy == Auth.auth().currentUser?.uid {
                self.navigationItem.leftItemsSupplementBackButton = false
                self.saveBarButton.title = "Update"
                self.cancelBarButton.title = "Cancel"
            }
        }
        review.getPostedBy() { (postingUser) in
            self.postingUser = postingUser
            self.configureUserInterface()
        }
    }
    
    func configureUserInterface() {
        reviewTitleLabel.text = review.reviewHeadline
        reviewContentView.text = review.reviewText
        nameLabel.text = place.placeName
        addressLabel.text = place.address
//        nameLabel.text = name
//        addressLabel.text = address
        
        let formattedDate = dateFormatter.string(from: review.date)
        reviewDateLabel.text = "posted: \(formattedDate)"
        
        // update buttons
        for button in starButtonCollection {
            if button.tag <= review.rating {
                button.setImage(UIImage(named: "star-filled"), for: .normal)
            }
        }
        //TODO: - update below so instead of string, it compares against real UserID
        //If person viewing now also left the review, show save & cancel and get rid of the < button
        if review.reviewBy == "\(currentUser!.uid)" {
            // if the headline isn't blank, there must be a review, so "Save" button should read "Update"
            
            self.cancelBarButton.title = "Cancel"
            
            if review.reviewHeadline != "" { // This must be an update since headline isn't blank
                saveBarButton.title = "Update"
                deleteReviewButton.isHidden = false
            } else {
                self.saveBarButton.title = "Save"
            }
            self.navigationItem.leftItemsSupplementBackButton = false
            addBorder(view: reviewContentView, alpha: 1.0)
            addBorder(view: reviewTitleLabel, alpha: 1.0)
            addBorder(view: starBackgroundView, alpha: 1.0)
        } else { // hide save & cancel
            if postingUser != nil {
                reviewedByLabel.text = "review by: " + postingUser!.email
            } else {
                reviewedByLabel.text = "review by: " + review.reviewBy
            }
            self.saveBarButton.title = ""
            self.cancelBarButton.title = ""
            self.navigationItem.leftItemsSupplementBackButton = true
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
        enableDisableSaveButton()
    }
    
    func addBorder(view: UIView, alpha: CGFloat) {
        let borderColor : UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: alpha)
        view.layer.borderWidth = 0.5
        view.layer.borderColor = borderColor.cgColor
        view.layer.cornerRadius = 5.0
    }
    
    func enableDisableSaveButton() {
        if reviewTitleLabel.text != "" && review.rating > 0 {
            saveBarButton.isEnabled = true
        } else {
            saveBarButton.isEnabled = false
        }
    }
    
    @IBAction func reviewTitleChanged(_ sender: UITextField) {
        enableDisableSaveButton()
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
        enableDisableSaveButton()
    }
    
    @IBAction func saveBarButtonPressed(_ sender: UIBarButtonItem) {
        //Update review values that the user has entered or updated
        review.reviewHeadline = reviewTitleLabel.text!
        review.reviewText = reviewContentView.text!
        
        if newReview {
            review.saveReview(place: place)
            // Since we got here via Present Modally segue (e.g. "Add" mode):
            dismiss(animated: true, completion: nil)
        } else {
            review.updateReview(place: place)
            // Since we got here via Show segue:
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func deleteReviewPressed(_ sender: UIButton) {
        review.deleteReview(place: place)
        // Since we got here via Show segue:
        navigationController?.popViewController(animated: true)
    }
    
}
