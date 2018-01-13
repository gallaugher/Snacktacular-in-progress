//
//  PhotoViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 12/1/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit
import Firebase

class PhotoViewController: UIViewController {
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var descriptionField: UITextField!
    @IBOutlet weak var postedOnLabel: UILabel!
    @IBOutlet weak var postedByLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    
    var photo: Photo!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        if let photo = photo {
            photoImageView.image = photo.image
            descriptionField.text = photo.imageDescription
            postedByLabel.text = "posted by: \(photo.postedBy)"
            postedOnLabel.text = "posted on: \(photo.date)"
            let currentUser = Auth.auth().currentUser
            if currentUser?.email == photo.postedBy {
                descriptionField.isEnabled = true
                descriptionField.becomeFirstResponder()
                if photo.imageDocumentID != "" {
                    deleteButton.isHidden = false
                }
                // hides the <Back button
                self.navigationItem.leftItemsSupplementBackButton = false
            } else {
                descriptionField.isEnabled = false
                // hides the cancel and save buttons
                self.saveBarButton.title = ""
                self.cancelBarButton.title = ""
                deleteButton.isHidden = true
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        photo.imageDescription = descriptionField.text!
    }
}
