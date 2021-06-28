// Copyright (c) 2020 Objectivity. All rights reserved.
// Use of this source code is governed by The MIT License (MIT) that can be
// found in the LICENSE file.

import CoreLocation
import Foundation

typealias BeaconServiceStartMonitoringResult = (Bool, BeaconService.Error?) -> Void

protocol BeaconServiceProtocol {
    func startBackgroundMonitoring(onComplete: @escaping BeaconServiceStartMonitoringResult)
    func stopBackgroundMonitoring()

    func startForegroundMonitoring(onComplete: @escaping BeaconServiceStartMonitoringResult)
    func stopForegroundMonitoring()

    func startForegroundRanging(onComplete: @escaping BeaconServiceStartMonitoringResult)
    func stopForegroundRanging()
}

@objc
protocol BeaconServiceDelegate: class {
    @objc optional func beaconService(_ service: BeaconService, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
    @objc optional func beaconService(_ service: BeaconService, didDetermineState state: CLRegionState, for region: CLBeaconRegion)
    @objc optional func beaconService(_ service: BeaconService, didEnterRegion region: CLBeaconRegion)
    @objc optional func beaconService(_ service: BeaconService, didExitRegion region: CLBeaconRegion)
}

class BeaconService: NSObject {

    // MARK: - Private Properties
    private let multicast = BeaconServiceMulticastDelegate()
    private let locationService: LocationService
    private let preferencesStorage: PreferencesStorage
    private let permissionsService: PermissionsServiceProtocol
    private var regionsToMonitor = Set<CLBeaconRegion>()
    private var onComplete: BeaconServiceStartMonitoringResult?
    private var authorizationStatus: CLAuthorizationStatus?

    // MARK: - Error
    enum Error: Swift.Error {
        case bluetoothIsDisabled
        case monitoringIsNotAvailable
        case rangingIsNotAvailable
        case locationServicesAreDisabled
        case locationServicesAreDenied
        case locationServicesAreNotDetermined
        case locationServicesAreRestricted
        case locationServicesAreNotAuthorizedWhenInUse
        case locationServicesAreNotAuthorizedAlways
    }

    // MARK: - Instance Initialization
    init(locationService: LocationService,
         preferencesStorage: PreferencesStorage,
         permissionsService: PermissionsServiceProtocol) {
        self.locationService = locationService
        self.preferencesStorage = preferencesStorage
        self.permissionsService = permissionsService
        super.init()
        setupLocationService()
    }

    // MARK: - Public Methods
    func add(_ delegate: BeaconServiceDelegate) {
        os_log()
        multicast.add(delegate)
    }
    func remove(_ delegateToRemove: BeaconServiceDelegate) {
        os_log("\(delegateToRemove)")
        multicast.remove(delegateToRemove)
    }

