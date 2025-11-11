import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class ChatEmptyState extends StatelessWidget {
  final VoidCallback? onStartChat;
  final String? customMessage;
  final String? partnerName;
  
  const ChatEmptyState({
    super.key,
    this.onStartChat,
    this.customMessage,
    this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppColors.textSecondary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: AppTextStyles.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            customMessage ?? 'Start your conversation with your partner',
            style: AppTextStyles.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onStartChat != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onStartChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Say hi to ${partnerName ?? 'your partner'} 👋',
                  style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 
