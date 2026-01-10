// lib/features/chat/widgets/enhanced_message_bubble.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import '../models/message_model.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:feelings/features/chat/widgets/voice_message_bubble.dart';
import 'package:provider/provider.dart'; 
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/features/encryption/widgets/encryption_status_bubble.dart'; 

class EnhancedMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isReplyingToOwnMessage;
  final VoidCallback? onLongPress;
  final String highlightQuery;
  final bool showDateHeader;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isReplyingToOwnMessage,
    this.onLongPress,
    this.highlightQuery = '',
    this.showDateHeader = false,
  });

  String _getProxiedUrl(String imageId, {bool highQuality = false}) {
    // ✨ FIX: Support direct URLs (e.g. Cloudinary) by not wrapping them in Google Drive logic
    final String urlToProxy = imageId.startsWith('http') 
        ? imageId 
        : "https://drive.google.com/uc?export=view&id=$imageId";
        
    final size = highQuality ? "w=1200" : "w=600&h=600";
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(urlToProxy)}&$size&fit=cover";
  }

  /// Builds the widget to display the chat image
  Widget _buildImageView(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUploading = message.uploadStatus == 'uploading';
    final bool isFailed = message.uploadStatus == 'failed';
    // ✨ THIS IS THE FIX ✨
    // We check if a localImagePath exists AND the file is still there.
    // Your ChatProvider logic ensures this path is preserved for the sender.
    final bool hasLocalPath = message.localImagePath != null &&
        File(message.localImagePath!).existsSync();

    Widget imageWidget;

    // 1. SENDER'S PATH (Uploading, Failed, or Success with local path)
    if (hasLocalPath) {
      imageWidget = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(message.localImagePath!),
            fit: BoxFit.cover,
          ),
          if (isUploading)
            Center(
              child: PulsingDotsIndicator(
                size: 40,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.6)
                ],
              ),
            ),
          if (isFailed)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.error, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Failed',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    // 2. RECIPIENT'S PATH (or sender after restart)
    else if (message.googleDriveImageId != null) {
      imageWidget = FutureBuilder<File?>(
        future: LocalStorageHelper.getLocalImage(message.googleDriveImageId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null &&
              snapshot.data!.existsSync()) {
            return Image.file(snapshot.data!, fit: BoxFit.cover);
          }
          
          // ✨ THE FIX IS HERE ✨
          // We now request the highQuality version for the thumbnail.
          return CachedNetworkImage(
            imageUrl: _getProxiedUrl(message.googleDriveImageId!, highQuality: true), // <--- CHANGED TO TRUE
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.download_for_offline_outlined,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  size: 40,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                // ... (error widget)
              ),
            ),
          );
        },
      );
    } 
    // 3. FALLBACK
    else {
      imageWidget = Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.70,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: imageWidget,
        ),
      ),
    );
  }

  void _showImageGallery(BuildContext context) {
    if (message.uploadStatus == 'uploading' ||
        message.uploadStatus == 'failed') {
      return;
    }
    ImageProvider? imageProvider;
    if (message.localImagePath != null &&
        File(message.localImagePath!).existsSync()) {
      imageProvider = FileImage(File(message.localImagePath!));
    } else if (message.googleDriveImageId != null) {
      imageProvider = CachedNetworkImageProvider(
        _getProxiedUrl(message.googleDriveImageId!, highQuality: true),
      );
    } else {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: imageProvider,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                heroAttributes: PhotoViewHeroAttributes(tag: message.id),
              );
            },
            itemCount: 1,
            loadingBuilder: (context, event) => Center(
              child: PulsingDotsIndicator(
                size: 40,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.6)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isImageMessage = message.messageType == 'image';
    final bool isVoiceMessage = message.messageType == 'voice';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply content with conditional padding
                          if (isImageMessage || isVoiceMessage)
                            _buildReplyContent(context, theme, isImageMessage, isVoiceMessage)
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(13, 9, 13, 0),
                              child: _buildReplyContent(context, theme, isImageMessage, isVoiceMessage),
                            ),
                          if (isImageMessage)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: GestureDetector(
                                onTap: () => _showImageGallery(context),
                                child: Hero(
                                  tag: message.id,
                                  child: _buildImageView(context),
                                ),
                              ),
                            ),

                            if (isVoiceMessage)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: VoiceMessageBubble(
                                message: message,
                                isMe: isMe,
                                // ✨ CONNECT DECRYPTION LOGIC
                                onPrepareAudio: (msg) => 
                                Provider.of<ChatProvider>(context, listen: false)
                                .prepareAudioFile(msg),
                              ),
                            ),
                          if (!isImageMessage && !isVoiceMessage && message.content.isNotEmpty)
                            IntrinsicWidth(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Message text
                                    _buildMessageTextOrHighlight(
                                        context, message.content, highlightQuery, theme),
                                    const SizedBox(height: 3),
                                    // Timestamp row - aligned right
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (message.editedAt != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Text(
                                              'edited',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: isMe
                                                    ? theme.colorScheme.onPrimary.withOpacity(0.6)
                                                    : theme.colorScheme.onSurface.withOpacity(0.5),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          _formatTime(message.timestamp.toLocal()),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: isMe
                                                ? theme.colorScheme.onPrimary.withOpacity(0.6)
                                                : theme.colorScheme.onSurface.withOpacity(0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                        // ✨ Lock Icon for Encrypted Messages
                                        if (message.encryptionVersion == 1) ...[
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.lock,
                                            size: 10,
                                            color: isMe
                                                ? theme.colorScheme.onPrimary.withOpacity(0.6)
                                                : theme.colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ],
                                        if (isMe) ...[
                                          const SizedBox(width: 3),
                                          _buildMessageStatus(context, message.status, theme),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isImageMessage)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildImageOverlay(context, theme),
                      ),

                      if (isVoiceMessage) ...[
                        Builder(builder: (context) {
                          // Debug print
                          if (message.audioEncryptionVersion == 1) debugPrint("🔒 [UI] Voice Message IS ENCRYPTED (v1)");
                          else debugPrint("🔓 [UI] Voice Message NOT encrypted (v=${message.audioEncryptionVersion})");
                          return const SizedBox.shrink();
                        }),
                      ],
                      if (isVoiceMessage)
                      Positioned(
                        bottom: 8,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             // ✨ Lock Icon for Encrypted Voice
                            if (message.encryptionVersion == 1 || (isVoiceMessage && message.audioEncryptionVersion == 1)) ...[
                              Icon(
                                Icons.lock,
                                size: 10,
                                color: isMe
                                    ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (message.editedAt != null) ...[
                              Text(
                                'edited',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isMe
                                      ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                      : theme.colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (isMe)
                              _buildMessageStatus(context, message.status, theme),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOverlay(BuildContext context, ThemeData theme) {
    if (message.uploadStatus == 'uploading' ||
        message.uploadStatus == 'failed') {
      return const SizedBox.shrink();
    }

    final bool hasCaption = message.content.isNotEmpty;

    if (hasCaption) {
      return Container(
        padding:
            const EdgeInsets.only(left: 10, right: 10, bottom: 8, top: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 1.0],
            colors: [
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.7),
            ],
          ),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(15.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageTextOrHighlight(
                context, message.content, highlightQuery, theme,
                forceColor: Colors.white),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // ✨ Lock Icon for Encrypted Images (Overlay)
                if (message.encryptionVersion == 1) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.lock,
                    size: 10,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ],
                if (message.editedAt != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'edited',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatus(context, message.status, theme,
                      onDarkBackground: true),
                ],
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        alignment: Alignment.bottomRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.timestamp.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // ✨ Lock Icon for Encrypted Images (No Caption)
              if (message.encryptionVersion == 1) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.lock,
                  size: 10,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
              if (message.editedAt != null) ...[
                const SizedBox(width: 6),
                Text(
                  'edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildMessageStatus(context, message.status, theme,
                    onDarkBackground: true),
              ],
            ],
          ),
        ),
      );
    }
  }

  Future<void> _openLink(LinkableElement link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;
    final mode = LaunchMode.externalApplication;
    await launchUrl(uri, mode: mode);
  }

  // ✨ Helper to get proxied URL (for the reply thumbnail)
  String _getReplyProxiedUrl(String imageId) {
    // ✨ FIX: Support direct URLs
    final String urlToProxy = imageId.startsWith('http') 
        ? imageId 
        : "https://drive.google.com/uc?export=view&id=$imageId";
        
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(urlToProxy)}&w=100&h=100&fit=cover";
  }

  Widget _buildReplyContent(BuildContext context, ThemeData theme, bool isImageMessage, bool isVoiceMessage) {
    // ✨ Check for the new reply type fields
    if (message.repliedToMessageId == null) {
      return const SizedBox.shrink();
    }
    
    // ✨ Only apply padding for image/voice messages (text messages get padding from outer wrapper)
    final EdgeInsets? contentPadding = (isImageMessage || isVoiceMessage)
        ? const EdgeInsets.fromLTRB(8, 8, 8, 0)
        : null;
    
    final bool isImageReply = message.repliedToMessageType == 'image';
    // ✨ Safely handle replyText. Use caption, or "Image", or empty string.
    final String replyText = isImageReply
        ? (message.repliedToMessageContent == null || message.repliedToMessageContent!.isEmpty ? "Image" : message.repliedToMessageContent!)
        : (message.repliedToMessageContent ?? "");

    // ... (your existing color logic)
    final Color backgroundColor;
    final Color borderColor;
    final Color senderColor;
    final Color contentColor;
    if (isMe) {
      if (isReplyingToOwnMessage) {
        backgroundColor = theme.colorScheme.onPrimary.withOpacity(0.15);
        borderColor = theme.colorScheme.onPrimary;
        senderColor = theme.colorScheme.onPrimary;
        contentColor = theme.colorScheme.onPrimary.withOpacity(0.9);
      } else {
        backgroundColor = theme.colorScheme.onPrimary.withOpacity(0.08);
        borderColor = theme.colorScheme.onPrimary.withOpacity(0.6);
        senderColor = theme.colorScheme.onPrimary;
        contentColor = theme.colorScheme.onPrimary.withOpacity(0.9);
      }
    } else {
      if (isReplyingToOwnMessage) {
        backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
        borderColor = theme.colorScheme.primary;
        senderColor = theme.colorScheme.primary;
        contentColor = theme.colorScheme.onSurface;
      } else {
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        borderColor = theme.colorScheme.outline.withOpacity(0.5);
        senderColor = theme.colorScheme.onSurface.withOpacity(0.7);
        contentColor = theme.colorScheme.onSurface.withOpacity(0.8);
      }
    }
    // ... (end of color logic)

    final replyContainer = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
        ),
      ),
      child: Row( // ✨ Wrap in a Row
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // ✨ Use repliedToSenderName from model
                  message.repliedToSenderName ?? 'Message',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: senderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyText, // ✨ Use new replyText
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: contentColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // ✨ Show image thumbnail using the new local-first logic
          if (isImageReply && message.repliedToImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: _ReplyImageThumbnail(
                imageId: message.repliedToImageUrl!,
                proxiedUrl: _getReplyProxiedUrl(message.repliedToImageUrl!),
              ),
            ),
        ],
      ),
    );
    
    // Only wrap with padding for image/voice messages
    if (contentPadding != null) {
      return Padding(
        padding: contentPadding,
        child: replyContainer,
      );
    }
    
    return replyContainer;
  }

  Widget _buildMessageTextOrHighlight(
    BuildContext context,
    String text,
    String query,
    ThemeData theme, {
    Color? forceColor,
  }) {
    // ✨ CHECK FOR ENCRYPTION STATUS
    if (text == "⏳ Waiting for key...") {
      return EncryptionStatusBubble(status: 'waiting', isMe: isMe);
    } else if (text == "🔒 Decryption Failed") {
      return EncryptionStatusBubble(status: 'failed', isMe: isMe);
    } else if (text == "🔒 Encrypted Message") {
      return EncryptionStatusBubble(status: 'locked', isMe: isMe);
    }

    final Color mainColor =
        forceColor ?? (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface);
    final Color linkColor =
        forceColor ?? (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary);

    if (query.isEmpty) {
      return SelectableLinkify(
        text: text,
        onOpen: _openLink,
        options: const LinkifyOptions(humanize: false, removeWww: false),
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: mainColor, fontSize: 15, height: 1.3),
        linkStyle: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
            decorationThickness: 2,
            fontWeight: FontWeight.w600),
        maxLines: null,
        textAlign: TextAlign.start,
      );
    }
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int lastMatchEnd = 0;
    int index = lowerText.indexOf(lowerQuery);
    while (index != -1) {
      if (index > lastMatchEnd) {
        spans.add(TextSpan(
            text: text.substring(lastMatchEnd, index),
            style: TextStyle(color: mainColor)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.08)),
        ),
      );
      lastMatchEnd = index + lowerQuery.length;
      index = lowerText.indexOf(lowerQuery, lastMatchEnd);
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(color: mainColor)));
    }
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: mainColor, fontSize: 15, height: 1.3),
        children: spans,
      ),
    );
  }

  Widget _buildMessageStatus(
    BuildContext context,
    String status,
    ThemeData theme, {
    bool onDarkBackground = false,
  }) {
    IconData icon;
    Color color;
    String tooltip;

    final fadedColor = onDarkBackground
        ? Colors.white.withOpacity(0.9)
        : (isMe
            ? theme.colorScheme.onPrimary.withOpacity(0.7)
            : theme.colorScheme.onSurface.withOpacity(0.7));

    switch (status.toLowerCase()) {
      case 'seen':
        icon = Icons.done_all; // Two ticks
        color = onDarkBackground ? Colors.blue.shade200 : (isMe ? Colors.blue.shade200 : theme.colorScheme.primary);
        tooltip = 'Seen';
        break;
      
      case 'sent':
        icon = Icons.done; // One tick
        color = fadedColor;
        tooltip = 'Sent';
        break;

      case 'unsent':
        icon = Icons.schedule; // Clock icon
        color = fadedColor;
        tooltip = 'Sending...';
        break;

      case 'failed':
        icon = Icons.error_outline; // Error icon
        color = onDarkBackground ? theme.colorScheme.error.withOpacity(0.8) : theme.colorScheme.error;
        tooltip = 'Failed to send';
        break;

      default:
        icon = Icons.done; // Fallback
        color = fadedColor;
        tooltip = 'Sent';
    }

    return Tooltip(message: tooltip, child: Icon(icon, size: 16, color: color));
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
}

// ✨ NEW HELPER WIDGET ✨
/// A helper widget to display the reply thumbnail.
/// It prioritizes loading the local file and falls back to CachedNetworkImage.
class _ReplyImageThumbnail extends StatelessWidget {
  final String imageId;
  final String proxiedUrl;

  const _ReplyImageThumbnail({required this.imageId, required this.proxiedUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: LocalStorageHelper.getLocalImage(imageId),
      builder: (context, snapshot) {
        // 1. If we have the local file, use it
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null &&
            snapshot.data!.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              snapshot.data!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          );
        }

        // 2. If we don't, or are still checking, use the cached network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: proxiedUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            // Optional: A small placeholder while this itself loads
            placeholder: (context, url) => Container(
              width: 40,
              height: 40,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (context, url, error) => Container(
              width: 40,
              height: 40,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}