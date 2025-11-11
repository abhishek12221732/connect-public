// lib/features/widgets/pulsing_dots_indicator.dart
// (Or wherever you have this file)

import 'package:flutter/material.dart';
import 'dart:math' show pi, sin; // Import sin and pi

class PulsingDotsIndicator extends StatefulWidget {
  /// The total width of the indicator.
  final double size;
  
  /// The list of colors for the dots. The number of dots will match the length of this list.
  final List<Color> colors;

  const PulsingDotsIndicator({
    super.key,
    this.size = 60.0,
    this.colors = const [
      Colors.blue,
      Colors.red,
      Colors.green,
    ],
  });

  @override
  _PulsingDotsIndicatorState createState() => _PulsingDotsIndicatorState();
}

class _PulsingDotsIndicatorState extends State<PulsingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    // ✨ [MODIFIED] No longer needs `reverse: true`. 
    // The sin wave naturally handles the up-and-down motion.
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size / 3, // Keep the height proportional
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.colors.length, (index) {
          
          // ✨ --- THIS IS THE NEW LOGIC --- ✨
          // We use AnimatedBuilder to manually control the animation
          // based on a continuous sin wave.
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // 1. Get the number of dots
              final dotCount = widget.colors.length;

              // 2. Create a phase-offset value for each dot.
              // This makes the wave flow from one dot to the next.
              final animationValue = _controller.value + (index / dotCount);

              // 3. Calculate the sin value. This gives a smooth -1.0 to 1.0 wave.
              final sinValue = sin(animationValue * 2 * pi);

              // 4. Normalize the sin value from [-1, 1] to [0, 1].
              final normalizedValue = (sinValue + 1.0) / 2.0;

              // 5. Map the [0, 1] value to our desired scale range [0.4, 1.0].
              final scale = (normalizedValue * 0.6) + 0.4;
              
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            // The child is the dot, which is built once and passed
            // to the builder for efficiency.
            child: _buildDot(index),
          );
          // ✨ --- END OF NEW LOGIC --- ✨
        }),
      ),
    );
  }

  Widget _buildDot(int index) {
    // This helper widget is unchanged.
    final dotSize = (widget.size / widget.colors.length) * 0.75;
    
    return SizedBox.fromSize(
      size: Size.square(dotSize),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.colors[index],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}