class PredictionEngine {
  // Major college stops where rush is expected
  static const List<String> collegeStops = [
    'PSG College',
    'CIT',
    'SNS',
    'KCT',
    'Karpagam'
  ];

  // Run the enhanced DOPS prediction algorithm
  PredictionResult predict({
    required String sourceStop,
    required String destinationStop,
    required int passengerCount,
    required int currentOccupancy,
    required int capacity,
    required List<String> routeStops,
    double historicalAvgBoarding = 0.0,
    double historicalAvgExits = 0.0,
    int recentFeedbackCount = 0,
    Map<String, int> feedbackCrowdCounts = const {},
  }) {
    int expectedBoarding = 0;
    int expectedExits = 0;
    int confidenceScore = 80; // baseline confidence

    final bool isCollegeStop = collegeStops.any(
      (college) => sourceStop.toLowerCase().contains(college.toLowerCase())
    );

    // 1. Boarding Prediction (Expected Boarding)
    // Detect peak hours: 08:00 AM – 10:00 AM, 04:00 PM – 07:00 PM
    final now = DateTime.now();
    final hour = now.hour;
    final isPeak = (hour >= 8 && hour <= 10) || (hour >= 16 && hour <= 19);

    if (historicalAvgBoarding > 0.0) {
      expectedBoarding = historicalAvgBoarding.round();
    } else {
      if (isCollegeStop) {
        expectedBoarding = 15 + (passengerCount % 5);
      } else {
        expectedBoarding = 3 + (passengerCount % 3);
      }
    }

    // Adjust for Peak Hours
    if (isPeak) {
      expectedBoarding = (expectedBoarding * 1.5).round();
      if (isCollegeStop && expectedBoarding < 15) {
        expectedBoarding = 15;
      }
    }

    // 2. Exit Prediction (Expected Exits)
    final bool isTerminal = destinationStop.toLowerCase().contains('gandhipuram') ||
        destinationStop.toLowerCase().contains('railway') ||
        destinationStop.toLowerCase().contains('ukkadam') ||
        destinationStop.toLowerCase().contains('singanallur') ||
        destinationStop.toLowerCase().contains('ondipudur');

    if (historicalAvgExits > 0.0) {
      expectedExits = historicalAvgExits.round();
    } else {
      if (isTerminal) {
        expectedExits = (currentOccupancy * 0.7).round();
      } else {
        expectedExits = (currentOccupancy * 0.15).round() + 1;
      }
    }

    // Safety checks
    if (expectedExits > (currentOccupancy + passengerCount)) {
      expectedExits = (currentOccupancy + passengerCount);
    }
    if (expectedExits < 0) expectedExits = 0;

    // 3. Predicted Occupancy
    final int predictedOccupancy = (currentOccupancy + passengerCount + expectedBoarding - expectedExits)
        .clamp(0, capacity);

    // 4. Comfort Score
    int comfortScore = 100;
    if (capacity > 0) {
      final double ratio = predictedOccupancy / capacity;
      if (ratio < 0.3) {
        comfortScore = 95;
      } else if (ratio < 0.6) {
        comfortScore = 75;
      } else if (ratio < 0.85) {
        comfortScore = 40;
      } else {
        comfortScore = 15;
      }
    }

    // 5. Confidence Score & Prediction Accuracy
    // Base confidence adjusts during peak hours (commutes are highly regular)
    if (isPeak) {
      confidenceScore += 10;
    }

    // Factor in passenger feedback
    int predictionAccuracy = 90; // Default accuracy
    if (recentFeedbackCount > 0) {
      // Determine ETM crowd status
      final double loadRatio = currentOccupancy / (capacity > 0 ? capacity : 1);
      String etmStatus = 'Low';
      if (loadRatio >= 0.85) {
        etmStatus = 'High';
      } else if (loadRatio >= 0.4) {
        etmStatus = 'Moderate';
      }

      int matchingFeedback = feedbackCrowdCounts[etmStatus] ?? 0;
      predictionAccuracy = ((matchingFeedback / recentFeedbackCount) * 100).round();
      
      // If feedback aligns with predicted occupancy range, boost confidence. If it conflicts, reduce.
      if (predictionAccuracy >= 60) {
        confidenceScore += 8;
      } else {
        confidenceScore -= 12;
      }
    }

    // Add small random noise for dynamic variability in normal limits
    confidenceScore = confidenceScore.clamp(55, 98);

    return PredictionResult(
      predictedOccupancy: predictedOccupancy,
      expectedBoarding: expectedBoarding,
      expectedExits: expectedExits,
      comfortScore: comfortScore,
      confidenceScore: confidenceScore,
      predictionAccuracy: predictionAccuracy,
      isRushAlert: isCollegeStop && expectedBoarding >= 12,
    );
  }
}

// Data class to wrap prediction outputs
class PredictionResult {
  final int predictedOccupancy;
  final int expectedBoarding;
  final int expectedExits;
  final int comfortScore;
  final int confidenceScore;
  final int predictionAccuracy;
  final bool isRushAlert;

  PredictionResult({
    required this.predictedOccupancy,
    required this.expectedBoarding,
    required this.expectedExits,
    required this.comfortScore,
    required this.confidenceScore,
    required this.predictionAccuracy,
    required this.isRushAlert,
  });
}

