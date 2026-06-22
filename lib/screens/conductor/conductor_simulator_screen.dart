import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../models/bus_model.dart';
import '../../models/ticket_model.dart';
import '../../providers/bus_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/custom_button.dart';
import '../../services/prediction_engine.dart';

class ConductorSimulatorScreen extends ConsumerStatefulWidget {
  const ConductorSimulatorScreen({super.key});

  @override
  ConsumerState<ConductorSimulatorScreen> createState() => _ConductorSimulatorScreenState();
}

class _ConductorSimulatorScreenState extends ConsumerState<ConductorSimulatorScreen> {
  String _selectedBusNumber = '21G'; // default selector
  String? _selectedSourceStop;
  String? _selectedDestinationStop;
  int _passengerCount = 1;
  int _exitCount = 1;

  @override
  void initState() {
    super.initState();
    // Prepopulate default routes in Firestore in case it's a fresh run
    Future.microtask(() {
      ref.read(ticketControllerProvider.notifier).prepopulateRoutes();
    });
  }

  // Helper to determine status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'moderate':
        return AppColors.warning;
      case 'high':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Subscribe to routes mapping
    final routesAsync = ref.watch(routesStreamProvider);
    // Subscribe to all buses stream
    final busesAsync = ref.watch(busesStreamProvider);
    // Subscribe to selected bus Firestore stream
    final busAsync = ref.watch(busDetailsStreamProvider(_selectedBusNumber));
    // Subscribe to simulator execution state
    final ticketState = ref.watch(ticketControllerProvider);

