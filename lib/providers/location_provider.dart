import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

// Provide the LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

// FutureProvider to fetch the current user position once (e.g. on Dashboard load)
final currentUserPositionProvider = FutureProvider<Position>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentLocation();
});

// StreamProvider to continuously track device coordinates (e.g. on Tracking Screen)
final userLocationStreamProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.getLocationStream();
});
