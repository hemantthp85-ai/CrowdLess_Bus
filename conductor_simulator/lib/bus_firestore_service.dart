import 'package:cloud_firestore/cloud_firestore.dart';
import 'bus_data.dart';

/// Handles all Firestore read/write operations for the 'buses' collection.
///
/// Firestore structure:
/// buses (collection)
///   └── 21G (document)
///         ├── occupancy: 35       (int)
///         ├── capacity: 90        (int)
///         ├── ticketsIssued: 120  (int)
///         ├── route: "Singanallur - PSG College" (string)
///         └── lastUpdated: <server timestamp>
///   └── S1 (document)
///         ├── ... same fields
///   └── 1C (document)
///         ├── ... same fields
class BusFirestoreService {
  final CollectionReference<Map<String, dynamic>> _busesRef =
      FirebaseFirestore.instance.collection('buses');

  /// List of bus numbers available in the simulator dropdown.
  /// Update this list if your team adds/removes simulated buses.
  static const List<String> availableBuses = ['21G', 'S1', '1C'];

  /// Stream of live updates for a specific bus document.
  /// Passenger app listens to the same stream pattern.
  Stream<BusData> watchBus(String busNumber) {
    return _busesRef.doc(busNumber).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return BusData.fromMap(busNumber, data);
    });
  }

  /// Ensures a bus document exists with default values.
  /// Call this once when a bus is first selected, in case the
  /// document hasn't been created yet by anyone on the team.
  Future<void> ensureBusExists(String busNumber, {String route = ''}) async {
    final docRef = _busesRef.doc(busNumber);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'occupancy': 0,
        'capacity': 90,
        'ticketsIssued': 0,
        'route': route,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Conductor issues a ticket: occupancy +1, ticketsIssued +1.
  /// Occupancy is capped at capacity (can't exceed bus capacity).
  Future<void> issueTicket(String busNumber, int currentOccupancy, int capacity) async {
    final docRef = _busesRef.doc(busNumber);

    if (currentOccupancy >= capacity) {
      // Bus is already full - still count the ticket attempt but
      // do not increase occupancy beyond capacity.
      await docRef.update({
        'ticketsIssued': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.update({
      'occupancy': FieldValue.increment(1),
      'ticketsIssued': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Passenger exits the bus: occupancy -1 (never below 0).
  Future<void> passengerExit(String busNumber, int currentOccupancy) async {
    if (currentOccupancy <= 0) return; // prevent negative occupancy

    final docRef = _busesRef.doc(busNumber);
    await docRef.update({
      'occupancy': FieldValue.increment(-1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Reset a bus to empty (useful for demo/testing between runs).
  Future<void> resetBus(String busNumber) async {
    final docRef = _busesRef.doc(busNumber);
    await docRef.update({
      'occupancy': 0,
      'ticketsIssued': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
