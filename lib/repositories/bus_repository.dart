import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';

class BusRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of all buses in real-time
  Stream<List<BusModel>> getBusesStream() {
    return _firestore.collection('buses').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList();
    });
  }

  // Stream of a specific bus's details in real-time
  Stream<BusModel> getBusDetailsStream(String busNumber) {
    return _firestore
        .collection('buses')
        .doc(busNumber)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw Exception('Bus $busNumber not found');
          }
          return BusModel.fromFirestore(snapshot);
        });
  }

  // Search buses by route, destination or number (Client-side filtering is preferred with streams)
  Future<List<BusModel>> searchBuses(String query) async {
    final snapshot = await _firestore.collection('buses').get();
    final allBuses = snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList();
    
    if (query.trim().isEmpty) return allBuses;

    final lowerQuery = query.toLowerCase();
    return allBuses.where((bus) {
      return bus.busNumber.toLowerCase().contains(lowerQuery) ||
             bus.route.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
