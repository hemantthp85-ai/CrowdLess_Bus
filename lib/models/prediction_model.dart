import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionModel {
  final String id;
  final String busNumber;
  final int currentOccupancy;
  final int predictedOccupancy;
  final int expectedBoarding;
  final int expectedExits;
  final int comfortScore;
  final int confidenceScore;
  final DateTime generatedAt;

  PredictionModel({
    required this.id,
    required this.busNumber,
    required this.currentOccupancy,
    required this.predictedOccupancy,
    required this.expectedBoarding,
    required this.expectedExits,
    required this.comfortScore,
    required this.confidenceScore,
    required this.generatedAt,
  });

  factory PredictionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PredictionModel(
      id: doc.id,
      busNumber: data['busNumber'] ?? '',
      currentOccupancy: data['currentOccupancy'] is num ? (data['currentOccupancy'] as num).toInt() : 0,
      predictedOccupancy: data['predictedOccupancy'] is num ? (data['predictedOccupancy'] as num).toInt() : 0,
      expectedBoarding: data['expectedBoarding'] is num ? (data['expectedBoarding'] as num).toInt() : 0,
      expectedExits: data['expectedExits'] is num ? (data['expectedExits'] as num).toInt() : 0,
      comfortScore: data['comfortScore'] is num ? (data['comfortScore'] as num).toInt() : 100,
      confidenceScore: data['confidenceScore'] is num ? (data['confidenceScore'] as num).toInt() : 100,
      generatedAt: data['generatedAt'] is Timestamp 
          ? (data['generatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'currentOccupancy': currentOccupancy,
      'predictedOccupancy': predictedOccupancy,
      'expectedBoarding': expectedBoarding,
      'expectedExits': expectedExits,
      'comfortScore': comfortScore,
      'confidenceScore': confidenceScore,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }
}
