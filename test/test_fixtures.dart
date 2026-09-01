/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:io';
import 'dart:typed_data';

/// Loads the `.fit` files under `test/data`.
///
/// The only place in this package that touches `dart:io`; the SDK itself is
/// pure Dart and runs unchanged on the web, which is what keeps these fixtures
/// out of `lib/`.
abstract final class TestFixtures {
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Uint8List load(String name) => _cache.putIfAbsent(name, () {
        final file = File('test/data/$name');
        if (!file.existsSync()) {
          throw StateError('test fixture $name is missing from test/data');
        }
        return file.readAsBytesSync();
      });

  static Uint8List get activity => load('Activity.fit');

  static Uint8List get activityDevFields => load('ActivityDevFields.fit');

  static Uint8List get withGearChangeData => load('WithGearChangeData.fit');

  static Uint8List get hrmPluginTestActivity =>
      load('HrmPluginTestActivity.fit');

  static Uint8List get hrMesgTestActivity => load('HrMesgTestActivity.fit');
}
