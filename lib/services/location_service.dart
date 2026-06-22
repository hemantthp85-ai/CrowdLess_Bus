import 'package:geolocator/geolocator.dart';

class LocationService {
  // Default coordinates (Singanallur/Gandhipuram area in Coimbatore: 11.0168, 76.9558)
  static const double defaultLatitude = 11.0168;
  static const double defaultLongitude = 76.9558;

  // Check and request location permission, then return current position
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _mockPosition();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, return default mock position
        return _mockPosition();
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, return default mock position
      return _mockPosition();
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return _mockPosition();
    }
  }

  // Stream location changes for real-time tracking
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    ).handleError((error) {
      // Return a stream that yields a mock position on error
      return Stream.value(_mockPosition());
    });
  }

  // Helper to generate a mock position object in case of permission denials
  Position _mockPosition() {
    return Position(
      longitude: defaultLongitude,
      latitude: defaultLatitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }
}
