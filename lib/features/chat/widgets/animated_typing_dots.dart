import 'package:flutter/material.dart';

class AnimatedTypingDots extends StatefulWidget {
  const AnimatedTypingDots({super.key});

  @override
  _AnimatedTypingDotsState createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Duration _animationDuration = const Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _controller.value > index / 3 ? 1.0 : 0.3,
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
