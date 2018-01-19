//
//  UsersListViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 1/18/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit
import Firebase

class UsersListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var users = [SnackUser]()
    var db = Firestore.firestore()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        checkForUsers()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier! == "ShowSnackUser" {
            let destination = segue.destination as! UserProfileViewController
            destination.snackUser = users[tableView.indexPathForSelectedRow!.row]
        }
    }
    
    func checkForUsers() {
        db.collection("users").addSnapshotListener { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: adding the snapshot listener \(error!.localizedDescription)")
                return
            }
            self.users = []
            for document in querySnapshot!.documents {
                let snackUser = SnackUser(dictionary: document.data())
                self.users.append(snackUser)
            }
            self.tableView.reloadData()
        }
    }
}

extension UsersListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        cell.textLabel?.text = users[indexPath.row].displayName
        cell.detailTextLabel?.text = users[indexPath.row].email
        return cell
    }
}
