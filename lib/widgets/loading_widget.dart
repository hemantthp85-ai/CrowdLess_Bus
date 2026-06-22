import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/colors.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool isOverlay;

  const LoadingWidget({
    super.key,
    this.message,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ],
      ),
    );

    if (isOverlay) {
      return Container(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
        child: child,
      );
    }

    return child;
  }
}

class BusCardShimmer extends StatelessWidget {
  const BusCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight;
    final highlightColor = isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlightLight;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 80, height: 24, color: Colors.white),
                Container(width: 60, height: 20, color: Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 200, height: 16, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 120, height: 14, color: Colors.white),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 100, height: 12, color: Colors.white),
                Container(width: 80, height: 12, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const BusCardShimmer(),
    );
  }
}
