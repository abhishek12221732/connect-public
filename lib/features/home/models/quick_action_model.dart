// lib/models/quick_action_model.dart

import 'package:flutter/material.dart';

class QuickAction {
  /// A unique identifier, e.g., 'add_event'.
  final String id;
  
  /// The text displayed below the icon, e.g., "Add Event".
  final String label;

  /// The icon to display.
  final IconData icon;

  /// A function that returns the actual `onPressed` callback.
  /// We use a builder to get access to the `BuildContext` for navigation.
  final VoidCallback Function(BuildContext context) actionBuilder;

  QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.actionBuilder,
  });
}