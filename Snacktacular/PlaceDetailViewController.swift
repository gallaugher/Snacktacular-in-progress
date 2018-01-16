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
            let averageRating = Double(self.reviews.reduce(0, {$0 + $1.rating})) / Double(self.reviews.count)
            
            let ratingString = String(format: "%.1f", averageRating)
            averageRatingLabel.text = ratingString
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
    
    func saveData(place: Place, review: Review?, photo: Photo?) {
        // Note: exissting place record will always be saved or updated each time an image or review is added.
        
        let currentUser = Auth.auth().currentUser
        
        // Grab the unique userID
        if let postingUserID = (currentUser?.uid) {
            place.postingUserID = postingUserID
        } else {
            place.postingUserID = "unknown user"
        }
        
        // Create the dictionary representing data we want to save
        let dataToSave: [String: Any] = place.dictionary
        
        // if we HAVE saved a record, we'll have an ID
        if place.placeDocumentID != "" {
            let ref = db.collection("places").document(place.placeDocumentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("ERROR: updating document \(error.localizedDescription)")
                } else {
                    print("Document updated with reference ID \(ref.documentID)")
                    if let photo = photo {
                        self.savePhoto(placeDocumentID: place.placeDocumentID, photo: photo)
                    }
                    if let review = review {
                        self.saveReview(review: review)
                    }
                }
            }
        } else { // Otherwise we don't have a document ID so we need to create the ref ID and save a new document
            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
            ref = db.collection("places").addDocument(data: dataToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                } else {
                    print("Document added with reference ID \(ref!.documentID)")
                    place.placeDocumentID = "\(ref!.documentID)"
                    self.saveBarButtonItem.title = "Update"
                    if let photo = photo {
                        self.savePhoto(placeDocumentID: place.placeDocumentID, photo: photo)
                    }
                    if let review = review {
                        self.saveReview(review: review)
                    }
                }
            }
        }
    }
    
    func updateAverageRating(){
        var averageRating = 0.0
        if reviews.count > 0 {
            averageRating = Double(self.reviews.reduce(0, {$0 + $1.rating})) / Double(self.reviews.count)
        }
        db.collection("places").document((place?.placeDocumentID)!).updateData(["averageRating": averageRating]) { err in
            if let err = err {
                print("Error updating averageRating: \(err). ref \((self.place?.placeDocumentID)!)")
            } else {
                print("*** Updated average successfully updated")
            }
        }
    }
    
    func savePhoto(placeDocumentID: String, photo: Photo) {
        let photoName = NSUUID().uuidString+".jpg" // always creates a unique string in part based on time/date
        photo.imageDocumentID = photoName
        // Create the dictionary representing data we want to save
        // let reviewToSave: [String: Any] = review.dictionary
        let photoToSave: [String: Any] = photo.dictionary
        
        // imagesRef now points to a bucket to hold all images for place named: "placeDocumentID"
        // let imagesRef = storage.reference().child(placeDocumentID)
        let placeStorageRef = storage.reference().child(placeDocumentID)
        
        // Convert image to type Data so it can be saved to Storage
        guard let photoData = UIImageJPEGRepresentation(newImage, 0.8) else {
            print("ERROR creating imageData from JPEGRepresentation")
            return
        }
        // Create a ref to the file you want to upload
        let uploadedPhotoRef = placeStorageRef.child(photoName)
        let uploadTask = uploadedPhotoRef.putData(photoData, metadata: nil, completion: { (metadata, error) in
            guard error == nil else {
                print("ERROR: \(error!.localizedDescription)")
                return
            }
            let downloadURL = metadata!.downloadURL
            print("%%% successfully uploaded - the downloadURL is \(downloadURL)")
            
            let photoRef = self.db.collection("places").document(placeDocumentID).collection("images").document(photoName)
            
            photoRef.setData(photoToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                } else {
                    print("Document added for place \(placeDocumentID) and image \(photoName)")
                    self.photos.append(photo)
                }
                self.collectionView.reloadData()
            }
        })
    }
    
    func saveReview(review: Review){
        // Create the dictionary representing data we want to save
        let reviewToSave: [String: Any] = review.dictionary
        
        // Just an error check. This should never happen
        guard let place = place else {
            print("*** ERROR: place was nil in saveReviewData")
            return
        }
        
        // if we HAVE saved a review, we must be updating and we'll have an ID
        if review.reviewDocumentID != "" {
            let ref = db.collection("places").document(place.placeDocumentID).collection("reviews").document(review.reviewDocumentID)
            ref.setData(reviewToSave) { (error) in
                if let error = error {
                    print("ERROR: updating review \(error.localizedDescription)")
                } else {
                    print("Review updated with reviewDocumentID \(review.reviewDocumentID)")
                    self.updateAverageRating()
                }
            }
        } else { // Otherwise we don't have a document ID, so we must be adding a new review, so we need to create the ref ID and save a new review document
            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
            ref = db.collection("places").document(place.placeDocumentID).collection("reviews").addDocument(data: reviewToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                } else {
                    review.reviewDocumentID = "\(ref!.documentID)"
                    print("Document added for place \(place.placeDocumentID) and review \(review.reviewDocumentID)")
                    self.updateAverageRating()
                }
            }
        }
    }
    
    func deletePhoto(photo: Photo) {
        guard let placeDocumentID = place?.placeDocumentID else {
            print("*** deletePhoto error, invalid placeDocumentID \((place?.placeDocumentID)!)")
            return
        }
        
        let ref = db.collection("places").document((place?.placeDocumentID)!).collection("images").document(photo.imageDocumentID)
        ref.delete() { err in
            if let err = err {
                print("Error removing document: \(photo.imageDocumentID), error: \(err)")
            } else {
                print("^^^ Document \(photo.imageDocumentID) successfully removed!")
                guard let selectedIndex = self.collectionView.indexPathsForSelectedItems?.first else {
                    print("*** tried to delete invalid selection!")
                    return
                }
                self.photos.remove(at: selectedIndex.row)
                self.collectionView.deleteItems(at: [selectedIndex])
            }
        }
        let placeStorageRef = storage.reference().child(placeDocumentID).child(photo.imageDocumentID)
        // Delete the file
        placeStorageRef.delete { error in
            if let error = error {
                print("*** ERROR: \(error.localizedDescription) In deletePhoto trying to delete \(placeStorageRef)")
            } else {
                print("Successfully deleted selected photo")
            }
        }
    }
    
    func deleteReview(review: Review) {
        let ref = db.collection("places").document((place?.placeDocumentID)!).collection("reviews").document(review.reviewDocumentID)
        ref.delete() { err in
            if let err = err {
                print("Error removing document: \(review.reviewDocumentID), error: \(err)")
            } else {
                print("^^^ Document \(review.reviewDocumentID) successfully removed!")
                guard let selectedIndex = self.tableView.indexPathForSelectedRow else {
                    print("*** tried to delete invalid selection!")
                    return
                }
                self.reviews.remove(at: selectedIndex.row)
                self.tableView.deleteRows(at: [selectedIndex], with: .fade)
                //                self.averageRating = Double(self.reviews.reduce(0, {$0 + $1.rating})) / Double(self.reviews.count)
            }
        }
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
        case "ShowPhoto":
            let destination = segue.destination as! PhotoTableViewController
            destination.photo = photos[collectionView.indexPathsForSelectedItems!.first!.row]
        // destination.photoImage = photos[collectionView.indexPathsForSelectedItems!.first!.row]
        case "UnwindFromDetailWithSegue":
            place?.placeName = placeNameField.text!
            place?.address = addressField.text!
        case "ShowRatingSegue":
            print("*** showRatingSegue pressed!")
            let destination = segue.destination as! ReviewTableViewController
            let selectedReview = tableView.indexPathForSelectedRow!.row
            destination.review = reviews[selectedReview]
            destination.name = placeNameField.text
            destination.address = addressField.text
        case "AddRatingSegue":
            let navigationController = segue.destination as! UINavigationController
            let destination = navigationController.viewControllers.first as! ReviewTableViewController
            destination.name = placeNameField.text
            destination.address = addressField.text
            // do deselect here:
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        default:
            print("DANG! This should not have happened! No case for the segue triggered!")
        }
    }
    
    @IBAction func unwindFromReviewTableViewController(segue: UIStoryboardSegue) {
        guard let source = segue.source as? ReviewTableViewController else {
            print("Couldn't get valid source inside of unwindFromReviewTableController")
            return
        }
        guard let review = source.review else {
            print("ERROR: Problem passing back review data")
            return
        }
        switch segue.identifier! {
        case "SaveUnwind":
            let db = Firestore.firestore()
            // Get new write batch
            let batch = db.batch()
            // Set the value of place
            let placeRef: DocumentReference!
            if place.placeDocumentID == "" {
                placeRef = db.collection("places").document()
            } else {
                placeRef = db.collection("places").document(place.placeDocumentID)
            }
            batch.setData(place.dictionary, forDocument: placeRef)
            
            // Set the value of review
            let reviewRef = placeRef.collection("reviews").document()
            batch.setData(review.dictionary, forDocument: reviewRef)
            
            // Commit the batch
            batch.commit() { err in
                if let err = err {
                    print("&&& Error writing batch \(err)")
                } else {
                    print("&&& Batch write succeeded.")
                }
            }
//            let source = segue.source as! ReviewTableViewController
//            if let indexPath = tableView.indexPathForSelectedRow {
//                reviews[indexPath.row] = source.review
//                tableView.reloadRows(at: [indexPath], with: .automatic)
//                saveData(place: place!, review: reviews[indexPath.row], photo: nil)
//            } else {
//                let indexPath = IndexPath(row: reviews.count, section: 0)
//                reviews.append(source.review)
//                tableView.insertRows(at: [indexPath], with: .automatic)
//                tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
//                saveData(place: place!, review: reviews[indexPath.row], photo: nil)
//            }
        case "DeleteUnwind":
            deleteReview(review: review)
        default:
            print("ERROR: unidentified segue returning inside of unwindFromReview")
        }
    }
    
    @IBAction func unwindFromPhotoViewController(segue: UIStoryboardSegue) {
        let source = segue.source as! PhotoTableViewController
        switch segue.identifier! {
        case "DeletePhoto":
            deletePhoto(photo: source.photo)
        case "SavePhoto":
            savePhoto(placeDocumentID: (place?.placeDocumentID)!, photo: source.photo)
        case "CancelPhoto":
            print("CancelPhoto pressed. Nothing to save")
        default:
            print("*** incorrectly landed on default case in unwindFromPhotoViewController")
        }
    }
    
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
            for starNumber in 0..<reviews[indexPath.row].rating {
                cell.starCollection[starNumber].image = UIImage(named: "star-filled")
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
                    print("An error occurred while rading data from file ref: \(imageReference), error \(error!.localizedDescription)")
                    return
                }
                let image = UIImage(data: data!)
                photo.image = image
                self.collectionView.reloadData()
            }
        }
        self.stopActivityIndicator()
    }
    
    func checkForImages()
    { db.collection("places").document((place?.placeDocumentID)!).collection("images").addSnapshotListener { (querySnapshot, error) in
        self.photos = []
        if error != nil {
            print("ERROR: reading documents at \(error!.localizedDescription)")
        } else {
            for document in querySnapshot!.documents {
                var photo = Photo(dictionary: document.data())
                photo.imageDocumentID = document.documentID
                self.photos.append(photo)
            }
        }
        self.loadImages()
        }
    }
}
