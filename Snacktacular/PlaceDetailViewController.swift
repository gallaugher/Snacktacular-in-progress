//
//  DetailViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import GooglePlaces
import Firebase

class PlaceDetailViewController: UIViewController {
    @IBOutlet weak var placeNameField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var rateItButton: UIButton!
    @IBOutlet weak var saveBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var averageRatingLabel: UILabel!
    
    var place: Place!
    var locationManger: CLLocationManager!
    var currentLocation: CLLocation!
    var regionRadius = 1000.0 // 1 km
    var imagePicker = UIImagePickerController()
    var newImage = UIImage()
    var photos = [Photo]()
    var reviews = [Review]() {
        didSet {
            guard reviews.count != 0 else {
                averageRatingLabel.text = "-.-"
                return
            }
        }
    }
    
    var newReviews = [Review]()
    var db: Firestore!
    var storage: Storage!
    
    var activityIndicator = UIActivityIndicatorView()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        tableView.delegate = self
        tableView.dataSource = self
        
        db = Firestore.firestore()
        storage = Storage.storage()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        mapView.delegate = self
        if place == nil {
            place = Place()
            // Turn off the back button & keep Save and Cancel as is
            self.navigationItem.leftItemsSupplementBackButton = false
            getLocation()
        } else {
            //            centerMap(mapLocation: place, regionRadius: regionRadius)
            //            mapView.removeAnnotations(mapView.annotations)
            //            mapView.addAnnotation(place)
            //            mapView.selectAnnotation(place, animated: true)
            
            // blank out Cancel and Save buttons
            saveBarButtonItem.title = ""
            cancelBarButtonItem.title = ""
            placeNameField.isEnabled = false
            addressField.isEnabled = false
        }
        checkForReviewUpdates()
        checkForImages()
        updateUserInterface()
    }
    
    func updateUserInterface() {
        placeNameField.text = place!.placeName
        addressField.text = place!.address
        updateMap()
    }
    
    func updateMap() {
        centerMap(mapLocation: (place?.coordinate)!, regionRadius: regionRadius)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(self.place!)
        //        mapView.selectAnnotation(self.place!, animated: true)
    }
    
    func centerMap(mapLocation: CLLocationCoordinate2D, regionRadius: CLLocationDistance) {
        let region = MKCoordinateRegionMakeWithDistance(mapLocation, regionRadius, regionRadius)
        mapView.setRegion(region, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "AddPhoto":
            let currentUser = Auth.auth().currentUser?.uid ?? ""
            let photo = Photo(image: newImage, imageDocumentID: "", imageDescription: "", postedBy: currentUser, date: Date())
            let navigationController = segue.destination as! UINavigationController
            let destination = navigationController.viewControllers.first as! PhotoTableViewController
            destination.photo = photo
            destination.place = place
        case "ShowPhoto":
            let destination = segue.destination as! PhotoTableViewController
            destination.photo = photos[collectionView.indexPathsForSelectedItems!.first!.row]
            destination.place = place
        // destination.photoImage = photos[collectionView.indexPathsForSelectedItems!.first!.row]
        case "ShowRatingSegue":
            print("*** showRatingSegue pressed!")
            let destination = segue.destination as! ReviewTableViewController
            let selectedReview = tableView.indexPathForSelectedRow!.row
            destination.review = reviews[selectedReview]
            place.placeName = placeNameField.text!
            place.address = addressField.text!
            destination.place = place
        case "AddRatingSegue":
            let navigationController = segue.destination as! UINavigationController
            let destination = navigationController.viewControllers.first as! ReviewTableViewController
            place.placeName = placeNameField.text!
            place.address = addressField.text!
            destination.place = place
            // do deselect here:
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        case "SaveFromPlaceDetail":
            place?.placeName = placeNameField.text!
            place?.address = addressField.text!
        default:
            print("DANG! This should not have happened! No case for the segue triggered! Inside PlaceDetailViewController.swift \(segue.identifier!)")
        }
    }
    
    @IBAction func unwindFromPhotoTableViewController(segue: UIStoryboardSegue) {
        guard let source = segue.source as? PhotoTableViewController else {
            print("Couldn't get valid source inside of unwindFromPhotoTableController")
            return
        }
        guard source.photo != nil else {
            print("ERROR: Problem passing back photo data")
            return
        }
        if segue.identifier == "SavePhotoUnwind" {
            // Must have pressed save, so if there is a "Save" button on the PlaceDetailTableView controller, it should be changed to "Update"
            if saveBarButtonItem.title != "" { // It must say "Save"
                saveBarButtonItem.title = "Update"
            }
        }
    }
    
    @IBAction func unwindFromReviewTableViewController(segue: UIStoryboardSegue) {
        guard let source = segue.source as? ReviewTableViewController else {
            print("Couldn't get valid source inside of unwindFromReviewTableController")
            return
        }
        guard source.review != nil else {
            print("ERROR: Problem passing back review data")
            return
        }
        if segue.identifier == "SaveReviewUnwind" {
            // Must have pressed save, so if there is a "Save" button on the PlaceDetailTableView controller, it should be changed to "Update"
            if saveBarButtonItem.title != "" { // It must say "Save"
                saveBarButtonItem.title = "Update"
            }
        }
    }
    
