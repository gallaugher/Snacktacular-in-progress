//
//  UserProfileViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/18/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit

class UserProfileViewController: UIViewController {

    @IBOutlet weak var displayNameLabel: UILabel!
    var snackUser: SnackUser!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var memberSinceLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    
    let dateFormatter = DateFormatter()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard snackUser != nil else {
            print("*** ERROR: snackUser was nil in UserProfileViewController")
            return
        }
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        displayNameLabel.text = snackUser.displayName
        emailLabel.text = snackUser.email
        memberSinceLabel.text = dateFormatter.string(from: snackUser.userSince)
        
        let url = URL(string: snackUser.photoURL)
        let data = try? Data(contentsOf: url!) // make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
        profileImage.image = UIImage(data: data!)
    }

}