    // Listen for simulation alerts or errors
    ref.listen<TicketUIState>(ticketControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(ticketControllerProvider.notifier).clearError();
      } else if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket Issued successfully. Occupancy updated.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Conductor ETM Simulator'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.terminal, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'DOPS SIMULATOR',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Bus Selector Segmented bar
            busesAsync.when(
              data: (busesList) {
                final busNumbers = busesList.map((b) => b.busNumber).toList();
                if (busNumbers.isNotEmpty && !busNumbers.contains(_selectedBusNumber)) {
                  _selectedBusNumber = busNumbers.first;
                }
                return _buildBusSelectorBar(busNumbers, isDark);
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => _buildBusSelectorBar(['21G', 'S1', '1C', '10A', 'S2', 'K1'], isDark),
            ),
            const SizedBox(height: 24),

            // Load bus stream data
            busAsync.when(
              data: (bus) {
                // Populate default source/dest if stops are available
                final stops = routesAsync.value?[bus.busNumber] ?? [];
                if (stops.isNotEmpty) {
                  _selectedSourceStop ??= stops.first;
                  _selectedDestinationStop ??= stops.last;
                }

                final bool showRushAlert = _selectedSourceStop != null && 
                    PredictionEngine.collegeStops.any((col) => _selectedSourceStop!.contains(col));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. ETM Machine Live Header
                    _buildEtmHeaderCard(bus, isDark),
                    const SizedBox(height: 24),

                    // College Rush Alert Banners
                    if (showRushAlert) _buildCollegeRushAlert(isDark),

                    // 3. Ticket Issuance Form Section
                    _buildTicketFormCard(stops, bus, ticketState.isLoading, isDark),
                    const SizedBox(height: 24),

                    // 4. Last Ticket Receipt Preview
                    if (ticketState.lastGeneratedTicket != null)
                      _buildTicketReceipt(ticketState.lastGeneratedTicket!, isDark),
                    const SizedBox(height: 24),

                    // 5. Live ETM Metrics Panel & Exit stepper
                    _buildLiveMetricsPanel(bus, isDark),
                    const SizedBox(height: 24),

                    // 6. Prediction Analytics Panel
                    _buildPredictionAnalyticsPanel(bus, isDark),
                  ],
                );
              },
              loading: () => const Center(child: LoadingWidget(message: 'Syncing simulator telemetry...')),
              error: (err, _) => CustomErrorWidget(
                message: err.toString(),
                onRetry: () => ref.invalidate(busDetailsStreamProvider(_selectedBusNumber)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusSelectorBar(List<String> busNumbers, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: busNumbers.map((busNo) {
            final isSelected = _selectedBusNumber == busNo;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBusNumber = busNo;
                  _selectedSourceStop = null;
                  _selectedDestinationStop = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [AppColors.primary, AppColors.secondary])
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Bus $busNo',
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEtmHeaderCard(BusModel bus, bool isDark) {
    final statusColor = _getStatusColor(bus.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ETM TELEMETRY',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active ETM: ${bus.busNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  bus.formattedStatus,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bus.route,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Divider(height: 24, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMinicell('OCCUPANCY', '${bus.occupancy} / ${bus.capacity}'),
              _buildMinicell('AVAILABLE', '${bus.availableCapacity} seats'),
              _buildMinicell('COMFORT', '${bus.comfortScore}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinicell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCollegeRushAlert(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠ Rush Hour Alert (PSG / CIT / KCT)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                ),
                SizedBox(height: 2),
                Text(
                  'Current stop is near major college campus. High Boarding Expected.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketFormCard(List<String> stops, BusModel bus, bool isLoading, bool isDark) {
    // Fallback if stops stream has not loaded yet
    final List<String> sourceDropdownStops = stops.isNotEmpty ? stops : ['Singanallur'];
    final List<String> destDropdownStops = stops.isNotEmpty ? stops : ['Gandhipuram'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ISSUE ELECTRONIC TICKET',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 16),

          // Source Stop Dropdown
          DropdownButtonFormField<String>(
            value: _selectedSourceStop,
            decoration: const InputDecoration(
              labelText: 'Source Stop',
              prefixIcon: Icon(Icons.trip_origin_rounded, color: AppColors.success, size: 20),
            ),
            items: sourceDropdownStops.map((stop) {
              return DropdownMenuItem<String>(
                value: stop,
                child: Text(stop),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSourceStop = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Destination Stop Dropdown
          DropdownButtonFormField<String>(
            value: _selectedDestinationStop,
            decoration: const InputDecoration(
              labelText: 'Destination Stop',
              prefixIcon: Icon(Icons.sports_score_rounded, color: AppColors.danger, size: 20),
            ),
            items: destDropdownStops.map((stop) {
              return DropdownMenuItem<String>(
                value: stop,
                child: Text(stop),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedDestinationStop = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Passenger Count Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Passenger Count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _passengerCount > 1
                          ? () => setState(() => _passengerCount--)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '$_passengerCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => setState(() => _passengerCount++),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Issue Button
          CustomButton(
            text: 'Generate Ticket',
            isLoading: isLoading,
            icon: Icons.confirmation_number_outlined,
            onPressed: () {
              if (_selectedSourceStop != null && _selectedDestinationStop != null) {
                ref.read(ticketControllerProvider.notifier).createTicket(
                      busNumber: bus.busNumber,
                      sourceStop: _selectedSourceStop!,
                      destinationStop: _selectedDestinationStop!,
                      passengerCount: _passengerCount,
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTicketReceipt(TicketModel ticket, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Receipt header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ETM RECEIPT PREVIEW',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Icon(Icons.print, color: Colors.white, size: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TICKET ID:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(ticket.ticketId.substring(0, 10).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BUS NUMBER:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(ticket.busNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TIMESTAMP:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(DateFormat('hh:mm:ss a, dd MMM').format(ticket.timestamp), style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FROM', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          Text(ticket.sourceStop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.secondary, size: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TO', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          Text(ticket.destinationStop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PASSENGERS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      '${ticket.passengerCount} ADULT',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetricsPanel(BusModel bus, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE WORKLOAD METRICS',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Capacity utilization:'),
              Text(
                '${(bus.occupancyPercentage * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Alighting Exit Simulator Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Simulate Alighting Exits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    'Force exit passengers',
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.blueGrey),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 14),
                          onPressed: _exitCount > 1
                              ? () => setState(() => _exitCount--)
                              : null,
                        ),
                        Text('$_exitCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 14),
                          onPressed: () => setState(() => _exitCount++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: bus.occupancy > 0 
                        ? () {
                            ref.read(ticketControllerProvider.notifier).alightingEvent(
                              bus.busNumber,
                              _exitCount,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Exit', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionAnalyticsPanel(BusModel bus, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DOPS DYNAMIC PREDICTIONS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCell('Predicted at Next Stop', '${bus.predictedOccupancy} PAX', isDark),
              _buildMetricCell('Expected Boarding', '+${bus.expectedBoarding} PAX', isDark),
              _buildMetricCell('Expected Exits', '-${bus.expectedExits} PAX', isDark),
            ],
          ),
          
          const Divider(height: 28, thickness: 0.5),

          // Comfort level meter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Comfort Rating:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                '${bus.comfortScore} / 100 (${bus.comfortScore >= 70 ? "High Comfort" : (bus.comfortScore >= 40 ? "Moderate" : "Low Comfort")})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: bus.comfortScore >= 70 
                      ? AppColors.success 
                      : (bus.comfortScore >= 40 ? AppColors.warning : AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
