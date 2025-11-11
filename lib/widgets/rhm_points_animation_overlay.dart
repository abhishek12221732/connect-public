import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feelings/services/rhm_animation_service.dart';

class RhmPointsAnimationOverlay extends StatefulWidget {
  final Widget child;
  const RhmPointsAnimationOverlay({super.key, required this.child});

  @override
  _RhmPointsAnimationOverlayState createState() =>
      _RhmPointsAnimationOverlayState();
}

class _RhmPointsAnimationOverlayState extends State<RhmPointsAnimationOverlay> {
  RhmAward? _currentAward;
  UniqueKey _key = UniqueKey();
  Timer? _hideTimer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = rhmAnimationService.onPointsAwarded.listen((award) {
      setState(() {
        _currentAward = award;
        _key = UniqueKey();
      });

      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _currentAward = null;
            _key = UniqueKey();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, -1.0),
                  end: Offset.zero,
                ).animate(animation);

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _currentAward == null
                  ? const SizedBox.shrink()
                  : _buildAwardToast(context, _currentAward!),
            ),
          ),
        ),
      ],
    );
  }

  // This widget builds the redesigned toast
  Widget _buildAwardToast(BuildContext context, RhmAward award) {
    final theme = Theme.of(context);
    // Using the secondary color from your theme for a different feel.
    final backgroundColor = theme.colorScheme.secondary.withOpacity(0.95);
    final textColor = Colors.white;

    return Container(
      key: _key,
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50), // Pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Points Text (smaller font)
          Text(
            '+${award.points} Points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 8),
          // Reason Text (flexible and smaller)
          Flexible(
            child: Text(
              award.reason,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: textColor.withOpacity(0.9),
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
