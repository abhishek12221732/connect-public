// lib/features/chat/widgets/voice_message_bubble.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/providers/user_provider.dart';

class VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final Future<String> Function(MessageModel)? onPrepareAudio;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onPrepareAudio,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = true; // Start as loading
  bool _hasError = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  late final AnimationController _uploadAnimController;

  @override
  void initState() {
    super.initState();
    _uploadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Start animation if uploading
    if (widget.message.uploadStatus == 'uploading') {
      _uploadAnimController.repeat();
    } else {
      // If already sent/received, init immediately
      _initAudio();
    }
  }

  // ✨ Resend Logic
  bool _isResending = false;

  Future<void> _handleResend() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    try {
      final userProvider = context.read<UserProvider>();
      final chatProvider = context.read<ChatProvider>();
      final isEncryptionEnabled = userProvider.isEncryptionEnforced;

      if (widget.message.localAudioPath == null) return;
      final file = File(widget.message.localAudioPath!);
      if (!file.existsSync()) return;
      
      await chatProvider.resendExpiredAudio(
        message: widget.message,
        audioFile: file,
        isEncryptionEnabled: isEncryptionEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice message restored successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Resend failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ✨ CRITICAL FIX: React when upload finishes
  @override
  void didUpdateWidget(VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If status changed from uploading -> sent/failed
    if (oldWidget.message.uploadStatus == 'uploading' &&
        widget.message.uploadStatus != 'uploading') {
      
      _uploadAnimController.stop();
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    // 1. Guard clauses
    if (!mounted) return;
    if (widget.message.uploadStatus == 'uploading') return;
    
    if (widget.message.uploadStatus == 'failed') {
      if(mounted) setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    try {
      String? audioPath;

      // 2. Prepare the Audio (Decrypt/Download)
      if (widget.onPrepareAudio != null) {
        // ✨ This is where we decrypt
        audioPath = await widget.onPrepareAudio!(widget.message);
      } 
      // Fallback for old/legacy messages
      else if (widget.message.localAudioPath != null &&
          File(widget.message.localAudioPath!).existsSync()) {
        audioPath = widget.message.localAudioPath!;
      } else if (widget.message.audioUrl != null) {
         // Legacy download logic...
         final appDir = await getApplicationDocumentsDirectory();
         final localFilePath = '${appDir.path}/audio_cache/audio_${widget.message.id}.m4a';
         final file = File(localFilePath);
         if (!await file.exists()) {
  await Dio().download(widget.message.audioUrl!, localFilePath);
}
         audioPath = localFilePath;
      }

      // 3. Verify path exists before loading
      if (audioPath == null || !File(audioPath).existsSync()) {
        print("❌ [VoiceBubble] Audio file not found at: $audioPath");
        if(mounted) setState(() { _isLoading = false; _hasError = true; });
        return;
      }

      // 4. Load into Player
      final duration = await _audioPlayer.setFilePath(audioPath);
      
      // 5. Setup Listeners
      _setupListeners(duration);
      
      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint('❌ [VoiceBubble] Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _setupListeners(Duration? duration) {
    _totalDuration = duration ?? Duration.zero;
      
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          // Only show loading if buffering, NOT during init (handled separately)
          if (state.processingState == ProcessingState.buffering) {
             _isLoading = true;
          } else if (state.processingState == ProcessingState.ready) {
             _isLoading = false;
          }
        });
      }
      
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        if(mounted) setState(() => _currentPosition = Duration.zero);
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });

    _durationSubscription = _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _uploadAnimController.dispose();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError) return;
    // Don't block tap if loading, sometimes player needs a nudge
    
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      if (_currentPosition >= _totalDuration && _totalDuration.inSeconds > 0) {
        _audioPlayer.seek(Duration.zero);
        if(mounted) setState(() => _currentPosition = Duration.zero);
      }
      _audioPlayer.play();
    }
  }

  // ... (Keep helper methods like _formatDuration, _buildUploadingWidget, _buildLoadingAnimation same as before)
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildUploadingWidget(Color color) {
    return AnimatedBuilder(
      animation: _uploadAnimController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (index) {
            final value = (math.sin((_uploadAnimController.value * 2 * math.pi) + (index * math.pi / 3)) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6 + (value * 14),
              width: 4.0,
              decoration: BoxDecoration(
                color: color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLoadingAnimation(Color color) {
    if (!_uploadAnimController.isAnimating) {
      _uploadAnimController.repeat();
    }
    
    return AnimatedBuilder(
      animation: _uploadAnimController,
      builder: (context, child) {
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (index) {
              final offset = index * (2 * math.pi / 3);
              final value = (math.sin((_uploadAnimController.value * 2 * math.pi) + offset) + 1) / 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 4 + (value * 12),
                width: 3.0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    // Check availability
    final bool isCached = widget.message.localAudioPath != null && 
                          File(widget.message.localAudioPath!).existsSync();
    final bool isExpiredButCached = widget.message.audioUrl == null && isCached;

    // Uploading state
    if (widget.message.uploadStatus == 'uploading') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, color: color.withOpacity(0.7), size: 24),
          const SizedBox(width: 12),
          Expanded(child: _buildUploadingWidget(color)),
          const SizedBox(width: 12),
          Text(
            _formatDuration(Duration(seconds: (widget.message.audioDuration ?? 0).toInt())),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 24), // Reserve space for timestamp/status overlay
        ],
      );
    }
    
    // Error state
    if (widget.message.uploadStatus == 'failed' || _hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 8),
          Text("Failed to load", style: TextStyle(color: theme.colorScheme.error, fontSize: 13))
        ],
      );
    }

    // Calculate progress
    final progress = _totalDuration.inMilliseconds > 0
        ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Main player UI
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? _buildLoadingAnimation(color)
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: color,
                    size: 24,
                  ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Waveform visualization
        Expanded(
          child: Center(
            child: CustomPaint(
              size: const Size(double.infinity, 32),
              painter: _WaveformPainter(
                progress: progress,
                color: color,
                isPlaying: _isPlaying,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Duration
        Text(
          _formatDuration(
            _isPlaying
              ? _currentPosition 
              : (_totalDuration.inSeconds == 0 
                  ? Duration(seconds: (widget.message.audioDuration ?? 0).toInt()) 
                  : _totalDuration)
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),

        // ✨ Resend Button (Only if Expired but Cached)
        if (isExpiredButCached) ...[
          const SizedBox(width: 12),
          Tooltip(
            message: "Restore to Server",
            child: InkWell(
              onTap: _handleResend,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isResending
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(Icons.restore_page_outlined, color: color.withOpacity(0.9), size: 20),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Keep your existing _WaveformPainter class...
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isPlaying;
  
  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.isPlaying,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Generate consistent bar heights
    final barCount = 40;
    final barWidth = 3.0;
    final spacing = (size.width - (barCount * barWidth)) / (barCount - 1);
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final heightFactor = 0.3 + (random.nextDouble() * 0.7); // 30-100% height
      final barHeight = size.height * heightFactor;
      final y = (size.height - barHeight) / 2;
      
      // Determine if this bar is in the "played" portion
      final barProgress = (x + barWidth / 2) / size.width;
      final isPlayed = barProgress <= progress;
      
      final paint = Paint()
        ..color = isPlayed ? color : color.withOpacity(0.3)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(x + barWidth / 2, y),
        Offset(x + barWidth / 2, y + barHeight),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.isPlaying != isPlaying;
  }
}