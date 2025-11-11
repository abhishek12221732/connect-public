import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final String highlightQuery;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.highlightQuery = '',
  });

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);

    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();
    int startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text);
    }

    spans.add(TextSpan(text: text.substring(0, startIndex)));
    spans.add(TextSpan(
      text: text.substring(startIndex, startIndex + query.length),
      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
    ));
    spans.add(TextSpan(text: text.substring(startIndex + query.length)));

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: spans,
      ),
    );
  }

  Widget _buildMessageStatus(String status) {
    IconData icon;
    Color color;
    switch (status.toLowerCase()) {
      case 'seen':
        icon = Icons.done_all;
        color = Colors.lightGreenAccent;
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      default:
        icon = Icons.done;
        color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final time = message.timestamp.toLocal();
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.blueAccent : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight:
                      isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlightedText(message.content, highlightQuery),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        _buildMessageStatus(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
