import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final String routeId;
  final String source;
  final String destination;
  final List<String> stops;
  final List<String> buses;
  final Map<String, LatLng> stopCoordinates;

  RouteModel({
    required this.routeId,
    required this.source,
    required this.destination,
    required this.stops,
    required this.buses,
    required this.stopCoordinates,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawStops = data['stops'] as List<dynamic>? ?? [];
    final rawBuses = data['buses'] as List<dynamic>? ?? [];
    
    final Map<String, LatLng> stopCoords = {};
    
    // 1. Try to load stopCoordinates map
    final rawCoordsMap = data['stopCoordinates'] as Map<String, dynamic>? ?? 
                         data['coordinates'] as Map<String, dynamic>? ?? {};
    rawCoordsMap.forEach((key, val) {
      if (val is GeoPoint) {
        stopCoords[key.toLowerCase().trim()] = LatLng(val.latitude, val.longitude);
      } else if (val is Map<String, dynamic>) {
        final lat = val['latitude'] ?? val['lat'];
        final lng = val['longitude'] ?? val['lng'];
        if (lat is num && lng is num) {
          stopCoords[key.toLowerCase().trim()] = LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    });

    // 2. Try to load stopCoordinates list (parallel to stops list)
    final rawCoordsList = data['stopCoordinatesList'] as List<dynamic>? ??
                          data['coordinatesList'] as List<dynamic>? ?? [];
    if (rawCoordsList.isNotEmpty) {
      for (int i = 0; i < rawCoordsList.length && i < rawStops.length; i++) {
        final val = rawCoordsList[i];
        final stopName = rawStops[i].toString().toLowerCase().trim();
        if (val is GeoPoint) {
          stopCoords[stopName] = LatLng(val.latitude, val.longitude);
        } else if (val is Map<String, dynamic>) {
          final lat = val['latitude'] ?? val['lat'];
          final lng = val['longitude'] ?? val['lng'];
          if (lat is num && lng is num) {
            stopCoords[stopName] = LatLng(lat.toDouble(), lng.toDouble());
          }
        }
      }
    }

    return RouteModel(
      routeId: doc.id,
      source: data['source'] ?? '',
      destination: data['destination'] ?? '',
      stops: rawStops.map((e) => e.toString()).toList(),
      buses: rawBuses.map((e) => e.toString()).toList(),
      stopCoordinates: stopCoords,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'destination': destination,
      'stops': stops,
      'buses': buses,
    };
  }
}
