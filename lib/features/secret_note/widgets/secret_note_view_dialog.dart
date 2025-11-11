// lib/features/secret_note/widgets/secret_note_view_dialog.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// Import the VoiceMessageBubble from your project
import 'package:feelings/features/chat/widgets/voice_message_bubble.dart';

class SecretNoteViewDialog extends StatelessWidget {
  final MessageModel note;

  const SecretNoteViewDialog({
    super.key,
    required this.note,
  });

  /// This is the same helper from your enhanced_message_bubble.dart
  /// It gets a high-quality, proxied URL for a Google Drive image.
  String _getProxiedUrl(String imageId) {
    final googleUrl = "https://drive.google.com/uc?export=view&id=$imageId";
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(googleUrl)}&w=1200&fit=cover";
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    switch (note.messageType) {
      case 'image':
        final imageUrl = note.googleDriveImageId != null
            ? _getProxiedUrl(note.googleDriveImageId!)
            : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => AspectRatio(
                    aspectRatio: 1,
                    child: Center(
                      child: PulsingDotsIndicator(
                        size: 40,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => AspectRatio(
                    aspectRatio: 1,
                    child: Icon(Icons.broken_image,
                        color: theme.colorScheme.error),
                  ),
                ),
              ),
            if (note.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4),
                child: SelectableText(
                  note.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );

      case 'voice':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // We re-use your existing VoiceMessageBubble.
            // We wrap it to give it a background and style.
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: VoiceMessageBubble(
                message: note,
                isMe: false, // Always show as "received"
              ),
            ),
            if (note.content.isNotEmpty) // This field is unused for audio
              const SizedBox.shrink(),
          ],
        );

      case 'text':
      default:
        return SelectableText(
          note.content,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.mail_lock_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            "A Secret Note!",
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "Close",
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}