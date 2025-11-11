// lib/features/home/widgets/stats_grid.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StatsGrid extends StatelessWidget {
  final int journalCount;
  final int bucketListCount;
  final int questionCount;
  final int doneDatesCount;

  const StatsGrid({
    super.key,
    required this.journalCount,
    required this.bucketListCount,
    required this.questionCount,
    required this.doneDatesCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            'Your Stats',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          children: [
            StatsBox(
              icon: Icons.edit_note,
              value: journalCount.toString(),
              title: 'Notes By You',
              backgroundColor: colorScheme.secondary,
            ),
            StatsBox(
              icon: Icons.checklist_rtl,
              value: bucketListCount.toString(),
              title: 'Bucket List Items',
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            StatsBox(
              icon: Icons.favorite,
              value: doneDatesCount.toString(),
              title: 'Dates Done',
              backgroundColor: colorScheme.primary,
            ),
            StatsBox(
              icon: Icons.question_answer,
              value: questionCount.toString(),
              title: 'Questions Answered',
              backgroundColor: colorScheme.errorContainer.withOpacity(0.5),
            ),
          ],
        ),
      ],
    );
  }
}

// This is a presentational sub-widget and remains largely the same.
class StatsBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final Color? backgroundColor;
  final bool isLoading;

  const StatsBox({
    super.key,
    this.icon = Icons.grid_view_rounded,
    this.value = '',
    this.title = '',
    this.backgroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final effectiveBgColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final onBgColor = ThemeData.estimateBrightnessForColor(effectiveBgColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: theme.scaffoldBackgroundColor,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                icon,
                color: onBgColor.withOpacity(0.6),
                size: 24,
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: onBgColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onBgColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}