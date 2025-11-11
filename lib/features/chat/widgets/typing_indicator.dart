import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/chat_provider.dart';

class TypingIndicatorWidget extends StatelessWidget {
  const TypingIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (!chatProvider.isPartnerTyping) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            children: const [
              Text('Partner is typing...'),
            ],
          ),
        );
      },
    );
  }
}
