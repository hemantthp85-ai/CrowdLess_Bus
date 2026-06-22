import 'package:cloud_firestore/cloud_firestore.dart';

class BusModel {
  final String busNumber;
  final String route;
  final int occupancy;
  final int capacity;
  final double latitude;
  final double longitude;
  final int eta; // in minutes
  final String status; // 'Low', 'Moderate', 'High'
  
  // Prediction Engine parameters
  final int comfortScore; // 0 - 100
  final int predictedOccupancy;
  final int expectedBoarding;
  final int expectedExits;
  final int confidenceScore; // 0 - 100
  final int predictionAccuracy; // 0 - 100

  BusModel({
    required this.busNumber,
    required this.route,
    required this.occupancy,
    required this.capacity,
    required this.latitude,
    required this.longitude,
    required this.eta,
    required this.status,
    this.comfortScore = 95,
    this.predictedOccupancy = 0,
    this.expectedBoarding = 0,
    this.expectedExits = 0,
    this.confidenceScore = 90,
    this.predictionAccuracy = 92,
  });

  // Calculate available capacity dynamically
  int get availableCapacity => capacity - occupancy;

  // Calculate occupancy percentage
  double get occupancyPercentage => capacity > 0 ? occupancy / capacity : 0.0;

  // Get formatted status details
  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'low':
        return 'Low Crowd';
      case 'moderate':
        return 'Moderate Crowd';
      case 'high':
        return 'High Crowd';
      default:
        return '$status Crowd';
    }
  }

  // Recommendation logic based on occupancy percentage and comfort score
  String get recommendation {
    final percent = occupancyPercentage;
    if (percent >= 0.85 || comfortScore < 30) {
      return 'Crowded - Wait for next';
    } else if (percent >= 0.60 || comfortScore < 60) {
      return 'Expect Standing Room';
    } else {
      return 'Good To Board';
    }
  }

  // Factory constructor for Firestore mapping
  factory BusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final occupancyVal = data['occupancy'] is num ? (data['occupancy'] as num).toInt() : 0;
    final capacityVal = data['capacity'] is num ? (data['capacity'] as num).toInt() : 100;
    
    return BusModel(
      busNumber: doc.id, // document ID is the bus number (e.g., '21G')
      route: data['route'] ?? 'Unknown Route',
      occupancy: occupancyVal,
      capacity: capacityVal,
      latitude: data['latitude'] is num ? (data['latitude'] as num).toDouble() : 0.0,
      longitude: data['longitude'] is num ? (data['longitude'] as num).toDouble() : 0.0,
      eta: data['eta'] is num ? (data['eta'] as num).toInt() : 0,
      status: data['status'] ?? 'Unknown',
      comfortScore: data['comfortScore'] is num 
          ? (data['comfortScore'] as num).toInt() 
          : _calculateComfortScore(occupancyVal, capacityVal),
      predictedOccupancy: data['predictedOccupancy'] is num 
          ? (data['predictedOccupancy'] as num).toInt() 
          : occupancyVal,
      expectedBoarding: data['expectedBoarding'] is num ? (data['expectedBoarding'] as num).toInt() : 0,
      expectedExits: data['expectedExits'] is num ? (data['expectedExits'] as num).toInt() : 0,
      confidenceScore: data['confidenceScore'] is num ? (data['confidenceScore'] as num).toInt() : 90,
      predictionAccuracy: data['predictionAccuracy'] is num ? (data['predictionAccuracy'] as num).toInt() : 92,
    );
  }

  // Helper to estimate comfort score locally if not stored
  static int _calculateComfortScore(int occupancy, int capacity) {
    if (capacity <= 0) return 100;
    final ratio = occupancy / capacity;
    if (ratio < 0.3) return 95;
    if (ratio < 0.6) return 75;
    if (ratio < 0.85) return 45;
    return 15;
  }

  // Create Map for Firestore uploads (useful for setup or updates)
  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'route': route,
      'occupancy': occupancy,
      'capacity': capacity,
      'latitude': latitude,
      'longitude': longitude,
      'eta': eta,
      'status': status,
      'comfortScore': comfortScore,
      'predictedOccupancy': predictedOccupancy,
      'expectedBoarding': expectedBoarding,
      'expectedExits': expectedExits,
      'confidenceScore': confidenceScore,
      'predictionAccuracy': predictionAccuracy,
    };
  }
}
