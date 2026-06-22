import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import '../models/bus_model.dart';
import '../models/prediction_model.dart';
import '../models/route_model.dart';
import '../models/feedback_model.dart';
import '../services/prediction_engine.dart';

class TicketRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PredictionEngine _predictionEngine = PredictionEngine();

  // Initialize stops and default buses in 'routes' and 'buses' collections
  Future<void> initializeDefaultRoutes() async {
    final routesColl = _firestore.collection('routes');
    final busesColl = _firestore.collection('buses');
    
    // Check if routes are already initialized
    final snapshot = await routesColl.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final List<Map<String, dynamic>> routeSeeds = [
      {
        'id': '21G',
        'source': 'Singanallur',
        'destination': 'Gandhipuram',
        'stops': ['Singanallur', 'PSG College', 'Hope College', 'Gandhipuram'],
        'buses': ['21G'],
      },
      {
        'id': 'S1',
        'source': 'Ondipudur',
        'destination': 'Gandhipuram',
        'stops': ['Ondipudur', 'CIT', 'Hope College', 'Gandhipuram'],
        'buses': ['S1'],
      },
      {
        'id': '1C',
        'source': 'Kovaipudur',
        'destination': 'Railway Station',
        'stops': ['Kovaipudur', 'Kuniyamuthur', 'Karpagam', 'Railway Station'],
        'buses': ['1C'],
      },
      {
        'id': '10A',
        'source': 'Gandhipuram',
        'destination': 'Karpagam',
        'stops': ['Gandhipuram', 'Ukkadam', 'Kuniyamuthur', 'Karpagam'],
        'buses': ['10A'],
      },
      {
        'id': 'S2',
        'source': 'Gandhipuram',
        'destination': 'SNS',
        'stops': ['Gandhipuram', 'Saravanampatti', 'SNS', 'Thudiyalur'],
        'buses': ['S2'],
      },
      {
        'id': 'K1',
        'source': 'Gandhipuram',
        'destination': 'KCT',
        'stops': ['Gandhipuram', 'Saravanampatti', 'KCT', 'Chinnavedampatti'],
        'buses': ['K1'],
      },
    ];

    for (final seed in routeSeeds) {
      final id = seed['id'] as String;
      await routesColl.doc(id).set({
        'source': seed['source'],
        'destination': seed['destination'],
        'stops': seed['stops'],
        'buses': seed['buses'],
      });

      // Initialize corresponding bus document
      final busRef = busesColl.doc(id);
      final busSnap = await busRef.get();
      if (!busSnap.exists) {
        await busRef.set({
          'route': '${seed['source']} → ${seed['destination']}',
          'occupancy': 15,
          'capacity': 60,
          'latitude': 11.0168,
          'longitude': 76.9558,
          'eta': 10,
          'status': 'Low',
          'comfortScore': 95,
          'predictedOccupancy': 18,
          'expectedBoarding': 5,
          'expectedExits': 2,
          'confidenceScore': 90,
          'predictionAccuracy': 92,
          'occupancyHistory': [
            {
              'time': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 3))),
              'occupancy': 10,
            },
            {
              'time': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
              'occupancy': 12,
            },
            {
              'time': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
              'occupancy': 15,
            }
          ]
        });
      }
    }
    
    // Compute analytics initially
    await recalculateGlobalAnalytics();
  }

  // Stream routes from Firestore
  Stream<Map<String, List<String>>> getRoutesStream() {
    return _firestore.collection('routes').snapshots().map((snapshot) {
      final Map<String, List<String>> routesMap = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final stops = List<String>.from(data['stops'] ?? []);
        routesMap[doc.id] = stops;
      }
      return routesMap;
    });
  }

  // Stream RouteModel List for Discovery UI
  Stream<List<RouteModel>> getRoutesListStream() {
    return _firestore.collection('routes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
    });
  }

  // Submit Feedback from passenger
  Future<void> submitFeedback({
    required String busNumber,
    required String crowdLevel,
    required String userId,
  }) async {
    final feedbackRef = _firestore.collection('feedback').doc();
    final feedback = FeedbackModel(
      feedbackId: feedbackRef.id,
      busNumber: busNumber,
      crowdLevel: crowdLevel,
      timestamp: DateTime.now(),
      userId: userId,
    );
    await feedbackRef.set(feedback.toMap());

    // Trigger dynamic prediction updates based on the new feedback
    await recalculatePredictions(busNumber);
  }

  // Stream of feedback for a bus
  Stream<List<FeedbackModel>> getFeedbackStream(String busNumber) {
    return _firestore
        .collection('feedback')
        .where('busNumber', isEqualTo: busNumber)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FeedbackModel.fromFirestore(doc)).toList();
    });
  }

  // Re-run DOPS engine and update bus document with predictions
  Future<void> recalculatePredictions(String busNumber) async {
    final busDocRef = _firestore.collection('buses').doc(busNumber);
    final busSnap = await busDocRef.get();
    if (!busSnap.exists) return;
    
    final bus = BusModel.fromFirestore(busSnap);
    
    // 1. Fetch route data
    String routeId = busNumber; // Seeded match
    final routeSnap = await _firestore.collection('routes').doc(routeId).get();
    List<String> stops = [];
    String sourceStop = '';
    String destStop = '';
    if (routeSnap.exists) {
      final route = RouteModel.fromFirestore(routeSnap);
      stops = route.stops;
      sourceStop = route.source;
      destStop = route.destination;
    } else {
      stops = [bus.route.split('→').first.trim(), bus.route.split('→').last.trim()];
      sourceStop = stops.first;
      destStop = stops.last;
    }
    
    String currentStop = stops.length > 1 ? stops[1] : sourceStop;
    
    // 2. Fetch historical tickets count starting at currentStop
    double historicalAvgBoarding = 0.0;
    double historicalAvgExits = 0.0;
    try {
      final ticketsSnap = await _firestore
          .collection('tickets')
          .where('busNumber', isEqualTo: busNumber)
          .get();
          
      if (ticketsSnap.docs.isNotEmpty) {
        final List<TicketModel> allTickets = ticketsSnap.docs
            .map((doc) => TicketModel.fromFirestore(doc))
            .toList();
            
        final sourceTickets = allTickets.where((t) => t.sourceStop.toLowerCase() == currentStop.toLowerCase());
        if (sourceTickets.isNotEmpty) {
          historicalAvgBoarding = sourceTickets.map((t) => t.passengerCount).reduce((a, b) => a + b) / sourceTickets.length;
        }
        
        final destTickets = allTickets.where((t) => t.destinationStop.toLowerCase() == currentStop.toLowerCase());
        if (destTickets.isNotEmpty) {
          historicalAvgExits = destTickets.map((t) => t.passengerCount).reduce((a, b) => a + b) / destTickets.length;
        }
      }
    } catch (_) {}

    // 3. Fetch feedback submissions for the bus (last 2 hours)
    int recentFeedbackCount = 0;
    final Map<String, int> feedbackCrowdCounts = {'Low': 0, 'Moderate': 0, 'High': 0};
    try {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      final feedbackSnap = await _firestore
          .collection('feedback')
          .where('busNumber', isEqualTo: busNumber)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(twoHoursAgo))
          .get();
          
      recentFeedbackCount = feedbackSnap.docs.length;
      for (final doc in feedbackSnap.docs) {
        final level = doc.data()['crowdLevel'] as String? ?? 'Low';
        feedbackCrowdCounts[level] = (feedbackCrowdCounts[level] ?? 0) + 1;
      }
    } catch (_) {}

    // 4. Run Prediction Algorithm
    final predictionResult = _predictionEngine.predict(
      sourceStop: currentStop,
      destinationStop: destStop,
      passengerCount: 1, 
      currentOccupancy: bus.occupancy,
      capacity: bus.capacity,
      routeStops: stops,
      historicalAvgBoarding: historicalAvgBoarding,
      historicalAvgExits: historicalAvgExits,
      recentFeedbackCount: recentFeedbackCount,
      feedbackCrowdCounts: feedbackCrowdCounts,
    );

    // 5. Store Prediction history in 'predictions' collection
    final predictionRef = _firestore.collection('predictions').doc();
    final prediction = PredictionModel(
      id: predictionRef.id,
      busNumber: busNumber,
      currentOccupancy: bus.occupancy,
      predictedOccupancy: predictionResult.predictedOccupancy,
      expectedBoarding: predictionResult.expectedBoarding,
      expectedExits: predictionResult.expectedExits,
      comfortScore: predictionResult.comfortScore,
      confidenceScore: predictionResult.confidenceScore,
      generatedAt: DateTime.now(),
    );
    await predictionRef.set(prediction.toMap());

    // 6. Update Bus fields
    await busDocRef.update({
      'comfortScore': predictionResult.comfortScore,
      'predictedOccupancy': predictionResult.predictedOccupancy,
      'expectedBoarding': predictionResult.expectedBoarding,
      'expectedExits': predictionResult.expectedExits,
      'confidenceScore': predictionResult.confidenceScore,
      'predictionAccuracy': predictionResult.predictionAccuracy,
    });
    
    // 7. Aggregate stats to updates analytics collection
    await recalculateGlobalAnalytics();
  }

  // Aggregate global route analytics using history and ticket databases
  Future<void> recalculateGlobalAnalytics() async {
    try {
      final busesSnap = await _firestore.collection('buses').get();
      final ticketsSnap = await _firestore.collection('tickets').get();
      
      final List<BusModel> buses = busesSnap.docs
          .map((doc) => BusModel.fromFirestore(doc))
          .toList();
          
      final List<TicketModel> tickets = ticketsSnap.docs
          .map((doc) => TicketModel.fromFirestore(doc))
          .toList();

      double totalOccupancy = 0;
      int count = 0;
      for (final bus in buses) {
        totalOccupancy += bus.occupancy;
        count++;
      }
      double averageOccupancy = count > 0 ? totalOccupancy / count : 15.0;

      final Map<String, int> stopBoardingVolume = {};
      
      for (final t in tickets) {
        stopBoardingVolume[t.sourceStop] = (stopBoardingVolume[t.sourceStop] ?? 0) + t.passengerCount;
      }

      final defaultStops = [
        'Singanallur', 'PSG College', 'Hope College', 'Gandhipuram', 
        'Ondipudur', 'CIT', 'Kovaipudur', 'Kuniyamuthur', 
        'Karpagam', 'Railway Station', 'Saravanampatti', 'SNS', 
        'Thudiyalur', 'KCT', 'Ukkadam'
      ];
      for (final stop in defaultStops) {
        if (!stopBoardingVolume.containsKey(stop)) {
          stopBoardingVolume[stop] = stop.contains('College') || stop.contains('Gandhipuram') || stop.contains('Ukkadam') ? 22 : 6;
        }
      }

      final sortedStops = stopBoardingVolume.keys.toList()
        ..sort((a, b) => stopBoardingVolume[b]!.compareTo(stopBoardingVolume[a]!));

      final mostCrowded = sortedStops.take(4).toList();
      final leastCrowded = sortedStops.reversed.take(4).toList();

      final Map<String, String> stopOccupancies = {};
      for (final stop in stopBoardingVolume.keys) {
        final vol = stopBoardingVolume[stop] ?? 0;
        if (vol >= 15) {
          stopOccupancies[stop] = 'Red';
        } else if (vol >= 6) {
          stopOccupancies[stop] = 'Yellow';
        } else {
          stopOccupancies[stop] = 'Green';
        }
      }

      await _firestore.collection('analytics').doc('global_stats').set({
        'averageOccupancy': averageOccupancy,
        'mostCrowdedStops': mostCrowded,
        'leastCrowdedStops': leastCrowded,
        'stopOccupancies': stopOccupancies,
        'peakHours': ['08:00 AM - 10:00 AM', '04:00 PM - 07:00 PM'],
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error calculating analytics: $e');
    }
  }

  // Stream of analytics collection document
  Stream<DocumentSnapshot> getAnalyticsStream() {
    return _firestore.collection('analytics').doc('global_stats').snapshots();
  }

  // Issue ticket and trigger real-time updates
  Future<TicketModel> generateTicket({
    required String busNumber,
    required String sourceStop,
    required String destinationStop,
    required int passengerCount,
  }) async {
    final busDocRef = _firestore.collection('buses').doc(busNumber);
    final busSnap = await busDocRef.get();

    if (!busSnap.exists) {
      throw Exception('Bus $busNumber does not exist. Please initialize it.');
    }

    final BusModel bus = BusModel.fromFirestore(busSnap);
    
    // 1. Add ticket to the 'tickets' collection
    final ticketRef = _firestore.collection('tickets').doc();
    final ticket = TicketModel(
      ticketId: ticketRef.id,
      busNumber: busNumber,
      sourceStop: sourceStop,
      destinationStop: destinationStop,
      passengerCount: passengerCount,
      timestamp: DateTime.now(),
    );

    await ticketRef.set(ticket.toMap());

    // 2. Compute new occupancy
    final int newOccupancy = (bus.occupancy + passengerCount).clamp(0, bus.capacity);
    
    String newStatus = 'Low';
    final double loadPercentage = newOccupancy / bus.capacity;
    if (loadPercentage >= 0.85) {
      newStatus = 'High';
    } else if (loadPercentage >= 0.40) {
      newStatus = 'Moderate';
    }

    // 3. Update occupancy and append history
    await busDocRef.update({
      'occupancy': newOccupancy,
      'status': newStatus,
      'occupancyHistory': FieldValue.arrayUnion([
        {
          'time': Timestamp.now(),
          'occupancy': newOccupancy,
        }
      ]),
    });

    // 4. Force predictive recalculations immediately
    await recalculatePredictions(busNumber);

    return ticket;
  }

  // Record Passenger alighting exit events
  Future<void> recordPassengerExits(String busNumber, int exitCount) async {
    final busDocRef = _firestore.collection('buses').doc(busNumber);
    final busSnap = await busDocRef.get();
    if (!busSnap.exists) return;

    final bus = BusModel.fromFirestore(busSnap);
    final newOccupancy = (bus.occupancy - exitCount).clamp(0, bus.capacity);

    String newStatus = 'Low';
    final double loadPercentage = newOccupancy / bus.capacity;
    if (loadPercentage >= 0.85) {
      newStatus = 'High';
    } else if (loadPercentage >= 0.40) {
      newStatus = 'Moderate';
    }

    await busDocRef.update({
      'occupancy': newOccupancy,
      'status': newStatus,
      'occupancyHistory': FieldValue.arrayUnion([
        {
          'time': Timestamp.now(),
          'occupancy': newOccupancy,
        }
      ]),
    });

    // Recalculate predictions
    await recalculatePredictions(busNumber);
  }
}
