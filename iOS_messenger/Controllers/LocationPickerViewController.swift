//
//  LocationPickerViewController.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/8/23.
//

import UIKit
import CoreLocation
import MapKit


final class LocationPickerViewController: UIViewController {
    
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    private var coordinates: CLLocationCoordinate2D?
    
    private var isPickable = true
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    
    init(coordinates: CLLocationCoordinate2D?) {
        if let coordinates = coordinates {
            self.isPickable = false
            self.coordinates = coordinates
        } else {
            self.isPickable = true
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap))
            gesture.numberOfTapsRequired = 1
            gesture.numberOfTouchesRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            guard let coordinates = self.coordinates else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        view.addSubview(map)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    @objc func sendButtonTapped() {
        // send the locati on through the completion here
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        // remove existing pins if there's any
        for anno in map.annotations {
            if anno.isKind(of: MKPointAnnotation.classForCoder()) {
                map.removeAnnotation(anno)
            }
        }
        
        // drop a pin on that location
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
}
