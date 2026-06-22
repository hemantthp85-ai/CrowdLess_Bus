import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String feedbackId;
  final String busNumber;
  final String crowdLevel; // 'Low', 'Moderate', 'High'
  final DateTime timestamp;
  final String userId;

  FeedbackModel({
    required this.feedbackId,
    required this.busNumber,
    required this.crowdLevel,
    required this.timestamp,
    required this.userId,
  });

  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FeedbackModel(
      feedbackId: doc.id,
      busNumber: data['busNumber'] ?? '',
      crowdLevel: data['crowdLevel'] ?? 'Low',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'crowdLevel': crowdLevel,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
    };
  }
}
