import 'package:flutter/material.dart';
import 'bus_data.dart';
import 'bus_firestore_service.dart';

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  final BusFirestoreService _service = BusFirestoreService();

  String _selectedBus = BusFirestoreService.availableBuses.first;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _service.ensureBusExists(_selectedBus);
  }

  void _onBusChanged(String? newBus) {
    if (newBus == null) return;
    setState(() => _selectedBus = newBus);
    _service.ensureBusExists(newBus);
  }

  Future<void> _handleTicket(BusData bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _service.issueTicket(_selectedBus, bus.occupancy, bus.capacity);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleExit(BusData bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _service.passengerExit(_selectedBus, bus.occupancy);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset bus?'),
        content: Text(
            'This will set occupancy and ticket count for $_selectedBus back to 0.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.resetBus(_selectedBus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CrowdLess — Conductor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset bus',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildBusSelector(),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<BusData>(
                  stream: _service.watchBus(_selectedBus),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }
                    final bus = snapshot.data!;
                    return _buildBusPanel(bus);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.indigo),
            const SizedBox(width: 12),
            const Text(
              'Selected Bus:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedBus,
                isExpanded: true,
                items: BusFirestoreService.availableBuses
                    .map((bus) => DropdownMenuItem(
                          value: bus,
                          child: Text(
                            bus,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: _onBusChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusPanel(BusData bus) {
    final statusInfo = _statusInfo(bus.crowdStatus);

    return Column(
      children: [
        // Crowd status badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: statusInfo.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusInfo.color, width: 2),
          ),
          child: Column(
            children: [
              Text(statusInfo.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 4),
              Text(
                statusInfo.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusInfo.color,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Occupancy display
        Text(
          '${bus.occupancy} / ${bus.capacity}',
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
        ),
        Text(
          'seats occupied (${bus.occupancyPercent.toStringAsFixed(0)}%)',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),

        const SizedBox(height: 8),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (bus.occupancyPercent / 100).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              color: statusInfo.color,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Total tickets issued today: ${bus.ticketsIssued}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),

        if (bus.route.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Route: ${bus.route}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],

        const Spacer(),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: bus.occupancy <= 0 || _isProcessing
                    ? null
                    : () => _handleExit(bus),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Exit'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : () => _handleTicket(bus),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ticket'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: Colors.indigo,
                ),
              ),
            ),
          ],
        ),

        if (bus.occupancy >= bus.capacity)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bus is full — ticket count still increases but seats stay capped',
              style: TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  _StatusInfo _statusInfo(CrowdStatus status) {
    switch (status) {
      case CrowdStatus.low:
        return _StatusInfo('🟢', 'Low Crowd', Colors.green);
      case CrowdStatus.moderate:
        return _StatusInfo('🟡', 'Moderate Crowd', Colors.orange);
      case CrowdStatus.full:
        return _StatusInfo('🔴', 'Full Crowd', Colors.red);
    }
  }
}

class _StatusInfo {
  final String emoji;
  final String label;
  final Color color;
  _StatusInfo(this.emoji, this.label, this.color);
}
