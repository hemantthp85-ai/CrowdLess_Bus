import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class OccupancyIndicator extends StatelessWidget {
  final int occupancy;
  final int capacity;
  final String status;
  final bool showSeatGrid;

  const OccupancyIndicator({
    super.key,
    required this.occupancy,
    required this.capacity,
    required this.status,
    this.showSeatGrid = false,
  });

  Color _getStatusColor() {
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

  String _getStatusText() {
    switch (status.toLowerCase()) {
      case 'low':
        return 'Low Crowd (Plenty of seats)';
      case 'moderate':
        return 'Moderate Crowd (Standing room only)';
      case 'high':
        return 'High Crowd (Near capacity)';
      default:
        return '$status Crowd';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double percent = capacity > 0 ? (occupancy / capacity).clamp(0.0, 1.0) : 0.0;
    final statusColor = _getStatusColor();

    if (showSeatGrid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressSection(context, percent, statusColor),
          const SizedBox(height: 24),
          Text(
            'Live Seat Map',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildSeatLayoutGrid(context, percent),
          const SizedBox(height: 16),
          _buildSeatLegend(context),
        ],
      );
    }

    return _buildProgressSection(context, percent, statusColor);
  }

  Widget _buildProgressSection(BuildContext context, double percent, Color statusColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Occupancy',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '$occupancy / $capacity Seats occupied',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                height: 12,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                height: 12,
                width: MediaQuery.of(context).size.width * percent,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.7),
                      statusColor,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getStatusText(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeatLayoutGrid(BuildContext context, double occupancyPercent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const int rows = 8;
    const int seatsPerRow = 4; // 2 left, 2 right (excluding aisle)
    const int totalLayoutSeats = rows * seatsPerRow;
    final int occupiedSeatsCount = (totalLayoutSeats * occupancyPercent).round();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Driver's section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'FRONT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                ),
              ),
              Icon(
                Icons.supervised_user_circle_sharp,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scrollable seat grid mimicking bus aisle
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows,
            itemBuilder: (context, rowIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left 2 seats
                    Row(
                      children: List.generate(2, (colIndex) {
                        final seatNumber = rowIndex * seatsPerRow + colIndex;
                        final isOccupied = seatNumber < occupiedSeatsCount;
                        return _buildSeatIcon(context, isOccupied);
                      }),
                    ),
                    // Bus Aisle
                    const Spacer(),
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Container(
                        width: 1,
                        height: 24,
                        color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.3),
                      ),
                    ),
                    const Spacer(),
                    // Right 2 seats
                    Row(
                      children: List.generate(2, (colIndex) {
                        final seatNumber = rowIndex * seatsPerRow + 2 + colIndex;
                        final isOccupied = seatNumber < occupiedSeatsCount;
                        return _buildSeatIcon(context, isOccupied);
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeatIcon(BuildContext context, bool isOccupied) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isOccupied 
            ? statusColor.withOpacity(0.2) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOccupied 
              ? statusColor 
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.chair_alt_rounded,
        size: 16,
        color: isOccupied 
            ? statusColor 
            : (isDark ? AppColors.textSecondaryDark.withOpacity(0.4) : AppColors.textSecondaryLight.withOpacity(0.4)),
      ),
    );
  }

  Widget _buildSeatLegend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(context, 'Available', isDark ? AppColors.borderDark : AppColors.borderLight, false),
        const SizedBox(width: 24),
        _buildLegendItem(context, 'Occupied', statusColor, true),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, bool isOccupied) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isOccupied ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            Icons.chair_alt_rounded,
            size: 10,
            color: isOccupied ? color : (isDark ? AppColors.textSecondaryDark.withOpacity(0.4) : AppColors.textSecondaryLight.withOpacity(0.4)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
