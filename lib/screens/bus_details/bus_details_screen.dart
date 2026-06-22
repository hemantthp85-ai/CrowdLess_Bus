import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../models/bus_model.dart';
import '../../providers/bus_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/occupancy_indicator.dart';
import '../../widgets/custom_button.dart';
import '../tracking/live_tracking_screen.dart';

class BusDetailsScreen extends ConsumerWidget {
  final String busNumber;

  const BusDetailsScreen({
    super.key,
    required this.busNumber,
  });

  // Helper to determine next stop name based on bus number
  String _getNextStopName(String busNo) {
    switch (busNo.toUpperCase()) {
      case '21G':
        return 'Peelamedu Junction';
      case 'S1':
        return 'Hopes College Stop';
      case '1C':
        return 'Railway Station Corner';
      default:
        return 'Upcoming Transit Stop';
    }
  }

  // Helper to get route stops timeline
  List<String> _getRouteStops(String busNo, String route) {
    final parts = route.split('→');
    final start = parts.isNotEmpty ? parts.first.trim() : 'Start';
    final end = parts.length > 1 ? parts.last.trim() : 'Destination';
    return [start, _getNextStopName(busNo), end];
  }

  Color _getMeterColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Listen to real-time streams of the specific bus details from Firestore
    final busAsync = ref.watch(busDetailsStreamProvider(busNumber));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Bus $busNumber Details'),
      ),
      body: busAsync.when(
        data: (bus) {
          final stops = _getRouteStops(bus.busNumber, bus.route);
          final nextStop = _getNextStopName(bus.busNumber);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Card (Glassmorphic look)
                Hero(
                  tag: 'bus_hero_${bus.busNumber}',
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                bus.busNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ETA: ${bus.eta} MINS',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bus.route,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Next Stop: $nextStop',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // Occupancy Seating Section
                OccupancyIndicator(
                  occupancy: bus.occupancy,
                  capacity: bus.capacity,
                  status: bus.status,
                  showSeatGrid: true,
                ),

                const SizedBox(height: 28),

                // ⚡ DOPS Dynamic Predictions Dashboard Panel
                _buildDopsAnalyticsCard(context, bus, isDark),

                const SizedBox(height: 32),

                // Route stops timeline section
                Text(
                  'Route Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildTimelineList(context, stops, isDark),
              ],
            ),
          );
        },
        loading: () => const Center(child: LoadingWidget(message: 'Loading details...')),
        error: (error, _) => CustomErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(busDetailsStreamProvider(busNumber)),
        ),
      ),
     bottomSheet: busAsync.when(
  data: (bus) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      border: Border(
        top: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
    ),
    child: CustomButton(
      text: 'Track Live on Map',
      icon: Icons.map_outlined,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackingScreen(
              busNumber: bus.busNumber,
            ),
          ),
        );
      },
    ),
  ),
  loading: () => const SizedBox.shrink(),
 error: (_, __) => const SizedBox.shrink(),
),
);
}

Widget _buildDopsAnalyticsCard(BuildContext context, BusModel bus, bool isDark) {
    final comfortColor = _getMeterColor(bus.comfortScore);
    
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'DOPS PREDICTIVE FORECAST',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CONFIDENCE: ${bus.confidenceScore}%',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),

          // Next Stop Predictions Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildForecastCell('Next Stop Predicted', '${bus.predictedOccupancy} pax', isDark),
              _buildForecastCell('Expected Boarding', '+${bus.expectedBoarding} pax', isDark),
              _buildForecastCell('Expected Exits', '-${bus.expectedExits} pax', isDark),
            ],
          ),
          
          const Divider(height: 24, thickness: 0.5),

          // Comfort Meter progress
          _buildMeterBar(
            context: context,
            label: 'Rider Comfort Index',
            score: bus.comfortScore,
            color: comfortColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Confidence Meter progress
          _buildMeterBar(
            context: context,
            label: 'Algorithm Confidence',
            score: bus.confidenceScore,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCell(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBar({
    required BuildContext context,
    required String label,
    required int score,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '$score%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            color: color,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineList(BuildContext context, List<String> stops, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final isLast = index == stops.length - 1;
        final isNext = index == 1; // Middle item represents the next stop
        
        return IntrinsicHeight(
          child: Row(
            children: [
              // Column for the timeline indicator (dots & lines)
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isNext 
                          ? AppColors.primary 
                          : (isLast ? Colors.transparent : (isDark ? AppColors.borderDark : AppColors.borderLight)),
                      border: Border.all(
                        color: isNext ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        width: isNext ? 3 : 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Stop Name / Description Column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stops[index],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                              color: isNext 
                                  ? AppColors.primary 
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        index == 0 
                            ? 'Departed Terminal' 
                            : (isNext ? 'Approaching Next Stop' : 'Final Terminal Destination'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isNext 
                                  ? AppColors.primary.withOpacity(0.8) 
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
    );
  }
}
