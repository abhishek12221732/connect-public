import 'package:flutter/material.dart';
import 'dart:async';

class EnhancedTypingIndicator extends StatefulWidget {
  final String partnerName;
  
  const EnhancedTypingIndicator({
    super.key,
    this.partnerName = 'Partner',
  });

  @override
  State<EnhancedTypingIndicator> createState() => _EnhancedTypingIndicatorState();
}

class _EnhancedTypingIndicatorState extends State<EnhancedTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (index) => AnimationController(
      duration: Duration(milliseconds: 600 + (index * 100)),
      vsync: this,
    ));
    
    _dotAnimations = _dotControllers.map((controller) => 
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      )
    ).toList();
    
    _startAnimation();
  }

  void _startAnimation() {
    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _dotControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          // Partner avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              // THEME: Use theme's primary color
              color: colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 18,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(width: 8),

          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // THEME: Use a theme color like surfaceVariant to stand out from the background
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  // THEME: Use the theme's shadow color
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Typing dots
                ...List.generate(3, (index) => AnimatedBuilder(
                  animation: _dotAnimations[index],
                  builder: (context, child) {
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      child: Transform.scale(
                        scale: 0.8 + (_dotAnimations[index].value * 0.4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            // THEME: Use a theme-aware color for the dots
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                )),

                const SizedBox(width: 8),

                // Typing text
                Text(
                  '${widget.partnerName} is typing',
                  // THEME: Use textTheme and a theme-aware color
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}