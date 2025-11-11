import 'package:flutter/material.dart';

class FabMenu extends StatefulWidget {
  final VoidCallback onAddEvent;
  final VoidCallback onGenerateDateIdea;

  const FabMenu({
    super.key,
    required this.onAddEvent,
    required this.onGenerateDateIdea,
  });

  @override
  State<FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<FabMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.small(
            heroTag: label,
            onPressed: onPressed,
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Background tap detector to close menu
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              // CORRECTED: Changed scrim to transparent for an invisible dismiss layer
              child: Container(color: Colors.transparent),
            ),
          ),
        // Menu Options
        Padding(
          padding: const EdgeInsets.only(bottom: 80.0, right: 8.0),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildOption(
                  context: context,
                  icon: Icons.local_fire_department,
                  label: 'Generate Date Idea',
                  onPressed: () {
                    _toggle();
                    widget.onGenerateDateIdea();
                  },
                ),
                _buildOption(
                  context: context,
                  icon: Icons.event_note,
                  label: 'Add Event',
                  onPressed: () {
                    _toggle();
                    widget.onAddEvent();
                  },
                ),
              ],
            ),
          ),
        ),
        // Main FAB
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0.0, // Rotates 45 degrees
            duration: const Duration(milliseconds: 250),
            child: Icon(_expanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
}