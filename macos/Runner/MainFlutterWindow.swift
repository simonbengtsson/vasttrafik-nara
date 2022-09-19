import Cocoa
import FlutterMacOS
import CoreLocation

class MainFlutterWindow: NSWindow, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
        
        locationManager.delegate = self
        askForLocationPermission()
    }
    
    func askForLocationPermission() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        print("Authorization status \(getDescription(locationManager.authorizationStatus))")
    }
    
    func getDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "authorizedAlways"
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(locations.first?.coordinate.latitude ?? 0)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("Authorization status changed \(getDescription(manager.authorizationStatus))")
        if manager.authorizationStatus == .authorized {
            manager.startUpdatingLocation()
            print("Started updating location...")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error \(error.localizedDescription)")
    }
    
}
