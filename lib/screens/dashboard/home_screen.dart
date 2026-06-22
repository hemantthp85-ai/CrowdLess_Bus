import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../models/bus_model.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../auth/login_screen.dart';
import '../bus_details/bus_details_screen.dart';
import '../conductor/conductor_simulator_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out of CrowdLess Bus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Auth and User profiles
    final authState = ref.watch(authStateProvider);
    final String greetingName = authState.when(
      data: (user) {
        if (user != null) {
          final profile = ref.watch(userProfileProvider(user.uid));
          return profile.when(
            data: (model) => model?.name ?? 'Commuter',
            loading: () => 'Commuter',
            error: (_, __) => 'Commuter',
          );
        }
        return 'Commuter';
      },
      loading: () => 'Commuter',
      error: (_, __) => 'Commuter',
    );

    // Location tracker state
    final positionAsync = ref.watch(currentUserPositionProvider);
    final String locationText = positionAsync.when(
      data: (pos) => '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E',
      loading: () => 'Locating device...',
      error: (_, __) => 'Singanallur Transit Hub',
    );

    // Dynamic Search & Recommendation Streams
    final searchPerformed = ref.watch(searchPerformedProvider);
    final searchBusesAsync = ref.watch(searchBusesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CrowdLess Bus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        actions: [
          // Conductor Simulator Toggle Button
          IconButton(
            icon: const Icon(
              Icons.terminal_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Conductor Simulator',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConductorSimulatorScreen(),
                ),
              );
            },
          ),
          // Action button to sign out quickly
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
            ),
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate and reload streams/futures
          ref.invalidate(busesStreamProvider);
          ref.invalidate(routesListStreamProvider);
          ref.invalidate(analyticsStreamProvider);
          ref.invalidate(currentUserPositionProvider);
          // Wait for reloading
          await ref.read(currentUserPositionProvider.future);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Greeting Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $greetingName 👋',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.secondary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationText,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Small pulsing live signal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE GPS',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Discovery Search drop downs
              _buildDiscoverySearch(context, ref, isDark),
              const SizedBox(height: 28),

              // Global route analytics panel
              const AnalyticsPanel(),
              const SizedBox(height: 28),

              // Search results or matching buses header
              if (searchPerformed) ...[
                Text(
                  'Matching Buses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 16),

                searchBusesAsync.when(
                  data: (buses) {
                    if (buses.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_bus_filled_outlined,
                                size: 48,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No direct buses available for this route.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final recommendedBus = buses.first;
                    final otherBuses = buses.skip(1).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRecommendedBusCard(context, recommendedBus, isDark),
                        if (otherBuses.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Other Available Buses',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: otherBuses.length,
                            itemBuilder: (context, index) {
                              return BusCard(bus: otherBuses[index]);
                            },
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const ShimmerList(count: 2),
                  error: (error, _) => CustomErrorWidget(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(routesListStreamProvider),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverySearch(BuildContext context, WidgetRef ref, bool isDark) {
    final stopsAsync = ref.watch(allUniqueStopsProvider);
    final selectedSource = ref.watch(selectedSourceStopProvider);
    final selectedDest = ref.watch(selectedDestinationStopProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DISCOVER YOUR ROUTE',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 16),
          stopsAsync.when(
            data: (stops) {
              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSource,
                    decoration: const InputDecoration(
                      labelText: 'From (Source Stop)',
                      prefixIcon: Icon(Icons.trip_origin_rounded, color: AppColors.success, size: 20),
                    ),
                    items: stops.map((stop) {
                      return DropdownMenuItem<String>(
                        value: stop,
                        child: Text(stop),
                      );
                    }).toList(),
                    onChanged: (val) {
                      ref.read(selectedSourceStopProvider.notifier).state = val;
                      ref.read(searchPerformedProvider.notifier).state = false;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDest,
                    decoration: const InputDecoration(
                      labelText: 'To (Destination Stop)',
                      prefixIcon: Icon(Icons.sports_score_rounded, color: AppColors.danger, size: 20),
                    ),
                    items: stops.map((stop) {
                      return DropdownMenuItem<String>(
                        value: stop,
                        child: Text(stop),
                      );
                    }).toList(),
                    onChanged: (val) {
                      ref.read(selectedDestinationStopProvider.notifier).state = val;
                      ref.read(searchPerformedProvider.notifier).state = false;
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Text('Error loading stops: $err'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: selectedSource != null && selectedDest != null
                ? () {
                    ref.read(searchPerformedProvider.notifier).state = true;
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text(
              'Search Available Buses',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedBusCard(BuildContext context, BusModel bus, bool isDark) {
    final Color statusColor = bus.status.toLowerCase() == 'low' 
        ? AppColors.success 
        : (bus.status.toLowerCase() == 'moderate' ? AppColors.warning : AppColors.danger);
        
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xff1E293B), const Color(0xff0F172A)]
              : [const Color(0xffE3F2FD), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusDetailsScreen(busNumber: bus.busNumber),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'RECOMMENDED BUS',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ETA: ${bus.eta} MINS',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bus ${bus.busNumber}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                            ),
                            Text(
                              bus.route,
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRecommendMetric('COMFORT', '${bus.comfortScore}%', Colors.blue),
                      _buildRecommendMetric('CONFIDENCE', '${bus.confidenceScore}%', Colors.purple),
                      _buildRecommendMetric('CROWD LEVEL', bus.status, statusColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}

class AnalyticsPanel extends ConsumerStatefulWidget {
  const AnalyticsPanel({super.key});

  @override
  ConsumerState<AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends ConsumerState<AnalyticsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analyticsAsync = ref.watch(analyticsStreamProvider);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            leading: const Icon(Icons.analytics_rounded, color: AppColors.primary),
            title: const Text(
              'Global Route Intelligence',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: const Text(
              'Historical Analytics & Heat Map',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
          ),
          if (_isExpanded)
            analyticsAsync.when(
              data: (doc) {
                if (!doc.exists) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('Telemetry syncing. Issue tickets to view history.'),
                  );
                }
                final data = doc.data() as Map<String, dynamic>;
                final avgOcc = data['averageOccupancy'] is num ? (data['averageOccupancy'] as num).toDouble() : 15.0;
                final mostCrowded = List<String>.from(data['mostCrowdedStops'] ?? []);
                final stopOccupancies = Map<String, dynamic>.from(data['stopOccupancies'] ?? {});
                
                final now = DateTime.now();
                final hour = now.hour;
                final isPeak = (hour >= 8 && hour <= 10) || (hour >= 16 && hour <= 19);

                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16),
                      // Peak hours indicator
                      if (isPeak)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.flash_on_rounded, color: AppColors.danger, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Peak Crowd Expected (Rush Commute Hour)',
                                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      // Row with Avg Occupancy Circular progress and Peak Hours
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(
                              context,
                              'Avg Occupancy',
                              '${avgOcc.toStringAsFixed(1)} pax',
                              Icons.people_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatTile(
                              context,
                              'Peak Travel Hours',
                              '08:00 AM - 10:00 AM\n04:00 PM - 07:00 PM',
                              Icons.schedule,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Most Crowded stops
                      const Text(
                        'Most Crowded Stops',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mostCrowded.map((stop) {
                          return Chip(
                            avatar: const Icon(Icons.trending_up, color: AppColors.danger, size: 14),
                            label: Text(stop, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.danger.withOpacity(0.05),
                            side: BorderSide(color: AppColors.danger.withOpacity(0.1)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Occupancy Heat Map
                      const Text(
                        'Live Occupancy Heat Map',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: stopOccupancies.entries.map((entry) {
                            final stop = entry.key;
                            final colorStatus = entry.value as String;
                            Color indicatorColor = AppColors.success;
                            if (colorStatus.toLowerCase() == 'red') indicatorColor = AppColors.danger;
                            if (colorStatus.toLowerCase() == 'yellow') indicatorColor = AppColors.warning;

                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.borderDark.withOpacity(0.3) : AppColors.borderLight.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: indicatorColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: indicatorColor.withOpacity(0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    stop,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Error syncing analytics: $err'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.borderDark.withOpacity(0.2) : AppColors.borderLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
