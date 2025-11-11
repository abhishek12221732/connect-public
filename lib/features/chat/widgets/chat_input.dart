import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  const ChatInput({
    super.key,
    required this.messageController,
    required this.onSend,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
