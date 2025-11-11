// lib/features/discover/widgets/send_secret_note_card.dart

import 'package:flutter/material.dart';
import 'package:feelings/features/secret_note/screens/secret_note_composer_screen.dart'; // We will create this next

// Enum to tell the composer screen what to open
enum NoteType { text, image, voice }

class SendSecretNoteCard extends StatelessWidget {
  const SendSecretNoteCard({super.key});

  // This function handles showing the new modal composer screen
  void _showComposer(BuildContext context, NoteType noteType) {
    Navigator.of(context).push(
      // Use a custom PageRouteBuilder for a 'modal' slide-up animation
      PageRouteBuilder(
        // Make the page see-through
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.5),
        // The screen we are navigating to
        pageBuilder: (context, animation, secondaryAnimation) {
          return SecretNoteComposerScreen(noteType: noteType);
        },
        // The slide-up transition
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      // Add a subtle gradient or visual flair
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainer.withOpacity(0.5),
            ],
            stops: const [0.3, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Title ---
              Row(
                children: [
                  Icon(Icons.mail_lock_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Send a Secret Note",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "A surprise message for your partner!",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // --- Action Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NoteTypeButton(
                    icon: Icons.text_fields_rounded,
                    label: "Text",
                    onTap: () => _showComposer(context, NoteType.text),
                  ),
                  _NoteTypeButton(
                    icon: Icons.image_rounded,
                    label: "Image",
                    onTap: () => _showComposer(context, NoteType.image),
                  ),
                  _NoteTypeButton(
                    icon: Icons.mic_rounded,
                    label: "Voice",
                    onTap: () => _showComposer(context, NoteType.voice),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- A private helper widget for the buttons ---
class _NoteTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NoteTypeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: colorScheme.primary, size: 28),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}