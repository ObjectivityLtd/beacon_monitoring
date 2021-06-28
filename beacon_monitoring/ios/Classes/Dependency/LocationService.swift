// Copyright (c) 2020 Objectivity. All rights reserved.
// Use of this source code is governed by The MIT License (MIT) that can be
// found in the LICENSE file.

import CoreLocation

protocol LocationServiceProtocol {
    func isLocationEnabled() -> Bool
    func authorizationStatus() -> CLAuthorizationStatus
    func requestAuthorization()

    func startMonitoringBeacons(for region: CLRegion)
    func startMonitoringBeacons(for regions: Set<CLRegion>)
    func stopMonitoringBeacons(for region: CLRegion)
    func stopMonitoringBeacons()

    func startRangingBeacons(in region: CLBeaconRegion)
    func stopRangingBeacons(in region: CLBeaconRegion)
    func stopRangingBeacons()
}

protocol LocationServiceDelegate: class {
    func locationService(_ service: LocationService, didChangeAuthorization status: CLAuthorizationStatus)
    func locationService(_ service: LocationService, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
    func locationService(_ service: LocationService, didDetermineState state: CLRegionState, for region: CLBeaconRegion)
    func locationService(_ service: LocationService, didEnterRegion region: CLBeaconRegion)
    func locationService(_ service: LocationService, didExitRegion region: CLBeaconRegion)
}

final class LocationService: NSObject {

    // MARK: - Public Properties
    weak var delegate: LocationServiceDelegate?

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()

    // MARK: - Instance Initialization
    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
    }

}

// MARK: - LocationServiceProtocol
extension LocationService: LocationServiceProtocol {
    func isLocationEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    func authorizationStatus() -> CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }
    func requestAuthorization() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
    }
    func startMonitoringBeacons(for region: CLRegion) {
        os_log("monitoredRegions: \(locationManager.monitoredRegions)")
        locationManager.startMonitoring(for: region)
    }
    func startMonitoringBeacons(for regions: Set<CLRegion>) {
        os_log()
        regions.forEach { startMonitoringBeacons(for: $0) }
    }
    func stopMonitoringBeacons(for region: CLRegion) {
        os_log("monitoredRegions: \(locationManager.monitoredRegions)")
        locationManager.stopMonitoring(for: region)
    }
    func stopMonitoringBeacons() {
        os_log()
        let monitoredRegions = locationManager.monitoredRegions
        monitoredRegions.forEach { stopMonitoringBeacons(for: $0) }
    }
    func startRangingBeacons(in region: CLBeaconRegion) {
        os_log("rangedRegions: \(locationManager.rangedRegions)")
        locationManager.startRangingBeacons(in: region)
    }
    func stopRangingBeacons(in region: CLBeaconRegion) {
        os_log("rangedRegions: \(locationManager.rangedRegions)")
        locationManager.stopRangingBeacons(in: region)
    }
    func stopRangingBeacons() {
        os_log("rangedRegions: \(locationManager.rangedRegions)")
        let rangedRegions = locationManager.rangedRegions.compactMap { $0 as? CLBeaconRegion }
        rangedRegions.forEach { stopRangingBeacons(in: $0) }
    }
    
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        os_log("status: \(status.rawValue)")
        delegate?.locationService(self, didChangeAuthorization: status)
    }
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        os_log("region: \(region.identifier), beacons: \(beacons.debugDescription)")
        delegate?.locationService(self, didRangeBeacons: beacons, in: region)
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        os_log("region: \(region.identifier), state: \(state.rawValue)")
        guard let region = region as? CLBeaconRegion else { return }
        delegate?.locationService(self, didDetermineState: state, for: region)
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        os_log("region: \(region.identifier)")
        guard let region = region as? CLBeaconRegion else { return }
        delegate?.locationService(self, didEnterRegion: region)
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        os_log("region: \(region.identifier)")
        guard let region = region as? CLBeaconRegion else { return }
        delegate?.locationService(self, didExitRegion: region)
    }
}
