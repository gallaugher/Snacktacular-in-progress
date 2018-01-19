 //
//  PlaceListViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import CoreLocation

class PlaceListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortSegmentControl: UISegmentedControl!
    @IBOutlet weak var signOutBarButton: UIBarButtonItem!
    
    var places = [Place]()
    var authUI: FUIAuth!
    var db: Firestore!
    var storage: Storage!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureLeftBarButtonItems() // needed to create smaller space
        db = Firestore.firestore()
        storage = Storage.storage()
        authUI = FUIAuth.defaultAuthUI()
        // You need to adopt a FUIDelegate protocol to receive callback
        authUI?.delegate = self
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkForUpdates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        signIn()
        getLocation()
        sortBasedOnSegmentPressed()
    }
    
    // Return a square bar button item of dimension passed (which should be 25 for standard
    func configureImageBarButton(imageName: String, selector: Selector, dimension: CGFloat) -> UIBarButtonItem {
        let image = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal) // alwaysOriginal will preserve transparent background and layers
        let button = UIButton(type: UIButtonType.custom)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: dimension, height: dimension)
        let barButtonItem = UIBarButtonItem(customView: button)
        return barButtonItem
    }
    
    func configureLeftBarButtonItems() {
        var barButtonItemArray = [signOutBarButton!]
        barButtonItemArray.append(configureImageBarButton(imageName: "singleUserPDF", selector: #selector(singleUserPressed), dimension: 25))
        barButtonItemArray.append(configureImageBarButton(imageName: "usersPDF", selector: #selector(usersPressed), dimension: 25))
        navigationItem.leftBarButtonItems = barButtonItemArray
    }
    
    @objc func singleUserPressed() {
        performSegue(withIdentifier: "ShowSingleUser", sender: nil)
    }

    @objc func usersPressed() {
        performSegue(withIdentifier: "ShowUsersTable", sender: nil)
    }
    
    func signIn() {
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth()
            ]
        if authUI.auth?.currentUser == nil {
            self.authUI?.providers = providers
            present(authUI.authViewController(), animated: true, completion: nil)
        }
    }
    
    func saveUserIfNeeded() {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        let userRef = db.collection("users").document("\(currentUser.uid)")
        userRef.getDocument { (document, error) in
            guard error == nil else {
                print("error in query, but here's the result of document.exists \(document?.exists)")
                return
            }
            guard document?.exists == false else {
                print("Document exists for user \(currentUser.uid)")
                return
            }
            // No errors, but no document, so create new user
            let newUser = SnackUser(user: currentUser)
            newUser.saveData()
        }
    }
    
    func checkForUpdates() {
        db.collection("places").addSnapshotListener { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: adding the snapshot listener \(error!.localizedDescription)")
                return
            }
            self.places = []
            for document in querySnapshot!.documents {
                let place = Place(dictionary: document.data())
                place.placeDocumentID = document.documentID
                self.places.append(place)
            }
            self.sortBasedOnSegmentPressed()
        }
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "ShowDetail":
            let destination = segue.destination as! PlaceDetailViewController
            let selectedRow = tableView.indexPathForSelectedRow!.row
            destination.place = places[selectedRow]
        case "AddDetail":
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        case "ShowSingleUser":
            let destination = segue.destination as! UserProfileViewController
            destination.snackUser = SnackUser(user: Auth.auth().currentUser!)
        case "ShowUsersTable":
            print("Nothing to do for segue ShowUsersTable")
        default:
            print("This should not have happened. Segue named \(segue.identifier!) not accounted for in PlaceListViewController's prepare(for segue:)")
        }
    }
    
    func closestSort() {
        let sortedPlaces = places.sorted(by: {$0.location.distance(from: currentLocation) < $1.location.distance(from: currentLocation) } )
        places = sortedPlaces
        tableView.reloadData()
    }
    
    func sortBasedOnSegmentPressed() {
        switch sortSegmentControl.selectedSegmentIndex {

        case 0: // A-Z
            let sortedPlaces = places.sorted(by: {$0.placeName < $1.placeName})
            places = sortedPlaces
            tableView.reloadData()
        case 1: // closest
            if currentLocation != nil {
                closestSort()
                getLocation()
            } else {
                getLocation()
            }
        case 2: // averageRating
            let sortedPlaces = places.sorted(by: {$0.averageRating > $1.averageRating})
            places = sortedPlaces
            tableView.reloadData()
        default:
            print("HEY, you shouldn't have gotten her. Check out the segmented control for an error.")
        }
    }
    
    @IBAction func unwindFromPlaceDetail(segue: UIStoryboardSegue) {
//        let source = segue.source as! PlaceDetailViewController
//        source.place!.saveData {}
        switch segue.identifier! {
        case "SaveFromPlaceDetail":
            let source = segue.source as! PlaceDetailViewController
            let place = source.place
            place?.saveData{}
        case "CancelFromPlaceDetail":
            print("Cancelled, nothing saved from PlaceDetailViewController")
        default:
            print("default condition reached in unwindFromPlaceDetail - should have not happened.")
        }
    }
    
    @IBAction func signOutButtonPressed(_ sender: UIBarButtonItem) {
        do {
            try authUI!.signOut()
            print("^^^ Successfully signed out!")
            places = []
            tableView.reloadData()
            tableView.isHidden = true
            signIn()
        } catch {
            print("Couldn't sign out")
        }
    }
    
    @IBAction func sortSegmentPressed(_ sender: UISegmentedControl) {
        sortBasedOnSegmentPressed()
    }
    
 }

