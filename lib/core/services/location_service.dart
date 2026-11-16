import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../l10n/app_strings.dart';
import '../utils/map_location.dart';

/// Why the phone's location could not be had.
enum LocationProblem { serviceOff, denied, deniedForever, timeout, failed }

class LocationFailure implements Exception {
  const LocationFailure(this.problem);

  final LocationProblem problem;

  /// What to tell the person, and what to do about it.
  String get message => switch (problem) {
        LocationProblem.serviceOff => AppStrings.locationServiceOff,
        LocationProblem.denied => AppStrings.locationDenied,
        LocationProblem.deniedForever => AppStrings.locationDeniedForever,
        LocationProblem.timeout => AppStrings.locationTimeout,
        LocationProblem.failed => AppStrings.locationFailed,
      };

  @override
  String toString() => message;
}

/// Where the phone (or the browser) is right now, once, asking for permission
/// the first time. Used to save a child's home while standing at their door.
class LocationService {
  const LocationService._();

  /// The current position, or a [LocationFailure] saying what is wrong.
  static Future<MapLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(LocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(LocationProblem.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!MapLocation.isValid(position.latitude, position.longitude)) {
        throw const LocationFailure(LocationProblem.failed);
      }
      return MapLocation(position.latitude, position.longitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(LocationProblem.timeout);
    } catch (_) {
      throw const LocationFailure(LocationProblem.failed);
    }
  }
}