//    @IBAction func unwindFromReviewTableViewController(segue: UIStoryboardSegue) {
//        guard let source = segue.source as? ReviewTableViewController else {
//            print("Couldn't get valid source inside of unwindFromReviewTableController")
//            return
//        }
//        guard let review = source.review else {
//            print("ERROR: Problem passing back review data")
//            return
//        }
//        switch segue.identifier! {
//        case "SaveUnwind":
//            print"
//
//        case "DeleteUnwind":
//            review.deleteReview(place: place)
////            deleteReview(review: review)
//        default:
//            print("ERROR: unidentified segue returning inside of unwindFromReview")
//        }
//    }
    
//    @IBAction func unwindFromPhotoViewController(segue: UIStoryboardSegue) {
//        let source = segue.source as! PhotoTableViewController
//        switch segue.identifier! {
//        case "DeletePhoto":
//            source.photo.deletePhoto(leadingRef: place.documentReference())
//        case "SavePhoto":
//            if saveBarButtonItem.title != "" {
//                saveBarButtonItem.title = "Update"
//            }
////            place.saveData {
////                let placeRef = self.place.documentReference()
////                source.photo.savePhoto(leadingRef: placeRef)
////            }
//        case "CancelPhoto":
//            print("CancelPhoto pressed. Nothing to save")
//        default:
//            print("*** incorrectly landed on default case in unwindFromPhotoViewController")
//        }
//    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func rateItTouchDown(_ sender: UIButton) {
        rateItButton.alpha = 0.5
    }
    
    @IBAction func ratePressed(_ sender: UIButton) {
        rateItButton.alpha = 1.0     
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        let isPrestingInAddMode = presentingViewController is UINavigationController
        if isPrestingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func lookupButtonPressed(_ sender: UIBarButtonItem) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        present(autocompleteController, animated: true, completion: nil)
    }
    
    @IBAction func cameraButtonPressed(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { (cameraAction) in
            self.accessCamera()
        }
        let libraryAction = UIAlertAction(title: "Photo Library", style: .default) { (libraryAction) in
            self.accessLibrary()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension PlaceDetailViewController: CLLocationManagerDelegate {
    
    func getLocation(){
        locationManger = CLLocationManager()
        locationManger.delegate = self
    }
    
    func handleLocationAuthorizationStatus(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManger.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManger.requestLocation()
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
        guard place?.placeName == "" else {
            // User must have already added a location before first location came back while adding a new record.
            return
        }
        let geoCoder = CLGeocoder()
        currentLocation = locations.last
        let currentLatitude = currentLocation.coordinate.latitude
        let currentLongitude = currentLocation.coordinate.longitude
        self.place?.coordinate = CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
        geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: {placemarks, error in
            if placemarks != nil {
                let placemark = placemarks?.last
                self.place?.placeName = (placemark?.name)!
                self.place?.address = placemark?.thoroughfare ?? "unknown"
                //                place?.coordinate = CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
                //                self.centerMap(mapLocation: (self.place?.coordinate)!, regionRadius: self.regionRadius)
                //
                //                self.mapView.addAnnotation(self.place!)
                //                self.mapView.selectAnnotation(self.place!, animated: true)
                self.updateUserInterface()
            } else {
                print("Error retrieving place. Error code: \(error!)")
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location.")
    }
}

extension PlaceDetailViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifer = "Marker"
        // var view: MKPinAnnotationView
        var view: MKMarkerAnnotationView
        //       if let dequedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifer) as? MKPinAnnotationView {
        if let dequedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifer) as? MKMarkerAnnotationView {
            dequedView.annotation = annotation
            view = dequedView
        } else {
            // view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifer)
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifer)
            //            view.canShowCallout = true
            //            view.rightCalloutAccessoryView = UIButton(type: .custom)
        }
        return view
    }
}