    // MARK: - Private Methods
    private func setupLocationService() {
        locationService.delegate = self
    }
    private func startMonitoring(authorizationStatus: CLAuthorizationStatus, onComplete: @escaping BeaconServiceStartMonitoringResult) {
        os_log()
        do {
            try permissionsService.checkAllowedPermissions(authorizationStatus: authorizationStatus)
            locationService.requestAuthorization()
            locationService.startMonitoringBeacons(for: regionsToMonitor)
            onComplete(true, nil)
        } catch BeaconService.Error.locationServicesAreNotDetermined {
            locationService.requestAuthorization()
            self.authorizationStatus = authorizationStatus
            self.onComplete = onComplete
        } catch {
            onComplete(false, error as? BeaconService.Error)
        }
    }
    private func startRanging(authorizationStatus: CLAuthorizationStatus, onComplete: @escaping BeaconServiceStartMonitoringResult) {
        os_log()
        do {
            try permissionsService.checkAllowedPermissions(authorizationStatus: authorizationStatus)
            locationService.requestAuthorization()
            for region in regionsToMonitor {
                locationService.startRangingBeacons(in: region)
            }
            onComplete(true, nil)
        } catch BeaconService.Error.locationServicesAreNotDetermined {
            locationService.requestAuthorization()
            self.authorizationStatus = authorizationStatus
            self.onComplete = onComplete
        } catch {
            onComplete(false, error as? BeaconService.Error)
        }
    }
    private func stopQueueMonitoring() {
        os_log()
        guard preferencesStorage.hasMonitoringListener() == false else { return }
        locationService.stopMonitoringBeacons()
        locationService.stopRangingBeacons()
    }
}

// MARK: - BeaconServiceProtocol
extension BeaconService: BeaconServiceProtocol {
    func startBackgroundMonitoring(onComplete: @escaping BeaconServiceStartMonitoringResult) {
        os_log()
        startMonitoring(authorizationStatus: .authorizedAlways) { [weak self] didStartMonitoring, startMonitoringError in
            guard let self = self else { return }
            self.preferencesStorage.isBackgroundMonitoringStarted = didStartMonitoring
            onComplete(didStartMonitoring, startMonitoringError)
        }
    }
    func stopBackgroundMonitoring() {
        os_log()
        preferencesStorage.isBackgroundMonitoringStarted = false
        stopQueueMonitoring()
    }
    func startForegroundMonitoring(onComplete: @escaping BeaconServiceStartMonitoringResult) {
        os_log()
        startMonitoring(authorizationStatus: .authorizedWhenInUse) { [weak self] didStartMonitoring, startMonitoringError in
            guard let self = self else { return }
            self.preferencesStorage.isForegroundMonitoringStarted = didStartMonitoring
            onComplete(didStartMonitoring, startMonitoringError)
        }
    }
    func stopForegroundMonitoring() {
        os_log()
        preferencesStorage.isForegroundMonitoringStarted = false
        stopQueueMonitoring()
    }
    func startForegroundRanging(onComplete: @escaping BeaconServiceStartMonitoringResult) {
        os_log()
        startRanging(authorizationStatus: .authorizedWhenInUse) { [weak self] didStartMonitoring, startMonitoringError in
            guard let self = self else { return }
            self.preferencesStorage.isForegroundRangingStarted = didStartMonitoring
            onComplete(didStartMonitoring, startMonitoringError)
        }
    }
    func stopForegroundRanging() {
        os_log()
        preferencesStorage.isForegroundRangingStarted = false
        stopQueueMonitoring()
    }
}

// MARK: - Ranging And Monitoring Methods
extension BeaconService {
    func registerRegion(_ region: CLBeaconRegion) {
        os_log("\(region.identifier)")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        region.notifyEntryStateOnDisplay = true
        regionsToMonitor.insert(region)
    }
    func registerAllRegions(_ regions: [CLBeaconRegion]) {
        os_log("\(regions.debugDescription)")
        regions.forEach { registerRegion($0) }
    }
    func removeRegion(_ region: CLBeaconRegion) {
        os_log("\(region.identifier)")
        regionsToMonitor.remove(region)
    }
    func removeAllRegions() {
        os_log("\(regionsToMonitor.debugDescription)")
        regionsToMonitor.removeAll()
    }
}

// MARK: - LocationServiceDelegate
extension BeaconService: LocationServiceDelegate {
    func locationService(_ service: LocationService, didChangeAuthorization status: CLAuthorizationStatus) {
        os_log("\(status.rawValue)")
        guard let authorizationStatus = authorizationStatus, let onComplete = onComplete else { return }
        startMonitoring(authorizationStatus: authorizationStatus, onComplete: onComplete)
    }
    func locationService(_ service: LocationService, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        os_log("\(region.identifier): \(beacons.debugDescription)")
        multicast.beaconService(self, didRangeBeacons: beacons, in: region)
    }
    func locationService(_ service: LocationService, didDetermineState state: CLRegionState, for region: CLBeaconRegion) {
        os_log(region.identifier)
        multicast.beaconService(self, didDetermineState: state, for: region)
    }
    func locationService(_ service: LocationService, didEnterRegion region: CLBeaconRegion) {
        os_log(region.identifier)
        multicast.beaconService(self, didEnterRegion: region)
        guard preferencesStorage.isForegroundRangingStarted else { return }
        locationService.startRangingBeacons(in: region)
    }
    func locationService(_ service: LocationService, didExitRegion region: CLBeaconRegion) {
        os_log(region.identifier)
        multicast.beaconService(self, didExitRegion: region)
        locationService.stopRangingBeacons(in: region)
    }
}