extension PlaceListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PlacesTableViewCell
        cell.placeNameLabel.text = places[indexPath.row].placeName
        var distanceInMiles = ""
        if currentLocation != nil {
            let distanceInMeters = self.places[indexPath.row].location.distance(from: currentLocation)
            distanceInMiles = "Distance: " + String(format: "%.2f", (distanceInMeters * 0.00062137)) + " miles"
        }
        cell.distanceLabel.text = distanceInMiles
        let avgRatingString = String(format: "%.1f", places[indexPath.row].averageRating)
        cell.avgRatingLabel.text = "Avg. Rating: " + avgRatingString
        return cell
    }
}

extension PlaceListViewController: FUIAuthDelegate {
    
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String?
        if FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: sourceApplication) ?? false {
            return true
        }
        // other URL handling goes here.
        return false
    }
    
    func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
        if let user = user {
            print("*** Successfully logged in with userID \(user.uid) email = \(user.email!)")
            tableView.isHidden = false
            saveUserIfNeeded()
        }
    }
    
    func authPickerViewController(forAuthUI authUI: FUIAuth) -> FUIAuthPickerViewController {
        let loginViewController = FUIAuthPickerViewController(authUI: authUI)
        loginViewController.view.backgroundColor = UIColor.white
        
        let marginInset: CGFloat = 16
        let imageY = self.view.center.y - 225
        
        let logoFrame = CGRect(x: self.view.frame.origin.x + marginInset, y: imageY, width: self.view.frame.width - (marginInset*2), height: 225)
        let logoImageView = UIImageView(frame: logoFrame)
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        loginViewController.view.addSubview(logoImageView)
        
        return loginViewController
    }
}
 
 extension PlaceListViewController: CLLocationManagerDelegate {
    
    func getLocation(){
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    func handleLocationAuthorizationStatus(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied:
            showAlertToPrivacySettings(title: "User has not authorized location services", message: "Select 'Settings' below to open device settings and enable location services for this app.")
        case .restricted:
            showAlert(title: "Location services denied", message: "It may be that parental controls are restricting location use in this app")
        }
    }
    
    func showAlertToPrivacySettings(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            print("Something went wrong getting the UIApplicationOpenSettingsURLString")
            return
        }
        let settingsActions = UIAlertAction(title: "Settings", style: .default) { value in
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(settingsActions)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleLocationAuthorizationStatus(status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        print("CURRENT LOCATION = \(currentLocation.coordinate.latitude) \(currentLocation.coordinate.longitude)")
        sortBasedOnSegmentPressed()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location.")
    }
 }
 
 
