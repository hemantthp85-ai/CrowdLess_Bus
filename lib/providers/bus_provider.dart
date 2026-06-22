import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../repositories/bus_repository.dart';
import 'ticket_provider.dart';

// Provide the BusRepository instance
final busRepositoryProvider = Provider<BusRepository>((ref) => BusRepository());

// Stream of all buses
final busesStreamProvider = StreamProvider<List<BusModel>>((ref) {
  final repository = ref.watch(busRepositoryProvider);
  return repository.getBusesStream();
});

// Provide a state for search query text (backward compatibility)
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered bus list based on search query text (backward compatibility)
final filteredBusesProvider = Provider<AsyncValue<List<BusModel>>>((ref) {
  final busesAsync = ref.watch(busesStreamProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  return busesAsync.when(
    data: (buses) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(buses);
      }
      final filtered = buses.where((bus) {
        return bus.busNumber.toLowerCase().contains(searchQuery) ||
               bus.route.toLowerCase().contains(searchQuery);
      }).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Stream of details for a specific bus
final busDetailsStreamProvider = StreamProvider.family<BusModel, String>((ref, busNumber) {
  final repository = ref.watch(busRepositoryProvider);
  return repository.getBusDetailsStream(busNumber);
});

// --- DOPS Search & Discovery Providers ---

// Stream of RouteModel list
final routesListStreamProvider = StreamProvider<List<RouteModel>>((ref) {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  return ticketRepo.getRoutesListStream();
});

// Dropdown states for source and destination stops
final selectedSourceStopProvider = StateProvider<String?>((ref) => null);
final selectedDestinationStopProvider = StateProvider<String?>((ref) => null);
final searchPerformedProvider = StateProvider<bool>((ref) => false);

// Provider to extract all unique stops dynamically from Firestore routes
final allUniqueStopsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final routesAsync = ref.watch(routesListStreamProvider);
  return routesAsync.when(
    data: (routes) {
      final Set<String> stopsSet = {};
      for (final route in routes) {
        stopsSet.addAll(route.stops);
      }
      return AsyncValue.data(stopsSet.toList()..sort());
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Helper to normalize stop names for comparison
String _normalizeStopName(String name) {
  String text = name.trim().toLowerCase();
  // Expand common abbreviations to ensure matches
  text = text.replaceAll(RegExp(r'\btech\b'), 'technology');
  text = text.replaceAll(RegExp(r'\bcol\b'), 'college');
  text = text.replaceAll(RegExp(r'\bcoll\b'), 'college');
  text = text.replaceAll(RegExp(r'\brly\b'), 'railway');
  text = text.replaceAll(RegExp(r'\bstn\b'), 'station');
  text = text.replaceAll(RegExp(r'\bjn\b'), 'junction');
  text = text.replaceAll(RegExp(r'\bjunc\b'), 'junction');
  text = text.replaceAll(RegExp(r'\bstd\b'), 'stand');
  // Remove special characters (like accents, dashes, dots)
  text = text.replaceAll(RegExp(r'[^\w\s]'), '');
  return text;
}

// Helper to determine if a route stop matches the user's selected stop
bool _matchesStop(String routeStop, String queryStop) {
  final cleanRoute = _normalizeStopName(routeStop);
  final cleanQuery = _normalizeStopName(queryStop);
  
  if (cleanRoute == cleanQuery) return true;
  if (cleanRoute.contains(cleanQuery) || cleanQuery.contains(cleanRoute)) return true;
  
  // Custom alias mappings for high-confidence matching
  const Map<String, List<String>> stopAliases = {
    'psg': ['psg college of technology', 'psg college', 'psg tech', 'psg'],
    'railway': ['railway station', 'coimbatore railway station', 'junction railway station', 'railway'],
    'airport': ['airport', 'coimbatore airport', 'airport stop'],
    'hope': ['hope college', 'hope'],
  };
  
  for (final entry in stopAliases.entries) {
    final list = entry.value;
    bool routeMatches = list.any((alias) => cleanRoute.contains(alias) || alias.contains(cleanRoute));
    bool queryMatches = list.any((alias) => cleanQuery.contains(alias) || alias.contains(cleanQuery));
    if (routeMatches && queryMatches) {
      return true;
    }
  }

  // Word subset check (if all words of one name exist in the other)
  final wordsRoute = cleanRoute.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  final wordsQuery = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  
  if (wordsRoute.isEmpty || wordsQuery.isEmpty) return false;
  
  if (wordsQuery.every((w) => wordsRoute.contains(w))) return true;
  if (wordsRoute.every((w) => wordsQuery.contains(w))) return true;
  
  return false;
}

// Search and rank buses provider using the Smart Bus Recommendation Engine
final searchBusesProvider = Provider<AsyncValue<List<BusModel>>>((ref) {
  final routesAsync = ref.watch(routesListStreamProvider);
  final busesAsync = ref.watch(busesStreamProvider);
  final sourceStop = ref.watch(selectedSourceStopProvider);
  final destStop = ref.watch(selectedDestinationStopProvider);
  final searchPerformed = ref.watch(searchPerformedProvider);

  if (!searchPerformed || sourceStop == null || destStop == null) {
    return const AsyncValue.data([]);
  }

  return routesAsync.when(
    data: (routes) {
      print('=== Route Matching Debug ===');
      print('Selected Source: "$sourceStop"');
      print('Selected Destination: "$destStop"');

      // 1. Filter matching routes where source stop is before destination stop
      final matchingRoutes = routes.where((route) {
        final List<int> srcIndices = [];
        final List<int> destIndices = [];
        
        for (int i = 0; i < route.stops.length; i++) {
          if (_matchesStop(route.stops[i], sourceStop)) {
            srcIndices.add(i);
          }
          if (_matchesStop(route.stops[i], destStop)) {
            destIndices.add(i);
          }
        }
        
        if (srcIndices.isEmpty && destIndices.isEmpty) {
          print('Route ${route.routeId} rejected. Reason: neither source stop nor destination stop matched any stops in the route ${route.stops}');
          return false;
        }
        if (srcIndices.isEmpty) {
          print('Route ${route.routeId} rejected. Reason: source stop "$sourceStop" did not match any stops in the route ${route.stops}');
          return false;
        }
        if (destIndices.isEmpty) {
          print('Route ${route.routeId} rejected. Reason: destination stop "$destStop" did not match any stops in the route ${route.stops}');
          return false;
        }
        
        // Find if there is a valid direction (source before destination)
        bool hasValidDirection = false;
        int? matchedSrcIdx;
        int? matchedDestIdx;
        for (final srcIdx in srcIndices) {
          for (final destIdx in destIndices) {
            if (srcIdx < destIdx) {
              hasValidDirection = true;
              matchedSrcIdx = srcIdx;
              matchedDestIdx = destIdx;
              break;
            }
          }
          if (hasValidDirection) break;
        }
        
        if (!hasValidDirection) {
          print('Route ${route.routeId} rejected. Reason: direction invalid (source appears at index $srcIndices and destination at index $destIndices) in stops ${route.stops}');
          return false;
        }
        
        final matchedSrcStopName = route.stops[matchedSrcIdx!];
        final matchedDestStopName = route.stops[matchedDestIdx!];
        print('Matched Route: ${route.routeId}');
        print('Matched Source Stop: "$matchedSrcStopName"');
        print('Matched Destination Stop: "$matchedDestStopName"');
        return true;
      }).toList();

      final matchingRouteIds = matchingRoutes.map((route) => route.routeId).toSet();

      return busesAsync.when(
        data: (buses) {
          // 2. Filter buses running on the matching routes (case-insensitive checks on routeId, route.buses, bus.busNumber, and bus.route)
          final matchedBuses = buses.where((bus) {
            final matches = matchingRoutes.any((route) =>
              route.routeId.toLowerCase() == bus.busNumber.toLowerCase() ||
              route.buses.any((b) => b.toLowerCase() == bus.busNumber.toLowerCase()) ||
              bus.route.toLowerCase().contains(route.routeId.toLowerCase()) ||
              route.routeId.toLowerCase() == bus.route.toLowerCase()
            );
            
            if (matches) {
              print('Matched Bus: ${bus.busNumber} (Runs on matched route ${bus.route})');
              return true;
            } else {
              print('Bus ${bus.busNumber} rejected. Reason: bus number is not in route.buses, routeId does not match busNumber, and bus route "${bus.route}" does not contain routeId in matchingRouteIds: $matchingRouteIds');
              return false;
            }
          }).toList();

          print('Total matched buses: ${matchedBuses.length}');
          print('============================');

          // 3. Smart Bus Recommendation Engine ranking
          matchedBuses.sort((a, b) {
            final double scoreA = (a.comfortScore * 0.4) + 
                                  ((1.0 - a.occupancyPercentage) * 30) + 
                                  (((60 - a.eta).clamp(0, 60) / 60.0) * 20) + 
                                  (a.confidenceScore * 0.1);
                                  
            final double scoreB = (b.comfortScore * 0.4) + 
                                  ((1.0 - b.occupancyPercentage) * 30) + 
                                  (((60 - b.eta).clamp(0, 60) / 60.0) * 20) + 
                                  (b.confidenceScore * 0.1);
            return scoreB.compareTo(scoreA); // Highest score first
          });

          return AsyncValue.data(matchedBuses);
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

