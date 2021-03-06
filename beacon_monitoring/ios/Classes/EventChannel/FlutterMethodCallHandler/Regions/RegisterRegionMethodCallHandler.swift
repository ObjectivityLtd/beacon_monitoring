// Copyright (c) 2020 Objectivity. All rights reserved.
// Use of this source code is governed by The MIT License (MIT) that can be
// found in the LICENSE file.

import Flutter

final class RegisterRegionMethodCallHandler: FlutterMethodCallHandlerProtocol {

    // MARK: - Private Properties
    private let decoder: FlutterDecoder
    private let beaconService: BeaconService

    // MARK: - Instance Initialization
    init(decoder: FlutterDecoder, beaconService: BeaconService) {
        self.decoder = decoder
        self.beaconService = beaconService
    }

    // MARK: - FlutterMethodCallHandlerProtocol Methods
    func handleMethodCall(_ arguments: Any?, result: @escaping FlutterResult) {
        if let region = decoder.decodeBeaconRegion(arguments: arguments) {
            os_log()
            beaconService.registerRegion(region)
            result(FlutterResultModel.void())
        } else {
            result(FlutterError.exceptionInvalidArguments())
            os_log("\(FlutterError.exceptionInvalidArguments())")
        }
    }
}