extension PlaceDetailViewController: GMSAutocompleteViewControllerDelegate {
    
    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        self.place?.placeName = place.name
        self.place?.coordinate = place.coordinate
        self.place?.address = place.formattedAddress ?? "unknown"
        centerMap(mapLocation: (self.place?.coordinate)!, regionRadius: regionRadius)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(self.place!)
        mapView.selectAnnotation(self.place!, animated: true)
        updateUserInterface()
        dismiss(animated: true, completion: nil)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    // User canceled the operation.
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}

extension PlaceDetailViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let selectedImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        newImage = selectedImage
        // update stuff below
        //        photos.insert(selectedImage, at: 0)
        //        newImage = selectedImage
        //        dismiss(animated: true) {
        //            self.saveData(place: self.place!, review: nil, image: self.newImage)
        //            self.collectionView.reloadData()
        //        }
        dismiss(animated: true) {
            self.performSegue(withIdentifier: "AddPhoto", sender: nil)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func accessLibrary() {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    func accessCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            present(imagePicker, animated: true, completion: nil)
        } else {
            showAlert(title: "Camera Not Available", message: "There is no camera available on this device.")
        }
    }
}

extension PlaceDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PlaceImageCollectionViewCell
        cell.placeImage.image = photos[indexPath.row].image
        return cell
    }
}

extension PlaceDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reviews.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell", for: indexPath) as! ReviewTableViewCell
        cell.reviewHeadlineLabel.text = reviews[indexPath.row].reviewHeadline
        cell.reviewTextLabel.text = reviews[indexPath.row].reviewText
        if reviews[indexPath.row].rating > 0 {
            for starNumber in 0...4 {
                if starNumber < reviews[indexPath.row].rating {
                cell.starCollection[starNumber].image = UIImage(named: "star-filled")
                } else {
                    cell.starCollection[starNumber].image = UIImage(named: "star-empty")
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let totalInserts = self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom
        return 40
    }
}

extension PlaceDetailViewController {
    func startActivityIndicator() {
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = .whiteLarge
        activityIndicator.color = UIColor.red
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        UIApplication.shared.beginIgnoringInteractionEvents()
    }
    
    func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }
}

// Firestore Code
extension PlaceDetailViewController {
    
    func checkForReviewUpdates() {
        db.collection("places").document(place.placeDocumentID).collection("reviews").addSnapshotListener { (reviewQuerySnapshot, error) in
            guard error == nil else {
                print("ERROR: adding the snapshot listener \(error!.localizedDescription)")
                return
            }
            self.reviews = []
            for document in reviewQuerySnapshot!.documents {
                let review = Review(dictionary: document.data())
                review.reviewDocumentID = document.documentID
                self.reviews.append(review)
            }
            self.place.getAvgReview() { (avgReview) in
                if avgReview == 0.0 {
                    self.averageRatingLabel.text = "-.-" // for unrated
                } else {
                    self.averageRatingLabel.text = String(format: "%.1f", avgReview)
                }
            }
            self.tableView.reloadData()
        }
    }
    
    func loadImages() {
        guard let bucketRef = self.place?.placeDocumentID else {
            print("Couldn't read bucketRef for \(self.place!.placeDocumentID)")
            self.startActivityIndicator()
            return
        }
        for photo in photos {
            let imageReference = self.storage.reference().child(bucketRef+"/"+photo.imageDocumentID)
            print("Loading imageReference for: \(imageReference)")
            imageReference.getData(maxSize: 10 * 1024 * 1024) { data, error in
                guard error == nil else {
                    print("An error occurred while reading data from file ref: \(imageReference), error \(error!.localizedDescription)")
                    return
                }
                let image = UIImage(data: data!)
                photo.image = image
                self.collectionView.reloadData()
            }
        }
        self.stopActivityIndicator()
    }
    
    func checkForImages() {
        db.collection("places").document((place?.placeDocumentID)!).collection("images").addSnapshotListener { (querySnapshot, error) in
            self.photos = []
            if error != nil {
                print("ERROR: reading documents at \(error!.localizedDescription)")
            } else {
                for document in querySnapshot!.documents {
                    let photo = Photo(dictionary: document.data())
                    photo.imageDocumentID = document.documentID
                    self.photos.append(photo)
                }
                if let querySnapshot = querySnapshot, querySnapshot.count > 0 {
                    self.loadImages()
                } else { // no photos left
                    self.collectionView.reloadData()
                }
            }
        }
    }

}
