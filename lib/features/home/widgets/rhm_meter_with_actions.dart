// lib/features/home/widgets/rhm_meter_with_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
// ✨ --- END NEW IMPORTS --- ✨

class RhmMeterWithActions extends StatefulWidget {
  final int score;
  final VoidCallback onTap;

  const RhmMeterWithActions({
    super.key,
    required this.score,
    required this.onTap,
  });

  @override
  State<RhmMeterWithActions> createState() => _RhmMeterWithActionsState();
}

class _RhmMeterWithActionsState extends State<RhmMeterWithActions> {
  bool _isActionsExpanded = false;
  final GlobalKey _buttonKey = GlobalKey();
  double _buttonWidth = 95.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureButton());
  }

  void _measureButton() {
    final context = _buttonKey.currentContext;
    if (context != null) {
      final size = context.size;
      if (size != null && size.width != _buttonWidth && size.width > 0) {
        setState(() {
          _buttonWidth = size.width;
        });
      }
    }
  }

  ({String status, Color color}) _getStatus(int score) {
    if (score >= 85) {
      return (status: 'Thriving', color: Colors.green);
    } else if (score >= 65) {
      return (status: 'Connected', color: Colors.blue);
    } else if (score >= 40) {
      return (status: 'Steady', color: Colors.yellow[700] ?? Colors.yellow);
    } else if (score >= 20) {
      return (status: 'Needs Nurturing', color: Colors.orange);
    } else {
      return (status: 'Needs Care', color: Colors.red);
    }
  }

  // ✨ --- NEW HELPER METHOD --- ✨
  void _openSecretNote(BuildContext context, SecretNoteProvider provider) {
    final note = provider.activeSecretNote;
    if (note == null) return;

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SecretNoteViewDialog(note: note),
    );
    // Mark the note as read
    provider.markNoteAsRead(note.id);
  }

  @override
  Widget build(BuildContext context) {
    // ✨ --- NEW: WATCH THE PROVIDER --- ✨
    // We use `watch` here so the actions tray rebuilds when a note appears
    final secretNoteProvider = context.watch<SecretNoteProvider>();
    final bool hasSecretNoteAction =
        secretNoteProvider.activeNoteLocation == SecretNoteLocation.rhmMeter;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMeterCard(context),
          // ✨ --- PASS DATA TO THE TRAY --- ✨
          _buildActionsTray(context, hasSecretNoteAction, secretNoteProvider),
        ],
      ),
    );
  }

  Widget _buildMeterCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusInfo = _getStatus(widget.score);
    final double progress = widget.score / 100.0;

    return Stack(
      clipBehavior: Clip.none, 
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipPath(
            clipper: BottomRightNotchClipper(buttonWidth: _buttonWidth),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Row(
                    children: [
                      // Dial
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(
                                statusInfo.color.withOpacity(0.2),
                              ),
                            ),
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(statusInfo.color),
                              strokeCap: StrokeCap.round,
                            ),
                            Center(
                              child: Text(
                                '${widget.score}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: statusInfo.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Relationship Health',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${statusInfo.status}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: statusInfo.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to see details & boost score.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Overhanging button
        Positioned(
          bottom: 0,
          right: 20,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.primary,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _isActionsExpanded = !_isActionsExpanded),
              child: Container(
                key: _buttonKey,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _isActionsExpanded ? Icons.close : Icons.favorite,
                        key: ValueKey(_isActionsExpanded),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Actions',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✨ --- WIDGET SIGNATURE UPDATED --- ✨
  Widget _buildActionsTray(
    BuildContext context, 
    bool hasSecretNoteAction,
    SecretNoteProvider secretNoteProvider,
  ) {
    final theme = Theme.of(context);
    final actionsProvider = context.watch<DynamicActionsProvider>();
    final suggestedActions = actionsProvider.getDynamicActions();

    // ✨ --- NEW: Create the Secret Note Action Widget --- ✨
    final Widget secretNoteWidget = _buildShortcutIcon(
      context,
      icon: Icons.card_giftcard_rounded, // The gift icon
      label: "Open Note",
      onPressed: () => _openSecretNote(context, secretNoteProvider),
    );
    // ✨ --- END NEW --- ✨

    return IgnorePointer(
      ignoring: !_isActionsExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: _isActionsExpanded ? 85.0 : 16.0,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          // ✨ --- NEW: Conditional Logic --- ✨
          child: hasSecretNoteAction
              // --- IF NOTE EXISTS: Show only the note button ---
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isActionsExpanded ? 1.0 : 0.0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        offset: _isActionsExpanded ? Offset.zero : const Offset(0.0, 1.5),
                        child: secretNoteWidget,
                      ),
                    ),
                  ],
                )
              // --- IF NO NOTE: Show normal actions ---
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(suggestedActions.length, (index) {
                    final action = suggestedActions[index];
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isActionsExpanded ? 1.0 : 0.0,
                      child: AnimatedSlide(
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        curve: Curves.easeOutCubic,
                        offset: _isActionsExpanded ? Offset.zero : const Offset(0.0, 1.5),
                        child: _buildShortcutIcon(
                          context,
                          icon: action.icon,
                          label: action.label,
                          onPressed: () => action.actionBuilder(context)(),
                        ),
                      ),
                    );
                  }),
                ),
          // ✨ --- END NEW --- ✨
        ),
      ),
    );
  }

  Widget _buildShortcutIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

// --- CUSTOM CLIPPER (unchanged visual logic) ---
class BottomRightNotchClipper extends CustomClipper<Path> {
  final double buttonWidth;

  BottomRightNotchClipper({required this.buttonWidth});

  @override
  Path getClip(Size size) {
    const double btnRightMargin = 20.0;
    const double btnBottomOverhang = 16.0; // visual overhang amount
    final double btnWidth = buttonWidth;
    const double btnHeight = 36.0;
    const double btnRadius = 20.0;
    const double cardRadius = 20.0;
    const double cutoutPadding = 3.0;

    final double buttonTop = size.height - (btnHeight - btnBottomOverhang);
    final double buttonLeft = size.width - btnRightMargin - btnWidth;

    final double cutoutLeft = buttonLeft - cutoutPadding;
    final double cutoutTop = buttonTop - cutoutPadding;
    final double cutoutRight = (buttonLeft + btnWidth) + cutoutPadding;
    final double cutoutBottom = (buttonTop + btnHeight) + cutoutPadding;
    final double cutoutRadius = btnRadius + cutoutPadding;

    final path = Path();

    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(cardRadius),
    ));

    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
      Radius.circular(cutoutRadius),
    ));

    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant BottomRightNotchClipper oldClipper) {
    return oldClipper.buttonWidth != buttonWidth;
  }
}