import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String ticketId;
  final String busNumber;
  final String sourceStop;
  final String destinationStop;
  final int passengerCount;
  final DateTime timestamp;

  TicketModel({
    required this.ticketId,
    required this.busNumber,
    required this.sourceStop,
    required this.destinationStop,
    required this.passengerCount,
    required this.timestamp,
  });

  factory TicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketModel(
      ticketId: doc.id,
      busNumber: data['busNumber'] ?? '',
      sourceStop: data['sourceStop'] ?? '',
      destinationStop: data['destinationStop'] ?? '',
      passengerCount: data['passengerCount'] is num ? (data['passengerCount'] as num).toInt() : 1,
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'sourceStop': sourceStop,
      'destinationStop': destinationStop,
      'passengerCount': passengerCount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
