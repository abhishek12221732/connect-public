// lib/features/secret_note/widgets/secret_note_view_dialog.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// Import the VoiceMessageBubble from your project
import 'package:feelings/features/chat/widgets/voice_message_bubble.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/features/encryption/widgets/encryption_status_bubble.dart'; // Add this
import 'package:provider/provider.dart'; // Add this
import 'package:feelings/providers/secret_note_provider.dart'; // Add this

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
    final proxyUrl = "https://images.weserv.nl/?url=${Uri.encodeComponent(googleUrl)}&w=1200&fit=cover";
    debugPrint("[SecretNotes] Proxy URL: $proxyUrl");
    return proxyUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✨ Make Dialog Reactive
    return Consumer<SecretNoteProvider>(
      builder: (context, provider, child) {
        // Use the fresh active note if it matches the one we opened.
        // If not found in provider (e.g. cleared), fall back to the initial 'note'.
        final freshNote = (provider.activeSecretNote?.id == note.id) 
            ? provider.activeSecretNote! 
            : note; 

        // Re-bind the helper to use freshNote
        Widget buildContent = _buildContent(context, freshNote);

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
            child: buildContent,
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
      },
    );
  }

  // ✨ Helper to pass fresh note
  Widget _buildContent(BuildContext context, MessageModel currentNote) {
    final theme = Theme.of(context);

    switch (currentNote.messageType) {
      case 'image':
        final imageUrl = currentNote.googleDriveImageId != null
            ? _getProxiedUrl(currentNote.googleDriveImageId!)
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
            if (currentNote.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4),
                child: SelectableText(
                  currentNote.content,
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: VoiceMessageBubble(
                message: currentNote,
                isMe: false, 
                onPrepareAudio: (msg) => 
                  Provider.of<SecretNoteProvider>(context, listen: false)
                    .prepareAudioFile(msg),
              ),
            ),
            if (currentNote.content.isNotEmpty) 
              const SizedBox.shrink(),
          ],
        );

      case 'text':
      default:
        if (currentNote.content == "⏳ Waiting for key...") {
           return const Center(child: EncryptionStatusBubble(status: 'waiting'));
        } else if (currentNote.content == "🔒 Decryption Failed") {
           return const Center(child: EncryptionStatusBubble(status: 'failed'));
        } else if (currentNote.content == "🔒 Encrypted Note") {
           return const Center(child: EncryptionStatusBubble(status: 'locked'));
        }

        return SelectableText(
          currentNote.content,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        );
    }
  }
}