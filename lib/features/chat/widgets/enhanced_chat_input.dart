// lib/features/chat/widgets/enhanced_chat_input.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter/services.dart'; // No longer needed
import 'dart:async';

class EnhancedChatInput extends StatefulWidget {
  final TextEditingController messageController;
  final Function(String text, File? image) onSend; // Correct signature
  final ValueChanged<String>? onChanged;
  final bool isLoading;
  final MessageModel? replyingToMessage;
  final VoidCallback? onCancelReply;
  final MessageModel? editingMessage;
  final VoidCallback? onCancelEdit;
  final ValueChanged<String>? onConfirmEdit;
  final Function(File audioFile) onSendVoice;
  
  final String currentUserId;
  final String partnerName;

  const EnhancedChatInput({
    super.key,
    required this.messageController,
    required this.onSend,
    this.onChanged,
    this.isLoading = false,
    this.replyingToMessage,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onConfirmEdit,
    required this.currentUserId,
    required this.partnerName,
    required this.onSendVoice,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput>
    with TickerProviderStateMixin {
  
  late AnimationController _sendButtonAnimationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _imagePreviewFadeController;
  late Animation<double> _imagePreviewFadeAnimation;
  
  bool _hasText = false;
  File? _selectedImage;
  
  // --- RECORDER STATE ---
  bool _isRecording = false;
  late final AudioRecorder _audioRecorder;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  bool _hasRecordedFile = false;

  // --- UI/UX STATE ---
  late AnimationController _recordingBlinkController;

  @override
  void initState() {
    super.initState();

    _audioRecorder = AudioRecorder();
    
    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
          parent: _sendButtonAnimationController, curve: Curves.easeInOut),
    );

    _imagePreviewFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _imagePreviewFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imagePreviewFadeController, curve: Curves.easeIn),
    );

