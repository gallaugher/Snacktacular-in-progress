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
    
    var photo: Photo!
    let dateFormatter = DateFormatter()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Set up DateFormatter
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        if let photo = photo {
            photoImageView.image = photo.image
            descriptionField.text = photo.imageDescription
            
            postedByLabel.text = "\(photo.postedBy)"
            let formattedDate = dateFormatter.string(from: photo.date)
            postedOnLabel.text = "\(formattedDate)"
            let currentUser = Auth.auth().currentUser
            if currentUser?.uid == photo.postedBy {
                if photo.imageDocumentID != "" {
                    deleteButton.isHidden = false
                    descriptionField.isEnabled = false
                    // hides the cancel and save buttons
                    self.saveBarButton.title = ""
                    self.cancelBarButton.title = ""
                } else {
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
        }
        enableDisableSaveButton()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        photo.imageDescription = descriptionField.text!
    }
    
    func enableDisableSaveButton() {
        if descriptionField.text != "" {
            saveBarButton.isEnabled = true
        } else {
            saveBarButton.isEnabled = false
        }
    }
    
    @IBAction func descriptionChanged(_ sender: UITextField) {
        enableDisableSaveButton()
    }
    
}
