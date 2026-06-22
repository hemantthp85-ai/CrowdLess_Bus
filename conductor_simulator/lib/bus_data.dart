/// Represents a single bus document in the 'buses' Firestore collection.
class BusData {
  final String busNumber;
  final int occupancy;
  final int capacity;
  final int ticketsIssued;
  final String route;

  BusData({
    required this.busNumber,
    required this.occupancy,
    required this.capacity,
    required this.ticketsIssued,
    required this.route,
  });

  /// Build a BusData object from a Firestore document snapshot map.
  factory BusData.fromMap(String busNumber, Map<String, dynamic> data) {
    return BusData(
      busNumber: busNumber,
      occupancy: (data['occupancy'] ?? 0) as int,
      capacity: (data['capacity'] ?? 90) as int,
      ticketsIssued: (data['ticketsIssued'] ?? 0) as int,
      route: (data['route'] ?? '') as String,
    );
  }

  /// Occupancy as a percentage of capacity (0-100).
  double get occupancyPercent =>
      capacity == 0 ? 0 : (occupancy / capacity) * 100;

  /// Crowd status classification based on occupancy percentage.
  /// 0-40%  -> Low (green)
  /// 41-70% -> Moderate (yellow)
  /// 71-100% -> Full (red)
  CrowdStatus get crowdStatus {
    final pct = occupancyPercent;
    if (pct <= 40) return CrowdStatus.low;
    if (pct <= 70) return CrowdStatus.moderate;
    return CrowdStatus.full;
  }
}

enum CrowdStatus { low, moderate, full }