    _recordingBlinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _hasText = widget.messageController.text.isNotEmpty;
    _checkAnimateButtonState(); 
    widget.messageController.addListener(_checkAnimateButtonState);
  }

  void _checkAnimateButtonState() {
    if (!mounted) return;
    
    final bool hasText = widget.messageController.text.isNotEmpty;
    final bool hasImage = _selectedImage != null;
    final bool canSend = hasText || hasImage;

    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    if (canSend && _sendButtonAnimationController.status != AnimationStatus.completed) {
      _sendButtonAnimationController.forward();
    } else if (!canSend && _sendButtonAnimationController.status != AnimationStatus.dismissed) {
      _sendButtonAnimationController.reverse();
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        _checkAnimateButtonState(); 
        _imagePreviewFadeController.forward(); 
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _handleSend() {
    final text = widget.messageController.text.trim();
    final image = _selectedImage;
    if (text.isEmpty && image == null) return; 

    if (widget.editingMessage != null && widget.onConfirmEdit != null) {
      widget.onConfirmEdit!(text);
    } else {
      widget.onSend(text, image);
      setState(() {
        _selectedImage = null; 
      });
      _imagePreviewFadeController.reverse(); 
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _checkAnimateButtonState();
    });
  }

  void _handleSendVoice() {
    if (_recordingPath != null && _hasRecordedFile) {
      widget.onSendVoice(File(_recordingPath!));
    }
    _resetRecordingState();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint("Microphone permission denied");
      return;
    }

    final tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacHe,
          bitRate: 32000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
        _hasRecordedFile = false;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });

    } catch (e) {
      debugPrint("Error starting recording: $e");
      _resetRecordingState();
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;
    
    try {
      final path = await _audioRecorder.stop();
      if (_recordingDuration.inSeconds > 0 || _recordingDuration.inMilliseconds > 500) {
        setState(() {
          _isRecording = false;
          _hasRecordedFile = true;
          _recordingPath = path;
        });
      } else {
        _cancelRecording();
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      _resetRecordingState();
    }
  }

  void _cancelRecording() {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) {
        file.delete();
      }
    }
    _resetRecordingState();
  }

  void _resetRecordingState() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasRecordedFile = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _recordingTimer?.cancel(); 
    _sendButtonAnimationController.dispose();
    _imagePreviewFadeController.dispose();
    _recordingBlinkController.dispose();
    widget.messageController.removeListener(_checkAnimateButtonState);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildRecordingUI(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_hasRecordedFile)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: _cancelRecording,
              tooltip: 'Delete recording',
            )
          else
            FadeTransition(
              opacity: _recordingBlinkController,
              child: Icon(Icons.circle, color: colorScheme.error, size: 16),
            ),
          
          const SizedBox(width: 8),
          
          Text(
            _formatDuration(_recordingDuration),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          
          const Spacer(),
          
          if (_isRecording)
            IconButton(
              icon: Icon(Icons.stop_circle, color: colorScheme.primary, size: 30),
              onPressed: _stopRecording,
              tooltip: 'Stop recording',
            )
          else if (_hasRecordedFile)
            IconButton(
              icon: Icon(Icons.send_rounded, color: colorScheme.primary, size: 30),
              onPressed: _handleSendVoice,
              tooltip: 'Send voice message',
            )
        ],
      ),
    );
  }

  Widget _buildTextInputField(ColorScheme colorScheme) {
    return TextField(
      controller: widget.messageController,
      onChanged: widget.onChanged,
      maxLines: 5,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Type a message...',
        border: InputBorder.none,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    // ... (This function is unchanged)
    if (_selectedImage == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _imagePreviewFadeAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                    });
                    _checkAnimateButtonState();
                    _imagePreviewFadeController.reverse();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.scrim,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditingBanner() {
    // ... (This function is unchanged)
    if (widget.editingMessage == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing message',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCancelEdit,
            color: colorScheme.onSurface.withOpacity(0.6),
            tooltip: 'Cancel edit',
          ),
        ],
      ),
    );
  }

  String _getProxiedUrl(String imageId) {
    // ... (This function is unchanged)
    final googleUrl = "https://drive.google.com/uc?export=view&id=$imageId";
    return "https://images.weserv.nl/?url=${Uri.encodeComponent(googleUrl)}&w=100&h=100&fit=cover";
  }

  Widget _buildReplyPreview() {
    // ... (This function is unchanged)
    if (widget.replyingToMessage == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final message = widget.replyingToMessage!;

    final bool isImageReply = message.messageType == 'image';
    final String replyText = isImageReply 
      ? (message.content.isEmpty ? "Image" : message.content) 
      : message.content;
      
    final String originalSenderName = 
      message.senderId == widget.currentUserId 
        ? "You" 
        : widget.partnerName;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalSenderName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            _buildReplyThumbnail(message),
            
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onCancelReply,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyThumbnail(MessageModel message) {
    // ... (This function is unchanged)
    if (message.messageType != 'image' || message.googleDriveImageId == null) {
      return const SizedBox.shrink();
    }

    final String imageId = message.googleDriveImageId!;
    final String proxiedUrl = _getProxiedUrl(imageId);

    return FutureBuilder<File?>(
      future: LocalStorageHelper.getLocalImage(imageId),
      builder: (context, snapshot) {
        Widget thumbnail;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null &&
            snapshot.data!.existsSync()) {
          thumbnail = Image.file(
            snapshot.data!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          );
        } 
        else {
          thumbnail = CachedNetworkImage(
            imageUrl: proxiedUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
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
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumbnail,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool canSend = _hasText || _selectedImage != null;

    final List<Color> dotColors = canSend
        ? [
            colorScheme.onPrimary,
            colorScheme.onPrimary.withOpacity(0.8),
            colorScheme.onPrimary.withOpacity(0.6),
          ]
        : [
            colorScheme.onSurface.withOpacity(0.6),
            colorScheme.onSurface.withOpacity(0.4),
            colorScheme.onSurface.withOpacity(0.2),
          ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          _buildEditingBanner(),
          _buildReplyPreview(),
          _buildSelectedImagePreview(), 
          
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end, 
                children: [
                  if (widget.editingMessage == null && !_isRecording && !_hasRecordedFile)
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: colorScheme.primary,
                      ),
                      onPressed: widget.isLoading ? null : _pickImage,
                      tooltip: 'Attach image',
                    ),
                  if (widget.editingMessage == null && !_isRecording && !_hasRecordedFile)
                    const SizedBox(width: 8),
                  
                  Expanded(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: (_isRecording || _hasRecordedFile)
                            ? _buildRecordingUI(theme, colorScheme)
                            : _buildTextInputField(colorScheme),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ✨ --- THIS IS THE FIX --- ✨
                  // Only show the mic/send button if we are NOT in a recording state.
                  if (!_isRecording && !_hasRecordedFile)
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: (canSend || widget.editingMessage != null)
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              boxShadow: (canSend || widget.editingMessage != null)
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              icon: widget.isLoading
                                  ? PulsingDotsIndicator(
                                      size: 20,
                                      colors: dotColors,
                                    )
                                  : Icon(
                                      (canSend || widget.editingMessage != null)
                                        ? Icons.send_rounded
                                        : Icons.mic,
                                      color: (canSend || widget.editingMessage != null)
                                          ? colorScheme.onPrimary
                                          : colorScheme.primary,
                                      size: 20,
                                    ),
                              onPressed: widget.isLoading 
                                ? null 
                                : (canSend || widget.editingMessage != null)
                                  ? _handleSend
                                  : _startRecording,
                              tooltip: (canSend || widget.editingMessage != null)
                                  ? 'Send message'
                                  : 'Record voice message',
                            ),
                          ),
                        );
                      },
                    ),
                  // ✨ --- END OF FIX --- ✨
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}