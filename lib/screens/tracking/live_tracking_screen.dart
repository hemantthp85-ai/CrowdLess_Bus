import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/colors.dart';
import '../../models/bus_model.dart';
import '../../providers/bus_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../models/route_model.dart';

class SimRouteStop {
  final String name;
  final LatLng position;
  SimRouteStop(this.name, this.position);
}

const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1E293B"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#94A3B8"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#0F172A"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334155"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1E293B"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#94A3B8"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0F172A"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334155"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#64748B"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1E293B"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0F172A"
      }
    ]
  }
]
''';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String busNumber;

  const LiveTrackingScreen({
    super.key,
    required this.busNumber,
  });

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  bool _useGoogleMaps = true; // Swappable by user

  // Simulation state variables
  List<SimRouteStop> _simulationStops = [];
  List<LatLng> _interpolatedPath = [];
  int _currentPathIndex = 0;
  double _simSpeed = 40.0; // km/h
  double _distanceRemaining = 5.4; // km
  int _etaSeconds = 300; // 5 mins
  String _nextStop = "";
  int _remainingStopsCount = 0;
  DateTime _lastUpdated = DateTime.now();

  Timer? _simTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initSimulation();
    _startSimulationTimers();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _countdownTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Helpers for stop normalization, matching, and coordinate lookup
  String _normalizeStopName(String name) {
    String text = name.trim().toLowerCase();
    text = text.replaceAll(RegExp(r'\btech\b'), 'technology');
    text = text.replaceAll(RegExp(r'\bcol\b'), 'college');
    text = text.replaceAll(RegExp(r'\bcoll\b'), 'college');
    text = text.replaceAll(RegExp(r'\brly\b'), 'railway');
    text = text.replaceAll(RegExp(r'\bstn\b'), 'station');
    text = text.replaceAll(RegExp(r'\bjn\b'), 'junction');
    text = text.replaceAll(RegExp(r'\bjunc\b'), 'junction');
    text = text.replaceAll(RegExp(r'\bstd\b'), 'stand');
    text = text.replaceAll(RegExp(r'[^\w\s]'), '');
    return text;
  }

  bool _matchesStop(String routeStop, String queryStop) {
    final cleanRoute = _normalizeStopName(routeStop);
    final cleanQuery = _normalizeStopName(queryStop);
    
    if (cleanRoute == cleanQuery) return true;
    if (cleanRoute.contains(cleanQuery) || cleanQuery.contains(cleanRoute)) return true;
    
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

    final wordsRoute = cleanRoute.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final wordsQuery = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    
    if (wordsRoute.isEmpty || wordsQuery.isEmpty) return false;
    
    if (wordsQuery.every((w) => wordsRoute.contains(w))) return true;
    if (wordsRoute.every((w) => wordsQuery.contains(w))) return true;
    
    return false;
  }

  LatLng? _getStopCoordinate(String stopName, RouteModel? matchedRoute) {
    final cleanName = stopName.trim().toLowerCase();
    
    // 1. First attempt to load stop coordinates from Firestore route data
    if (matchedRoute != null && matchedRoute.stopCoordinates.containsKey(cleanName)) {
      return matchedRoute.stopCoordinates[cleanName];
    }
    
    // Substring match in Firestore route coordinates
    if (matchedRoute != null) {
      for (final entry in matchedRoute.stopCoordinates.entries) {
        if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
          return entry.value;
        }
      }
    }

    // 2. Fallback to master map
    const Map<String, LatLng> stopCoordinatesMaster = {
      'gandhipuram': LatLng(11.0168, 76.9558),
      'gandhipuram junction': LatLng(11.0168, 76.9558),
      'lakshmi mills': LatLng(11.0094, 76.9806),
      'peelamedu': LatLng(11.0198, 76.9958),
      'psg college': LatLng(11.0252, 77.0028),
      'psg tech': LatLng(11.0252, 77.0028),
      'psg college of technology': LatLng(11.0252, 77.0028),
      'hope college': LatLng(11.0298, 77.0182),
      'airport': LatLng(11.0304, 77.0434),
      'coimbatore airport': LatLng(11.0304, 77.0434),
      'airport stop': LatLng(11.0304, 77.0434),
      'singanallur': LatLng(11.0008, 77.0256),
      'ramanathapuram': LatLng(10.9992, 76.9942),
      'sungam': LatLng(10.9984, 76.9804),
      'railway station': LatLng(10.9968, 76.9664),
      'coimbatore railway station': LatLng(10.9968, 76.9664),
      'kovaipudur': LatLng(10.9416, 76.9234),
      'kuniamuthur': LatLng(10.9702, 76.9458),
      'kuniyamuthur': LatLng(10.9702, 76.9458),
      'ukkadam': LatLng(10.9864, 76.9602),
      'town hall': LatLng(10.9952, 76.9608),
      'vadavalli': LatLng(11.0212, 76.9034),
      'lawley road': LatLng(11.0184, 76.9286),
      'agricultural university': LatLng(11.0124, 76.9362),
      'cross cut road': LatLng(11.0210, 76.9600),
      '100 feet road': LatLng(11.0250, 76.9700),
      'omni bus stand': LatLng(11.0298, 77.0182),
      'ondipudur': LatLng(11.0090, 77.0500),
      'cit': LatLng(11.0200, 77.0250),
      'karpagam': LatLng(10.8900, 76.9700),
      'saravanampatti': LatLng(11.0700, 76.9900),
      'sns': LatLng(11.0850, 76.9950),
      'thudiyalur': LatLng(11.0780, 76.9600),
      'kct': LatLng(11.0660, 76.9920),
      'chinnavedampatti': LatLng(11.0600, 77.0000),
    };

    if (stopCoordinatesMaster.containsKey(cleanName)) {
      return stopCoordinatesMaster[cleanName];
    }
    
    for (final entry in stopCoordinatesMaster.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }
    
    if (cleanName.contains('psg')) return stopCoordinatesMaster['psg college'];
    if (cleanName.contains('railway')) return stopCoordinatesMaster['railway station'];
    if (cleanName.contains('airport')) return stopCoordinatesMaster['airport'];
    if (cleanName.contains('hope')) return stopCoordinatesMaster['hope college'];
    if (cleanName.contains('gandhipuram')) return stopCoordinatesMaster['gandhipuram'];
    if (cleanName.contains('kuniamuthur') || cleanName.contains('kuniyamuthur')) return stopCoordinatesMaster['kuniamuthur'];
    
    return null;
  }

  void _initSimulation() {
    final busNum = widget.busNumber.toUpperCase().trim();
    
    // Read route list and selected stops from Riverpod
    final routesVal = ref.read(routesListStreamProvider).value;
    final sourceStop = ref.read(selectedSourceStopProvider);
    final destStop = ref.read(selectedDestinationStopProvider);

    RouteModel? matchedRoute;

    if (routesVal != null && sourceStop != null && destStop != null) {
      // 1. Try to find a route matching both source and destination in correct direction
      for (final r in routesVal) {
        int srcIdx = r.stops.indexWhere((s) => _matchesStop(s, sourceStop));
        int destIdx = r.stops.indexWhere((s) => _matchesStop(s, destStop));
        if (srcIdx != -1 && destIdx != -1 && srcIdx < destIdx) {
          if (r.routeId.toLowerCase() == busNum.toLowerCase() ||
              r.buses.any((b) => b.toLowerCase() == busNum.toLowerCase())) {
            matchedRoute = r;
            break;
          }
        }
      }
      
      // Fallback: Check any route matching source -> destination
      if (matchedRoute == null) {
        for (final r in routesVal) {
          int srcIdx = r.stops.indexWhere((s) => _matchesStop(s, sourceStop));
          int destIdx = r.stops.indexWhere((s) => _matchesStop(s, destStop));
          if (srcIdx != -1 && destIdx != -1 && srcIdx < destIdx) {
            matchedRoute = r;
            break;
          }
        }
      }
    }

    // 2. Extract correct subset of route stops (slice segment)
    List<String> stopNames = [];
    int startStopIndex = -1;
    int endStopIndex = -1;

    if (matchedRoute != null && sourceStop != null && destStop != null) {
      startStopIndex = matchedRoute.stops.indexWhere((s) => _matchesStop(s, sourceStop));
      endStopIndex = matchedRoute.stops.indexWhere((s) => _matchesStop(s, destStop));
      
      if (startStopIndex != -1 && endStopIndex != -1 && startStopIndex < endStopIndex) {
        stopNames = matchedRoute.stops.sublist(startStopIndex, endStopIndex + 1);
      } else {
        stopNames = matchedRoute.stops;
        startStopIndex = 0;
        endStopIndex = matchedRoute.stops.length - 1;
      }
    }

    // 3. Build simulation stops with coordinates (Firestore-first)
    List<SimRouteStop> stops = [];
    if (stopNames.isNotEmpty) {
      for (final name in stopNames) {
        final coord = _getStopCoordinate(name, matchedRoute);
        if (coord != null) {
          stops.add(SimRouteStop(name, coord));
        }
      }
    }

    // 4. Fallback to Coimbatore Predefined Demo coordinates for buses if no route/stops could be matched
    if (stops.isEmpty) {
      if (busNum.contains('21G')) {
        stops = [
          SimRouteStop('Gandhipuram', const LatLng(11.0168, 76.9558)),
          SimRouteStop('Lakshmi Mills', const LatLng(11.0094, 76.9806)),
          SimRouteStop('Peelamedu', const LatLng(11.0198, 76.9958)),
          SimRouteStop('PSG College', const LatLng(11.0252, 77.0028)),
          SimRouteStop('Hope College', const LatLng(11.0298, 77.0182)),
          SimRouteStop('Airport', const LatLng(11.0304, 77.0434)),
        ];
      } else if (busNum.contains('1C')) {
        stops = [
          SimRouteStop('Singanallur', const LatLng(11.0008, 77.0256)),
          SimRouteStop('Ramanathapuram', const LatLng(10.9992, 76.9942)),
          SimRouteStop('Sungam', const LatLng(10.9984, 76.9804)),
          SimRouteStop('Railway Station', const LatLng(10.9968, 76.9664)),
          SimRouteStop('Gandhipuram', const LatLng(11.0168, 76.9558)),
        ];
      } else if (busNum.contains('S1')) {
        stops = [
          SimRouteStop('Kovaipudur', const LatLng(10.9416, 76.9234)),
          SimRouteStop('Kuniamuthur', const LatLng(10.9702, 76.9458)),
          SimRouteStop('Ukkadam', const LatLng(10.9864, 76.9602)),
          SimRouteStop('Town Hall', const LatLng(10.9952, 76.9608)),
          SimRouteStop('Gandhipuram', const LatLng(11.0168, 76.9558)),
        ];
      } else if (busNum.contains('33G')) {
        stops = [
          SimRouteStop('Vadavalli', const LatLng(11.0212, 76.9034)),
          SimRouteStop('Lawley Road', const LatLng(11.0184, 76.9286)),
          SimRouteStop('Agricultural University', const LatLng(11.0124, 76.9362)),
          SimRouteStop('Railway Station', const LatLng(10.9968, 76.9664)),
          SimRouteStop('Gandhipuram', const LatLng(11.0168, 76.9558)),
        ];
      } else {
        stops = [
          SimRouteStop('Gandhipuram Junction', const LatLng(11.0168, 76.9558)),
          SimRouteStop('Cross Cut Road', const LatLng(11.0210, 76.9600)),
          SimRouteStop('100 Feet Road', const LatLng(11.0250, 76.9700)),
          SimRouteStop('Omni Bus Stand', const LatLng(11.0298, 77.0182)),
        ];
      }
    }

    _simulationStops = stops;

    // Interpolate segments to create smooth route coordinates (25 points per segment)
    _interpolatedPath = [];
    const int pointsPerSegment = 25;
    for (int i = 0; i < _simulationStops.length - 1; i++) {
      LatLng start = _simulationStops[i].position;
      LatLng end = _simulationStops[i + 1].position;
      for (int j = 0; j < pointsPerSegment; j++) {
        double t = j / pointsPerSegment;
        double lat = start.latitude + (end.latitude - start.latitude) * t;
        double lng = start.longitude + (end.longitude - start.longitude) * t;
        _interpolatedPath.add(LatLng(lat, lng));
      }
    }
    if (_simulationStops.isNotEmpty) {
      _interpolatedPath.add(_simulationStops.last.position);
    }
    
    // Print required debugging logs
    print('=== Route Accuracy Debug ===');
    print('Selected Source: "$sourceStop"');
    print('Selected Destination: "$destStop"');
    print('Matched Route: "${matchedRoute?.routeId ?? "None"}"');
    print('Route Stops Used: ${stopNames.join(" -> ")}');
    print('Coordinate Count: ${_simulationStops.length}');
    print('Polyline Point Count (Route Stops): ${_simulationStops.length}');
    print('Polyline Point Count (Interpolated): ${_interpolatedPath.length}');
    print('============================');

    _currentPathIndex = 0;
    _updateSimulatedParameters();
  }

  void _startSimulationTimers() {
    // Smooth simulated live movement
    _simTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      setState(() {
        _currentPathIndex = (_currentPathIndex + 1) % _interpolatedPath.length;
        _updateSimulatedParameters();
      });

      // Synchronize google maps camera tracking
      if (_useGoogleMaps && _mapController != null) {
        LatLng busLatLng = _interpolatedPath[_currentPathIndex];
        _mapController!.animateCamera(CameraUpdate.newLatLng(busLatLng));
      }
    });

    // Precision ETA Countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_etaSeconds > 0) {
        setState(() {
          _etaSeconds--;
        });
      }
    });
  }

  void _updateSimulatedParameters() {
    if (_interpolatedPath.isEmpty) return;

    const int pointsPerSegment = 25;
    int segmentIndex = (_currentPathIndex / pointsPerSegment).floor();
    segmentIndex = segmentIndex.clamp(0, _simulationStops.length - 1);

    if (segmentIndex < _simulationStops.length - 1) {
      _nextStop = _simulationStops[segmentIndex + 1].name;
      _remainingStopsCount = _simulationStops.length - 1 - segmentIndex;
    } else {
      _nextStop = "Destination Reached";
      _remainingStopsCount = 0;
    }

    // Realistic Speed profile: slow down near stops, accelerate in the middle
    int offsetInSegment = _currentPathIndex % pointsPerSegment;
    double segmentProgress = offsetInSegment / pointsPerSegment;
    double speedFactor = 0.35 + 0.65 * (segmentProgress * (1 - segmentProgress) * 4);
    _simSpeed = (32.0 + 18.0 * speedFactor) + (DateTime.now().second % 4 - 2);

    if (segmentIndex == _simulationStops.length - 1) {
      _simSpeed = 0.0;
    }

    // Geodesic distance calculation via Haversine Formula
    double totalDist = 0.0;
    for (int i = _currentPathIndex; i < _interpolatedPath.length - 1; i++) {
      totalDist += _distanceBetween(_interpolatedPath[i], _interpolatedPath[i + 1]);
    }
    _distanceRemaining = double.parse(totalDist.toStringAsFixed(1));
    if (_distanceRemaining < 0.05) _distanceRemaining = 0.0;

    // Direct dynamic ETA calculation based on real speed
    if (_simSpeed > 0) {
      _etaSeconds = ((_distanceRemaining / _simSpeed) * 3600).round();
    } else {
      _etaSeconds = 0;
    }

    _lastUpdated = DateTime.now();
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 - 
        math.cos((p2.latitude - p1.latitude) * p) / 2 + 
        math.cos(p1.latitude * p) * 
            math.cos(p2.latitude * p) * 
            (1 - math.cos((p2.longitude - p1.longitude) * p)) / 2;
    return 12742.0 * math.asin(math.sqrt(a)); // Haversine formula output in KM
  }

  // Update map camera bounds to fit both bus and user location
  void _updateCameraBounds(LatLng busLatLng, LatLng userLatLng) {
    if (_mapController == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        busLatLng.latitude < userLatLng.latitude ? busLatLng.latitude : userLatLng.latitude,
        busLatLng.longitude < userLatLng.longitude ? busLatLng.longitude : userLatLng.longitude,
      ),
      northeast: LatLng(
        busLatLng.latitude > userLatLng.latitude ? busLatLng.latitude : userLatLng.latitude,
        busLatLng.longitude > userLatLng.longitude ? busLatLng.longitude : userLatLng.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to current bus coordinates from Firestore stream
    final busAsync = ref.watch(busDetailsStreamProvider(widget.busNumber));
    // Listen to user device coordinate streams
    final userPosAsync = ref.watch(userLocationStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Live Tracking - ${widget.busNumber}',
          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
      body: busAsync.when(
        data: (bus) {
          // Snap user position to a midpoint stop in route if mock gps defaults are returned
          LatLng userPosition = userPosAsync.when(
            data: (pos) => LatLng(pos.latitude, pos.longitude),
            loading: () => _simulationStops.isNotEmpty 
                ? _simulationStops[(_simulationStops.length ~/ 2).clamp(0, _simulationStops.length - 1)].position 
                : const LatLng(11.0168, 76.9558),
            error: (_, __) => _simulationStops.isNotEmpty 
                ? _simulationStops[(_simulationStops.length ~/ 2).clamp(0, _simulationStops.length - 1)].position 
                : const LatLng(11.0168, 76.9558),
          );

          if (userPosition.latitude == 11.0168 && userPosition.longitude == 76.9558 && _simulationStops.isNotEmpty) {
            userPosition = _simulationStops[(_simulationStops.length ~/ 2).clamp(0, _simulationStops.length - 1)].position;
          }

          final busLatLng = _interpolatedPath.isNotEmpty 
              ? _interpolatedPath[_currentPathIndex] 
              : LatLng(bus.latitude, bus.longitude);

          return Stack(
            children: [
              // Main Map Widget
              Positioned.fill(
                child: _useGoogleMaps 
                    ? _buildGoogleMap(busLatLng, userPosition, bus) 
                    : _buildVectorCanvasMap(busLatLng, userPosition, bus, isDark),
              ),

              // Glassmorphic Floating Top Status Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopStatusBar(isDark),
              ),

              // Tactical view selector switch
              _buildMapStyleToggle(isDark),

              // HUD Draggable Bottom Overlay
              _buildBottomDraggableSheet(bus, isDark),
            ],
          );
        },
        loading: () => const Center(child: LoadingWidget(message: 'Initializing map telemetry...')),
        error: (error, _) => CustomErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(busDetailsStreamProvider(widget.busNumber)),
        ),
      ),
    );
  }

  Widget _buildTopStatusBar(bool isDark) {
    final now = DateTime.now();
    final diffSec = now.difference(_lastUpdated).inSeconds;
    final lastUpdatedText = diffSec <= 2 ? "Just now" : "${diffSec}s ago";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: kToolbarHeight + 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Live indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          // Speed
          Row(
            children: [
              Icon(Icons.speed, size: 14, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 4),
              Text(
                '${_simSpeed.toStringAsFixed(0)} km/h',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Distance Remaining
          Row(
            children: [
              Icon(Icons.alt_route, size: 14, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 4),
              Text(
                '${_distanceRemaining.toStringAsFixed(1)} km left',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Last updated
          Text(
            lastUpdatedText,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStyleToggle(bool isDark) {
    return Positioned(
      top: kToolbarHeight + 85,
      right: 16,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _useGoogleMaps = !_useGoogleMaps;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            _useGoogleMaps ? Icons.satellite_outlined : Icons.map_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleMap(LatLng busLatLng, LatLng userLatLng, BusModel bus) {
    final markers = {
      Marker(
        markerId: const MarkerId('bus_marker'),
        position: busLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Bus ${bus.busNumber}', snippet: bus.formattedStatus),
      ),
      Marker(
        markerId: const MarkerId('user_marker'),
        position: userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
    };

    // Add all route stops as markers
    for (int i = 0; i < _simulationStops.length; i++) {
      var stop = _simulationStops[i];
      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: stop.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: stop.name, snippet: 'Route Stop'),
        ),
      );
    }

    final polylines = {
      // Base route path
      Polyline(
        polylineId: const PolylineId('route_path'),
        points: _simulationStops.map((s) => s.position).toList(),
        color: AppColors.primary.withOpacity(0.4),
        width: 5,
      ),
      // Active route path traversed
      Polyline(
        polylineId: const PolylineId('active_path'),
        points: _interpolatedPath.sublist(0, _currentPathIndex + 1),
        color: AppColors.success,
        width: 5,
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: busLatLng,
        zoom: 14.5,
      ),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        controller.setMapStyle(_darkMapStyle);
        try {
          _updateCameraBounds(busLatLng, userLatLng);
        } catch (e) {
          // Fallback bounds
        }
      },
    );
  }

  Widget _buildVectorCanvasMap(LatLng busLatLng, LatLng userLatLng, BusModel bus, bool isDark) {
    return Container(
      color: isDark ? const Color(0xff0F172A) : const Color(0xffF1F5F9),
      child: Stack(
        children: [
          // Background grid animation
          Positioned.fill(
            child: CustomPaint(
              painter: VectorGridPainter(isDark: isDark),
            ),
          ),
          
          // Route nodes (User, Bus, Path)
          Positioned.fill(
            child: CustomPaint(
              painter: RoutePathPainter(
                stops: _simulationStops,
                busPos: busLatLng,
                userPos: userLatLng,
                busNumber: bus.busNumber,
                isDark: isDark,
                currentPathIndex: _currentPathIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDraggableSheet(BusModel bus, bool isDark) {
    final Color statusColor = bus.status.toLowerCase() == 'low' 
        ? AppColors.success 
        : (bus.status.toLowerCase() == 'moderate' ? AppColors.warning : AppColors.danger);

    // Format countdown display
    final minutes = _etaSeconds ~/ 60;
    final seconds = _etaSeconds % 60;
    final countdownStr = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator line
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header info: Bus number & status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              bus.busNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Smart Predictor Active',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      // Occupancy badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          bus.formattedStatus.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Route name
                  Text(
                    bus.route,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24, thickness: 0.5),

                  // Countdown section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT STOP ARRIVAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nextStop,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      // Big countdown timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm, color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              countdownStr,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.5),

                  // Stat Grid
                  Row(
                    children: [
                      _buildMiniStatCard(
                        icon: Icons.people_outline_rounded,
                        label: 'Capacity',
                        value: '${bus.occupancy}/${bus.capacity}',
                        color: AppColors.secondary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniStatCard(
                        icon: Icons.mood_rounded,
                        label: 'Comfort',
                        value: '${bus.comfortScore}%',
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniStatCard(
                        icon: Icons.pin_drop_outlined,
                        label: 'Stops Left',
                        value: '$_remainingStopsCount',
                        color: AppColors.warning,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Vertical Stop Timeline
                  _buildStopsTimelineVertical(isDark),
                  const SizedBox(height: 24),

                  // Passenger Experience Insights Card
                  _buildPassengerInsightsCard(bus, isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsTimelineVertical(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alt_route_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'ROUTE TIMELINE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _simulationStops.length,
          itemBuilder: (context, index) {
            final stop = _simulationStops[index];
            final isLast = index == _simulationStops.length - 1;
            
            // Determine status based on index segment
            const int pointsPerSegment = 25;
            int currentSegmentIndex = _currentPathIndex ~/ pointsPerSegment;
            bool isPassed = index < currentSegmentIndex;
            bool isCurrent = index == currentSegmentIndex;
            
            Color statusColor;
            Widget nodeWidget;
            if (isPassed) {
              statusColor = AppColors.success;
              nodeWidget = Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              );
            } else if (isCurrent) {
              statusColor = AppColors.warning;
              nodeWidget = Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warning, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            } else {
              statusColor = isDark ? Colors.white30 : Colors.black38;
              nodeWidget = Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline line & nodes
                  Column(
                    children: [
                      nodeWidget,
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isPassed ? AppColors.success : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Stop text details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                stop.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent 
                                      ? (isDark ? Colors.white : Colors.black) 
                                      : (isPassed ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight) : (isDark ? Colors.white38 : Colors.black38)),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  "Bus is currently here",
                                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                                ),
                              ] else if (isPassed) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "Passed",
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ],
                          ),
                          // Mini stats for stop if upcoming or next
                          if (index == currentSegmentIndex + 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Next in ${_etaSeconds ~/ 60}m',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPassengerInsightsCard(BusModel bus, bool isDark) {
    const int pointsPerSegment = 25;
    int currentSegmentIndex = _currentPathIndex ~/ pointsPerSegment;
    int nextStopPredictLoad = bus.predictedOccupancy;
    if (currentSegmentIndex < _simulationStops.length - 1) {
      nextStopPredictLoad = (bus.occupancy + 4 - (currentSegmentIndex % 3)).clamp(0, bus.capacity);
    }
    
    String comfortTip;
    IconData tipIcon;
    Color tipColor;
    if (bus.occupancyPercentage >= 0.8) {
      comfortTip = "Standing room only. Wait for next bus if comfort is preferred.";
      tipIcon = Icons.warning_amber_rounded;
      tipColor = AppColors.danger;
    } else if (bus.occupancyPercentage >= 0.45) {
      comfortTip = "Moderate load. Seats available near the rear exit.";
      tipIcon = Icons.info_outline_rounded;
      tipColor = AppColors.warning;
    } else {
      comfortTip = "Comfort is high; plenty of seats are currently free!";
      tipIcon = Icons.verified_user_outlined;
      tipColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [AppColors.surfaceDark, AppColors.backgroundDark]
              : [Colors.blue.withOpacity(0.03), Colors.blue.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'INTELLIGENT PASSENGER INSIGHTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Predicted load at next stop:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '$nextStopPredictLoad PAX',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DOPS Confidence score:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '${bus.confidenceScore}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tipIcon, color: tipColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comfortTip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VectorGridPainter extends CustomPainter {
  final bool isDark;
  VectorGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.04)
      ..strokeWidth = 1;

    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoutePathPainter extends CustomPainter {
  final List<SimRouteStop> stops;
  final LatLng busPos;
  final LatLng userPos;
  final String busNumber;
  final bool isDark;
  final int currentPathIndex;

  RoutePathPainter({
    required this.stops,
    required this.busPos,
    required this.userPos,
    required this.busNumber,
    required this.isDark,
    required this.currentPathIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stops.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var stop in stops) {
      double lat = stop.position.latitude;
      double lng = stop.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (userPos.latitude < minLat) minLat = userPos.latitude;
    if (userPos.latitude > maxLat) maxLat = userPos.latitude;
    if (userPos.longitude < minLng) minLng = userPos.longitude;
    if (userPos.longitude > maxLng) maxLng = userPos.longitude;

    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;
    
    if (latRange == 0) latRange = 0.01;
    if (lngRange == 0) lngRange = 0.01;

    minLat -= latRange * 0.15;
    maxLat += latRange * 0.15;
    minLng -= lngRange * 0.15;
    maxLng += lngRange * 0.15;
    latRange = maxLat - minLat;
    lngRange = maxLng - minLng;

    double getX(LatLng pos) {
      return 40 + ((pos.longitude - minLng) / lngRange) * (size.width - 80);
    }

    double getY(LatLng pos) {
      return size.height - 40 - ((pos.latitude - minLat) / latRange) * (size.height - 80);
    }

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    Offset center = Offset(size.width / 2, size.height / 2);
    for (double r = 50; r < size.width; r += 80) {
      canvas.drawCircle(center, r, gridPaint);
    }

    final roadPaint = Paint()
      ..color = isDark ? Colors.blueGrey.withOpacity(0.12) : Colors.grey.withOpacity(0.15)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = isDark ? Colors.blueGrey.withOpacity(0.25) : Colors.grey.withOpacity(0.35)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path roadPath = Path();
    roadPath.moveTo(getX(stops.first.position), getY(stops.first.position));
    for (int i = 1; i < stops.length; i++) {
      roadPath.lineTo(getX(stops[i].position), getY(stops[i].position));
    }
    
    canvas.drawPath(roadPath, roadBorderPaint);
    canvas.drawPath(roadPath, roadPaint);

    final activePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.8)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
    final glowPaint = Paint()
      ..color = AppColors.secondary.withOpacity(0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path activePath = Path();
    activePath.moveTo(getX(stops.first.position), getY(stops.first.position));
    
    const int pointsPerSegment = 25;
    int currentSegmentIndex = currentPathIndex ~/ pointsPerSegment;
    
    for (int i = 1; i <= currentSegmentIndex && i < stops.length; i++) {
      activePath.lineTo(getX(stops[i].position), getY(stops[i].position));
    }
    activePath.lineTo(getX(busPos), getY(busPos));
    
    canvas.drawPath(activePath, glowPaint);
    canvas.drawPath(activePath, activePaint);

    for (int i = 0; i < stops.length; i++) {
      var stop = stops[i];
      Offset stopOffset = Offset(getX(stop.position), getY(stop.position));
      
      bool isPassed = i <= currentSegmentIndex;
      bool isNext = i == currentSegmentIndex + 1;
      
      Color nodeColor;
      double radius;
      if (isPassed) {
        nodeColor = AppColors.success;
        radius = 8;
      } else if (isNext) {
        nodeColor = AppColors.warning;
        radius = 10;
      } else {
        nodeColor = isDark ? Colors.white54 : Colors.black45;
        radius = 6;
      }

      if (isNext) {
        final double pulse = 1.0 + 0.2 * math.sin(DateTime.now().millisecond * 0.005);
        final pulsePaint = Paint()
          ..color = AppColors.warning.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stopOffset, radius * pulse * 1.5, pulsePaint);
      }

      final outerPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(stopOffset, radius, outerPaint);
      
      final innerPaint = Paint()
        ..color = isDark ? AppColors.surfaceDark : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(stopOffset, radius - 3, innerPaint);

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      textPainter.text = TextSpan(
        text: stop.name,
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          fontSize: 10,
          fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      
      double labelYOffset = (i % 2 == 0) ? -22 : 12;
      canvas.drawRect(
        Rect.fromLTWH(stopOffset.dx - textPainter.width / 2 - 4, stopOffset.dy + labelYOffset - 2, textPainter.width + 8, textPainter.height + 4),
        Paint()..color = (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.75)..style = PaintingStyle.fill
      );
      textPainter.paint(canvas, Offset(stopOffset.dx - (textPainter.width / 2), stopOffset.dy + labelYOffset));
    }

    Offset userOffset = Offset(getX(userPos), getY(userPos));
    final userHalo = Paint()
      ..color = AppColors.secondary.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final userCenter = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final double userPulse = 1.0 + 0.3 * math.sin(DateTime.now().millisecond * 0.005);
    canvas.drawCircle(userOffset, 18 * userPulse, userHalo);
    canvas.drawCircle(userOffset, 8, userCenter);
    canvas.drawCircle(userOffset, 4, Paint()..color = Colors.white);

    final userText = TextPainter(textDirection: TextDirection.ltr);
    userText.text = const TextSpan(
      text: 'YOU',
      style: TextStyle(
        color: AppColors.secondary,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
    userText.layout();
    userText.paint(canvas, Offset(userOffset.dx - (userText.width / 2), userOffset.dy + 12));

    Offset busOffset = Offset(getX(busPos), getY(busPos));
    
    final double busPulse = 1.0 + 0.15 * math.sin(DateTime.now().millisecond * 0.008);
    final busGlow = Paint()
      ..color = AppColors.primary.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(busOffset, 22 * busPulse, busGlow);

    final busCardPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
      
    final RRect busRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: busOffset, width: 46, height: 32),
      const Radius.circular(8),
    );
    canvas.drawRRect(busRect, busCardPaint);
    
    final busBorder = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(busRect, busBorder);

    final busText = TextPainter(textDirection: TextDirection.ltr);
    busText.text = TextSpan(
      text: busNumber,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    busText.layout();
    busText.paint(canvas, Offset(busOffset.dx - (busText.width / 2), busOffset.dy - (busText.height / 2)));
  }

  @override
  bool shouldRepaint(covariant RoutePathPainter oldDelegate) {
    return oldDelegate.busPos != busPos || 
           oldDelegate.userPos != userPos || 
           oldDelegate.currentPathIndex != currentPathIndex ||
           oldDelegate.isDark != isDark;
  }
}
