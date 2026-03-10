//
//  LocationService.swift
//  Safe
//
//  Service de géolocalisation pour les alertes d'urgence
//

import Foundation
import CoreLocation

/// Service de géolocalisation
class LocationService: NSObject, ObservableObject {
    
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Mise à jour tous les 10 mètres
    }
    
    /// Demande la permission de localisation
    func requestPermission() {
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            break
        }
    }
    
    /// Démarre la mise à jour de la localisation
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    /// Arrête la mise à jour de la localisation
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Récupère la localisation actuelle de manière synchrone (pour l'envoi d'email)
    func getCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        if let location = currentLocation {
            completion(location)
        } else {
            // Démarrer la localisation et attendre
            locationManager.requestLocation()
            
            // Timeout de 5 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                completion(self?.currentLocation)
            }
        }
    }
    
    /// Convertit une localisation en adresse lisible (géocodage inversé)
    func getAddressFromLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            // Construire l'adresse
            var addressParts: [String] = []
            
            if let street = placemark.thoroughfare {
                if let number = placemark.subThoroughfare {
                    addressParts.append("\(number) \(street)")
                } else {
                    addressParts.append(street)
                }
            }
            
            if let city = placemark.locality {
                addressParts.append(city)
            }
            
            if let postalCode = placemark.postalCode {
                addressParts.append(postalCode)
            }
            
            if let country = placemark.country {
                addressParts.append(country)
            }
            
            let address = addressParts.isEmpty ? nil : addressParts.joined(separator: ", ")
            completion(address)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            break
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
