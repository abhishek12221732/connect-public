// lib/features/secret_note/widgets/secret_note_icon.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'secret_note_view_dialog.dart'; // We will create this next

class SecretNoteIcon extends StatefulWidget {
  final MessageModel note;

  const SecretNoteIcon({
    super.key,
    required this.note,
  });

  @override
  State<SecretNoteIcon> createState() => _SecretNoteIconState();
}

class _SecretNoteIconState extends State<SecretNoteIcon>
    with SingleTickerProviderStateMixin {
  late Alignment _alignment;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // A list of safe alignments to prevent overlapping with UI elements
  static const List<Alignment> _safeAlignments = [
    Alignment(-0.8, -0.8), // Top-left
    Alignment(0.8, -0.8), // Top-right
    Alignment(0.0, -0.6), // Top-center
    Alignment(-0.8, 0.8), // Bottom-left
    Alignment(0.8, 0.8), // Bottom-right
    Alignment(0.0, 0.6), // Bottom-center
    Alignment(-0.7, 0.0), // Mid-left
    Alignment(0.7, 0.0), // Mid-right
  ];

  @override
  void initState() {
    super.initState();

    // 1. Generate a random alignment
    _alignment = _safeAlignments[Random().nextInt(_safeAlignments.length)];

    // 2. Set up the animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // A fun, bouncy "pop"
    );

    // 3. Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows the dialog and marks the note as read
  void _showNote(BuildContext context) {
    // 1. Mark the note as read
    // We use listen: false because we are in a function
    Provider.of<SecretNoteProvider>(context, listen: false)
        .markNoteAsRead(widget.note.id);

    // 2. Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User must press "Close"
      builder: (dialogContext) {
        return SecretNoteViewDialog(
          note: widget.note,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () => _showNote(context),
          child: Tooltip(
            message: "A secret note... 💌",
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded, // A "gift" icon
                      size: 30,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                         padding: const EdgeInsets.all(1),
                         decoration: BoxDecoration(
                           color: Theme.of(context).colorScheme.surface,
                           shape: BoxShape.circle,
                         ),
                         child: Icon(
                          Icons.lock,
                          size: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
            ),
          ),
        ),
      ),
    );
  }
}