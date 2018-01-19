//
//  PhotoTableViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/13/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit
import Firebase

class PhotoTableViewController: UITableViewController {
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var descriptionField: UITextField!
    @IBOutlet weak var postedOnLabel: UILabel!
    @IBOutlet weak var postedByLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    
    var place: Place!
    var photo: Photo!
    var currentUser = Auth.auth().currentUser
    var postingUser: SnackUser?
    let dateFormatter = DateFormatter()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard place != nil else {
            print("*** ERROR: for some reason place was nil when PhotoTableViewController loaded.")
            return
        }
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Set up DateFormatter
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        if photo == nil { // should not happen - we always pass in a photo value, or create a new one for "AddPhoto"
            // Create new review by currentUser
            photo = Photo(postedBy: currentUser!.uid)
        } else {
            photoImageView.image = photo.image
            descriptionField.text = photo.imageDescription
        }
        photo.getPostedBy() { (postingUser) in
            self.postingUser = postingUser
            self.configureUserInterface()
        }
    }
    
    func configureUserInterface() {
        photoImageView.image = photo.image
        descriptionField.text = photo.imageDescription
        postedByLabel.text = "\(postingUser!.email)"
        let formattedDate = dateFormatter.string(from: photo.date)
        postedOnLabel.text = "\(formattedDate)"
        
        if Auth.auth().currentUser?.uid == photo.postedBy {
            if photo.imageDocumentID != "" { // User is looking a photo they posted
                deleteButton.isHidden = false
                descriptionField.isEnabled = false
                // hides the cancel and save buttons
                self.saveBarButton.title = ""
                self.cancelBarButton.title = ""
            } else { // otherwise this is a new photo
                deleteButton.isHidden = true
                descriptionField.isEnabled = true
                descriptionField.becomeFirstResponder()
                // hides the <Back button
                self.navigationItem.leftItemsSupplementBackButton = false
            }
        } else {
            descriptionField.isEnabled = false
            // hides the cancel and save buttons
            self.saveBarButton.title = ""
            self.cancelBarButton.title = ""
            deleteButton.isHidden = true
        }
        enableDisableSaveButton()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        photo.imageDescription = descriptionField.text!
        if segue.identifier == "SavePhotoUnwind" {
            photo.savePhoto(place: place)
        }
    }
    
    func enableDisableSaveButton() {
        if descriptionField.text != "" {
            saveBarButton.isEnabled = true
        } else {
            saveBarButton.isEnabled = false
        }
    }
    
    @IBAction func cancelBarButtonPressed(_ sender: UIBarButtonItem) {
        let isPrestingInAddMode = presentingViewController is UINavigationController
        if isPrestingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func descriptionChanged(_ sender: UITextField) {
        enableDisableSaveButton()
    }
    

    
    @IBAction func deleteButtonPressed(_ sender: UIButton) {
        photo.deletePhoto(place: place)
        // Since we got here via Show segue (only way to display existing photo, which displays the "Delete" button):
        navigationController?.popViewController(animated: true)
    }
    
}
