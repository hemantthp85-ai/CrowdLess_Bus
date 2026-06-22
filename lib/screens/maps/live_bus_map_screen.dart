import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/route_model.dart';
import '../../providers/bus_provider.dart';
import '../../providers/location_provider.dart';

class LiveBusMapScreen extends ConsumerStatefulWidget {
  final String busNumber;
  final double latitude;
  final double longitude;

  const LiveBusMapScreen({
    super.key,
    required this.busNumber,
    required this.latitude,
    required this.longitude,
  });

  @override
  ConsumerState<LiveBusMapScreen> createState() => _LiveBusMapScreenState();
}

class _LiveBusMapScreenState extends ConsumerState<LiveBusMapScreen> {
  GoogleMapController? mapController;
  LatLng? userLocation;
  bool _isLoading = true;
  String _loadingMessage = "Checking location permissions...";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    debugPrint("Map Debug: Starting permission check and location acquisition...");
    try {
      // 1. Check if location services are enabled.
      setState(() {
        _loadingMessage = "Checking if location services are enabled...";
      });
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint("Map Debug: Location services enabled status: $serviceEnabled");
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = "Location services are disabled. Please enable location services.";
          _isLoading = false;
        });
        return;
      }

      // 2. Check location permission status.
      setState(() {
        _loadingMessage = "Checking location permissions...";
      });
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint("Map Debug: Initial location permission: $permission");

      // 3. Request permission if denied.
      if (permission == LocationPermission.denied) {
        setState(() {
          _loadingMessage = "Requesting location permissions...";
        });
        permission = await Geolocator.requestPermission();
        debugPrint("Map Debug: Permission result after request: $permission");
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = "Location permission denied. Please grant permission to see your location.";
            _isLoading = false;
          });
          return;
        }
      }

      // 4. Handle deniedForever state gracefully.
      if (permission == LocationPermission.deniedForever) {
        debugPrint("Map Debug: Location permission permanently denied.");
        setState(() {
          _errorMessage = "Location permissions are permanently denied. Please enable them in settings.";
          _isLoading = false;
        });
        return;
      }

      // 5. Retrieve position.
      setState(() {
        _loadingMessage = "Acquiring location coordinates...";
      });
      debugPrint("Map Debug: Requesting current position...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint("Map Debug: Position retrieved: Lat ${position.latitude}, Lng ${position.longitude}");

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        _errorMessage = null; // Success!
      });
    } catch (e) {
      debugPrint("Map Debug: Exception caught during location initialization: $e");
      setState(() {
        _errorMessage = "Unable to access location. Please enable location services.";
        _isLoading = false; // Fallback to bus coordinates
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final LatLng busLocation = LatLng(widget.latitude, widget.longitude);
    debugPrint("Map Debug: Rendering screen. isLoading: $_isLoading, userLocation: $userLocation, busLocation: $busLocation");

    // 1. Show Loading State
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("${widget.busNumber} Live Tracking"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // Read routes list and selected stops from Riverpod
    final routesVal = ref.watch(routesListStreamProvider).value;
    final sourceStop = ref.watch(selectedSourceStopProvider);
    final destStop = ref.watch(selectedDestinationStopProvider);

    RouteModel? matchedRoute;
    final busNum = widget.busNumber.toUpperCase().trim();

    if (routesVal != null && sourceStop != null && destStop != null) {
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

    final List<LatLng> polylinePoints = [];
    if (stopNames.isNotEmpty) {
      for (final name in stopNames) {
        final coord = _getStopCoordinate(name, matchedRoute);
        if (coord != null) {
          polylinePoints.add(coord);
        }
      }
    }

    // Fallback: If no stop coordinates are available, just connect userLocation and busLocation
    if (polylinePoints.isEmpty && userLocation != null) {
      polylinePoints.add(userLocation!);
      polylinePoints.add(busLocation);
    }

    // Print required debugging logs
    print('=== LiveBusMapScreen Route Accuracy Debug ===');
    print('Selected Source: "$sourceStop"');
    print('Selected Destination: "$destStop"');
    print('Matched Route: "${matchedRoute?.routeId ?? "None"}"');
    print('Route Stops Used: ${stopNames.join(" -> ")}');
    print('Coordinate Count: ${polylinePoints.length}');
    print('Polyline Point Count (Route Stops): ${polylinePoints.length}');
    print('============================');

    // 2. Show Map (with potential error card overlay if location is unavailable)
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.busNumber} Live Tracking"),
      ),
      body: Stack(
        children: [
          // Main Google Map widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation ?? busLocation, // Fallback mode: Use bus coordinates if user location is null
              zoom: 14,
            ),
            myLocationEnabled: userLocation != null, // Render only if permission granted
            myLocationButtonEnabled: userLocation != null,
            zoomControlsEnabled: true,
            markers: {
              // Bus Marker
              Marker(
                markerId: const MarkerId("bus"),
                position: busLocation,
                infoWindow: InfoWindow(
                  title: widget.busNumber,
                  snippet: "ETA: 6 mins",
                ),
              ),
              // User Marker
              if (userLocation != null)
                Marker(
                  markerId: const MarkerId("user"),
                  position: userLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                  infoWindow: const InfoWindow(
                    title: "You",
                  ),
                ),
              // Intermediate Stop Markers
              for (int i = 0; i < stopNames.length; i++)
                if (_getStopCoordinate(stopNames[i], matchedRoute) != null)
                  Marker(
                    markerId: MarkerId("stop_$i"),
                    position: _getStopCoordinate(stopNames[i], matchedRoute)!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: InfoWindow(
                      title: stopNames[i],
                      snippet: "Stop ${i + 1}",
                    ),
                  ),
            },
            polylines: {
              if (polylinePoints.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId("route"),
                  color: Colors.blue,
                  width: 5,
                  points: polylinePoints,
                ),
            },
            onMapCreated: (controller) {
              debugPrint("Map Debug: GoogleMap widget initialized and created.");
              mapController = controller;
              if (userLocation != null) {
                LatLngBounds bounds = LatLngBounds(
                  southwest: LatLng(
                    userLocation!.latitude < busLocation.latitude ? userLocation!.latitude : busLocation.latitude,
                    userLocation!.longitude < busLocation.longitude ? userLocation!.longitude : busLocation.longitude,
                  ),
                  northeast: LatLng(
                    userLocation!.latitude > busLocation.latitude ? userLocation!.latitude : busLocation.latitude,
                    userLocation!.longitude > busLocation.longitude ? userLocation!.longitude : busLocation.longitude,
                  ),
                );
                Future.delayed(const Duration(milliseconds: 500), () {
                  mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
                });
              }
            },
          ),

          // User-friendly Error Card Overlay if location service fails or permission is denied
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _checkPermissionsAndGetLocation();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
