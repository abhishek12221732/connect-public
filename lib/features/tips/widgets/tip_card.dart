// lib/features/tips/widgets/tip_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tip_model.dart';
import '../../../providers/tips_provider.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
// ✨ --- END NEW IMPORTS --- ✨

class TipCard extends StatelessWidget {
  final String? title;
  final TipModel? tip;
  final bool isLoading;
  final String? partnerName;
  final String? partnerLoveLanguage;
  final ImageProvider? partnerProfileImage;

  // ✨ --- NEW PARAMETERS --- ✨
  final bool hasSecretNote;
  final VoidCallback? onSecretNoteTap;
  // ✨ --- END NEW --- ✨

  const TipCard({
    super.key,
    this.title,
    this.tip,
    this.isLoading = false,
    this.partnerName,
    this.partnerLoveLanguage,
    this.partnerProfileImage,
    // ✨ --- ADD TO CONSTRUCTOR --- ✨
    this.hasSecretNote = false,
    this.onSecretNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The main card content.
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        // ✨ --- MODIFIED --- ✨
        // If there's a footer, only round the top. Otherwise, round all corners.
        borderRadius: (partnerLoveLanguage != null && partnerLoveLanguage!.isNotEmpty)
            ? const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              )
            : BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(Icons.lightbulb_outline, color: colorScheme.secondary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                _buildContent(context),
              ],
            ),
          ),
          // ✨ --- MODIFIED: Use a spacer to reserve room for the bookmark --- ✨
          const SizedBox(width: 30),
        ],
      ),
    );

    // The Love Language Footer (unchanged)
    Widget footer = (partnerLoveLanguage != null && partnerLoveLanguage!.isNotEmpty)
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            // ... (footer content is unchanged) ...
             children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.onPrimary.withOpacity(0.1),
                  backgroundImage: partnerProfileImage,
                  child: partnerProfileImage == null
                      ? Icon(
                          Icons.person,
                          size: 18,
                          color: colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                      children: [
                        const TextSpan(text: 'Remember, '),
                        TextSpan(
                          text: partnerName ?? 'your partner',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' appreciates '),
                        TextSpan(
                          text: partnerLoveLanguage!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '. Try to keep this in mind!'),
                      ],
                    ),
                  ),
                ),
              ],
          ),
        )
      : const SizedBox.shrink();

    // ✨ --- NEW: STACK & BOOKMARK LOGIC --- ✨
    return Stack(
      children: [
        // The main content (Card + Footer)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            cardContent,
            footer,
          ],
        ),
        
        // The Bookmark/Gift Icon
        if (hasSecretNote)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onSecretNoteTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(-2, 2),
                    )
                  ],
                ),
                child: Icon(
                  Icons.mail_lock_rounded, 
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
    // ✨ --- END NEW --- ✨
  }

  Widget _buildContent(BuildContext context) {
    // ... (This function is unchanged) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (tip == null) {
      return Text(
        "Your tip for the day will appear here.",
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        tip!.content,
        key: ValueKey(tip!.id),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface,
          height: 1.3,
        ),
      ),
    );
  }
}

class DynamicTipCard extends StatelessWidget {
  final String? title;
  final String? partnerName;
  final String? partnerLoveLanguage;
  final ImageProvider? partnerProfileImage;

  const DynamicTipCard({
    super.key,
    this.title,
    this.partnerName,
    this.partnerLoveLanguage,
    this.partnerProfileImage,
  });

  // ✨ --- NEW HELPER METHOD --- ✨
  void _openSecretNote(BuildContext context, SecretNoteProvider provider) {
    final note = provider.activeSecretNote;
    if (note == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SecretNoteViewDialog(note: note),
    );
    provider.markNoteAsRead(note.id);
  }

  @override
  Widget build(BuildContext context) {
    // ✨ --- WATCH BOTH PROVIDERS --- ✨
    return Consumer2<TipsProvider, SecretNoteProvider>(
      builder: (context, tipsProvider, secretNoteProvider, child) {
        
        final bool hasSecretNote = 
            secretNoteProvider.activeNoteLocation == SecretNoteLocation.tipCard &&
            secretNoteProvider.activeSecretNote != null;
        
        final currentTip = tipsProvider.currentTip;

        if (tipsProvider.userId == null || tipsProvider.isLoading) {
          return TipCard(
            title: title,
            tip: null,
            isLoading: true,
            partnerName: partnerName,
            partnerLoveLanguage: partnerLoveLanguage,
            partnerProfileImage: partnerProfileImage,
            hasSecretNote: hasSecretNote, // Pass it down
            onSecretNoteTap: () => _openSecretNote(context, secretNoteProvider), // Pass the action
          );
        }

        return TipCard(
          title: title,
          tip: currentTip,
          isLoading: tipsProvider.isLoading,
          partnerName: partnerName,
          partnerLoveLanguage: partnerLoveLanguage,
          partnerProfileImage: partnerProfileImage,
          
          // ✨ --- NEW: Pass state and logic down --- ✨
          hasSecretNote: hasSecretNote,
          onSecretNoteTap: () => _openSecretNote(context, secretNoteProvider),
        );
      },
    );
  }
}