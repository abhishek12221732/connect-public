import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';

class PartnerSharedInsightCard extends StatelessWidget {
  final String partnerName;
  final String insightPreview;
  final VoidCallback onTap;
  final bool isFullCheckIn;

  const PartnerSharedInsightCard({
    super.key,
    required this.partnerName,
    required this.insightPreview,
    required this.onTap,
    this.isFullCheckIn = false,
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initial = partnerName.isNotEmpty ? partnerName.trim()[0].toUpperCase() : '?';
    final partnerImage = Provider.of<UserProvider>(context, listen: false).getPartnerProfileImageSync();

    // THEME: Replaced the main Container with a Card for better theme consistency
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20), // Should match Card's shape
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: partnerImage,
                // THEME: Use a theme-aware background and text color
                backgroundColor: colorScheme.secondary,
                child: null,
              ),
              const SizedBox(width: 16),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            partnerName.split(' ').first + (isFullCheckIn ? "'s Full Check-in" : "'s Shared Insight"),
                            // THEME: Use theme's text styles
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            // THEME: Use conditional theme colors for the tag
                            color: isFullCheckIn ? colorScheme.primary : colorScheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isFullCheckIn ? 'Full Check-in' : 'Shared Insight',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              // THEME: Use corresponding 'on' colors for the tag text
                              color: isFullCheckIn ? colorScheme.onPrimary : colorScheme.onSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      insightPreview,
                      // THEME: Use a subtle, theme-aware text color
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        height: 1.4
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}