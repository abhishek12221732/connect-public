// lib/features/secret_note/screens/secret_note_composer_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Your Project's Providers
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';

// Import the NoteType enum from the card
import 'package:feelings/features/discover/widgets/send_secret_note_card.dart';

// ✨ --- NEW IMPORT --- ✨
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class SecretNoteComposerScreen extends StatefulWidget {
  final NoteType noteType;

  const SecretNoteComposerScreen({
    super.key,
    required this.noteType,
  });

  @override
  State<SecretNoteComposerScreen> createState() =>
      _SecretNoteComposerScreenState();
}

class _SecretNoteComposerScreenState extends State<SecretNoteComposerScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  File? _selectedImage;
  bool _hasText = false;

  // Audio Recording State
  late final AudioRecorder _audioRecorder;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  bool _isRecording = false;
  bool _hasRecordedFile = false;

  // UI State
  bool _isSending = false;
  late AnimationController _recordingBlinkController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _recordingBlinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _textController.addListener(() {
      if (_hasText != _textController.text.isNotEmpty) {
        setState(() {
          _hasText = _textController.text.isNotEmpty;
        });
      }
    });

    // Automatically open the correct input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initComposer();
    });
  }

  void _initComposer() {
    switch (widget.noteType) {
      case NoteType.text:
        // Automatically open the keyboard for text
        _textFocusNode.requestFocus();
        break;
      case NoteType.image:
        // Automatically open the image picker
        _pickImage();
        break;
      case NoteType.voice:
        // Automatically start recording
        _startRecording();
        break;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _recordingBlinkController.dispose();
    super.dispose();
  }

  // --- Image Logic ---
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
      } else if (_selectedImage == null) {
        // If they cancelled the picker and no image was ever selected,
        // dismiss the whole modal.
        _dismiss();
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
      _dismiss(); // Dismiss on error
    }
  }

  // --- Audio Logic ---
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint("Microphone permission denied");
      _dismiss(); // Dismiss if permission denied
      return;
    }

    final tempDir = await getTemporaryDirectory();
    _recordingPath =
        '${tempDir.path}/secret_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      _dismiss();
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      if (_recordingDuration.inSeconds > 0 ||
          _recordingDuration.inMilliseconds > 500) {
        setState(() {
          _isRecording = false;
          _hasRecordedFile = true;
          _recordingPath = path;
        });
      } else {
        _cancelRecording(dismiss: true); // Too short, cancel and dismiss
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      _resetRecordingState();
    }
  }

  void _cancelRecording({bool dismiss = false}) {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) {
        file.delete();
      }
    }
    _resetRecordingState();
    if (dismiss && mounted) {
      _dismiss();
    }
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

  // --- Send & Dismiss Logic ---
  void _dismiss() {
    // Unfocus to hide keyboard *before* navigating
    _textFocusNode.unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send() async {
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();

    // Use the *correct* User ID from currentUser.id
    final String senderId = userProvider.currentUser?.id ?? '';
    final String receiverId = userProvider.partnerData?['userId'] ?? '';
    final String coupleId = coupleProvider.coupleId ?? '';

    if (senderId.isEmpty || receiverId.isEmpty || coupleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not send note. User or couple data is missing.')),
      );
      return;
    }

    // Determine what to send
    File? audioFile;
    if (widget.noteType == NoteType.voice && _hasRecordedFile) {
      audioFile = File(_recordingPath!);
    }

    // Double check that there is *something* to send
    if (_textController.text.trim().isEmpty &&
        _selectedImage == null &&
        audioFile == null) {
      _dismiss(); // Nothing to send, just dismiss
      return;
    }

    setState(() => _isSending = true);

    try {
      await context.read<SecretNoteProvider>().sendSecretNote(
            coupleId: coupleId,
            senderId: senderId,
            receiverId: receiverId,
            content: _textController.text.trim(),
            imageFile: _selectedImage,
            audioFile: audioFile,
          );

      // ✨ --- CHANGE --- ✨
      // Success
      _dismiss();
      // SnackBar removed as requested.
      // ✨ --- END OF CHANGE --- ✨

    } catch (e) {
      // Error
      debugPrint('Error sending secret note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send note: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool canSend = (_hasText || _selectedImage != null || _hasRecordedFile) && !_isSending;

    return GestureDetector(
      onTap: _dismiss, // Tap background to dismiss
      child: Scaffold(
        backgroundColor: Colors.transparent, // See-through
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap:
                () {}, // Trap taps inside the card to prevent dismissal
            child: Material(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Title Bar ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _dismiss,
                            child: const Text('Cancel'),
                          ),
                          Text(
                            _getTitle(),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          ElevatedButton(
                            onPressed: canSend ? _send : null,
                            child: _isSending
                                // ✨ --- CHANGE --- ✨
                                ? PulsingDotsIndicator(
                                    size: 20,
                                    colors: [
                                      colorScheme.onPrimary.withOpacity(0.8),
                                      colorScheme.onPrimary,
                                      colorScheme.onPrimary.withOpacity(0.8),
                                    ],
                                  )
                                // ✨ --- END OF CHANGE --- ✨
                                : const Text('Send'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      const SizedBox(height: 20),

                      // --- Composer Area ---
                      _buildComposerArea(theme, colorScheme),

                      // Add padding for the keyboard
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // This is the user's provided version
  String _getTitle() {
    switch (widget.noteType) {
      case NoteType.text:
        return 'Secret Note';
      case NoteType.image:
        return 'New Image';
      case NoteType.voice:
        return 'Voice Note';
    }
  }

  Widget _buildComposerArea(ThemeData theme, ColorScheme colorScheme) {
    switch (widget.noteType) {
      // --- TEXT COMPOSER ---
      case NoteType.text:
        return TextField(
          focusNode: _textFocusNode,
          controller: _textController,
          maxLines: 8,
          minLines: 8,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Write your secret note...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        );

      // --- IMAGE COMPOSER ---
      case NoteType.image:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage == null)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        const Text('Tap to change image'),
                      ],
                    ),
                  ),
                ),
              ),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              decoration: InputDecoration(
                hintText: '(Optional) Add a caption...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        );

      // --- VOICE COMPOSER ---
      case NoteType.voice:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRecording
                  ? "Recording..."
                  : (_hasRecordedFile
                      ? "Recording Complete!"
                      : "Starting recorder..."),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDuration(_recordingDuration),
              style: theme.textTheme.displayMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording)
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
            if (!_isRecording && _hasRecordedFile)
              GestureDetector(
                onTap: _startRecording, // Re-record
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.replay_rounded,
                      color: colorScheme.onSurfaceVariant, size: 40),
                ),
              ),
          ],
        );
    }
  }
}