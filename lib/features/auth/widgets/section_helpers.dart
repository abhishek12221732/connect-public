// lib/features/profile/widgets/section_helpers.dart

import 'package:flutter/material.dart';

Widget buildSectionTitle(BuildContext context, String title, {IconData? icon, Color? color}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6, top: 18),
    child: Row(
      children: [
        if (icon != null)
          Container(
            decoration: BoxDecoration(
              color: color ?? theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (color ?? theme.colorScheme.primary).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: theme.colorScheme.onPrimary, size: 20),
          ),
        if (icon != null) const SizedBox(width: 10),
        Text(title, style: theme.textTheme.titleLarge),
      ],
    ),
  );
}

Widget buildInfoCard(Widget content) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: content,
    ),
  );
}