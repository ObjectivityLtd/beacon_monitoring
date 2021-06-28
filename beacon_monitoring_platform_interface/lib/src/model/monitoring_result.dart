// Copyright (c) 2020 Objectivity. All rights reserved.
// Use of this source code is governed by The MIT License (MIT) that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'region.dart';

enum MonitoringEvent {
  didEnterRegion,
  didExitRegion,
  didDetermineState,
}

enum MonitoringState {
  inside,
  outside,
}

class MonitoringResult {
  static const _region = 'region';
  static const _type = 'type';
  static const _state = 'state';

  final Region region;
  final MonitoringEvent type;

  /// This value is not null when [type] is [MonitoringEvent.didDetermineState]
  final MonitoringState? state;

  MonitoringResult({
    required this.region,
    required this.type,
    this.state,
  });

  MonitoringResult.fromJson(Map<String, dynamic> json)
      : region = Region.fromJson(json[_region]),
        type = MonitoringEventExtension.parse(json[_type]),
        state = MonitoringStateExtension.parse(json[_state]);

  Map<String, dynamic> toJson() => <String, dynamic>{
        _region: region.toJson(),
        _type: type.toJson(),
        _state: state?.toJson(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

extension MonitoringEventExtension on MonitoringEvent {
  static parse(String? value) {
    if (_StringExtension.isBlank(value)) return null;

    return MonitoringEvent.values.firstWhere((e) => describeEnum(e) == value);
  }

  String toJson() {
    return describeEnum(this);
  }
}

extension _StringExtension on String {
  static bool isBlank(String? value) {
    return value?.trim().isEmpty ?? false;
  }
}

extension MonitoringStateExtension on MonitoringState {
  static parse(String? value) {
    if (_StringExtension.isBlank(value)) return null;

    try {
      return MonitoringState.values.firstWhere((e) => describeEnum(e) == value);
    } catch (_) {
      return null;
    }
  }

  String toJson() {
    return describeEnum(this);
  }
}
