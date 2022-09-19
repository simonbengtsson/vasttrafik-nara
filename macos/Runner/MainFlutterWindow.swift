import Cocoa
import FlutterMacOS
import CoreLocation

class MainFlutterWindow: NSWindow, CLLocationManagerDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    askForLocationPermission()

    super.awakeFromNib()
  }
    
    func askForLocationPermission() {
        let locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
        let status = locationManager.authorizationStatus
        if status == .restricted || status == .denied {
            print("Location Denied")
            return
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            print("Show ask for location")
            return
        } else if status == .authorized {
            print("This should work?")
            return
        }
    }
}
