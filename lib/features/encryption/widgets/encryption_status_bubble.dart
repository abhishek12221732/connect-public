import 'package:flutter/material.dart';

class EncryptionStatusBubble extends StatelessWidget {
  final String status; // 'waiting', 'failed', 'locked'
  final bool isMe;

  const EncryptionStatusBubble({
    super.key,
    required this.status,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    IconData icon;
    String text;
    Color color;

    switch (status) {
      case 'waiting':
        icon = Icons.hourglass_empty_rounded;
        text = "Waiting for key...";
        color = theme.colorScheme.onSurface.withOpacity(0.6);
        break;
      case 'failed':
        icon = Icons.error_outline_rounded;
        text = "Decryption Failed";
        color = theme.colorScheme.error;
        break;
      case 'locked':
      default:
        icon = Icons.lock_outline_rounded;
        text = "Encrypted Message";
        color = theme.colorScheme.onSurface.withOpacity(0.6);
        break;
    }

    // Adapt colors if it's "my" message (though usually my messages are decrypted locally)
    if (isMe && status != 'failed') {
       color = theme.colorScheme.onPrimary.withOpacity(0.8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe 
            ? theme.colorScheme.primary.withOpacity(0.1) 
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
