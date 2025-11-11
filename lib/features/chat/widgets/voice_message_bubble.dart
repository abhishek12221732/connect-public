// lib/features/chat/widgets/voice_message_bubble.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with TickerProviderStateMixin {
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerController _waveformController = PlayerController();

  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  bool _waveformLoaded = false;

  late final AnimationController _uploadAnimController;
  late final AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    _uploadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    if (widget.message.uploadStatus == 'uploading') {
      _uploadAnimController.repeat();
    }
    
    _initAudio();
  }

  Future<void> _initAudio() async {
    final msgId = widget.message.id;
    debugPrint("------------------------------------------");
    debugPrint("[VOICE_DEBUG $msgId] _initAudio START");

    if (widget.message.uploadStatus == 'uploading') {
      debugPrint("[VOICE_DEBUG $msgId] Status: UPLOADING. Exiting.");
      return;
    }
    if (widget.message.uploadStatus == 'failed') {
      debugPrint("[VOICE_DEBUG $msgId] Status: FAILED. Exiting.");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      String? audioPathForPlayer;
      String? audioPathForWaveform;

      if (widget.message.localAudioPath != null &&
          File(widget.message.localAudioPath!).existsSync()) {
        
        audioPathForPlayer = widget.message.localAudioPath!;
        audioPathForWaveform = widget.message.localAudioPath!;
        debugPrint("[VOICE_DEBUG $msgId] Using localAudioPath: $audioPathForPlayer");

      } 
      else if (widget.message.audioUrl != null) {
        debugPrint("[VOICE_DEBUG $msgId] No local path. Using audioUrl: ${widget.message.audioUrl}");
        
        final appDir = await getApplicationDocumentsDirectory();
        final localFilePath = '${appDir.path}/audio_cache/audio_${widget.message.id}.m4a';
        final localFile = File(localFilePath);

        await localFile.parent.create(recursive: true);

        if (!await localFile.exists()) {
          debugPrint("[VOICE_DEBUG $msgId] Downloading to PERSISTENT path: $localFilePath");
          await Dio().download(widget.message.audioUrl!, localFilePath);
          debugPrint("[VOICE_DEBUG $msgId] Download complete.");
        } else {
          debugPrint("[VOICE_DEBUG $msgId] Using persistent file: $localFilePath");
        }
        
        audioPathForPlayer = localFilePath;
        audioPathForWaveform = localFilePath;

      } 
      else {
         debugPrint("[VOICE_DEBUG $msgId] CRITICAL: No localAudioPath or audioUrl found. Setting error.");
         setState(() {
           _isLoading = false;
           _hasError = true;
         });
         return;
      }

      debugPrint("[VOICE_DEBUG $msgId] Initializing player with: $audioPathForPlayer");
      final duration = await _audioPlayer.setFilePath(audioPathForPlayer);
      _totalDuration = duration ?? Duration.zero;
      debugPrint("[VOICE_DEBUG $msgId] Player initialized. Duration: $_totalDuration");

      try {
        debugPrint("[VOICE_DEBUG $msgId] Initializing waveform with: $audioPathForWaveform");
        _waveformController = PlayerController();
        await _waveformController.preparePlayer(
          path: audioPathForWaveform,
          shouldExtractWaveform: true,
          noOfSamples: 100,
          volume: 1.0,
        );
        
        _waveformController.seekTo(0);
        
        debugPrint("[VOICE_DEBUG $msgId] Waveform initialized SUCCESSFULLY.");
        if (mounted) setState(() => _waveformLoaded = true);
      } catch (e) {
        debugPrint("[VOICE_DEBUG $msgId] ⚠️ WAVEFORM FAILED TO LOAD: $e");
      }
      
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _isLoading = state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
          });
        }
        
        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
          _waveformController.seekTo(0);
          _playPauseController.reverse();
          if(mounted) setState(() => _currentPosition = Duration.zero);
        }
      });

      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _currentPosition = pos);
          
          if (_isPlaying && pos.inMilliseconds > 0) {
            _waveformController.seekTo(pos.inMilliseconds);
          }
        }
      });

      _durationSubscription = _audioPlayer.durationStream.listen((dur) {
        if (mounted) {
          setState(() => _totalDuration = dur ?? Duration.zero);
        }
      });
      
      debugPrint("[VOICE_DEBUG $msgId] _initAudio SUCCESS. Setting isLoading = false");
      if (mounted) setState(() => _isLoading = false);

    } catch (e, stackTrace) {
      debugPrint("[VOICE_DEBUG ${widget.message.id}] ❌❌❌ CATASTROPHIC ERROR in _initAudio: $e");
      debugPrint("[VOICE_DEBUG ${widget.message.id}] StackTrace: $stackTrace");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _waveformLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _uploadAnimController.dispose();
    _playPauseController.dispose();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _waveformController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError || _isLoading) return;
    
    if (_isPlaying) {
      _audioPlayer.pause();
      _playPauseController.reverse();
    } else {
      if (_currentPosition >= _totalDuration && _totalDuration.inSeconds > 0) {
        _audioPlayer.seek(Duration.zero);
        _waveformController.seekTo(0);
        setState(() => _currentPosition = Duration.zero);
      } else {
        _waveformController.seekTo(_currentPosition.inMilliseconds);
      }
      _audioPlayer.play();
      _playPauseController.forward();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildUploadingWidget(Color color) {
    final double minHeight = 6.0;
    final double maxHeight = 20.0;
    
    final List<Animation<double>> animations = [
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: minHeight, end: maxHeight), weight: 1),
        TweenSequenceItem(tween: Tween(begin: maxHeight, end: minHeight), weight: 1),
      ]).animate(CurvedAnimation(parent: _uploadAnimController, curve: Interval(0.0, 0.6, curve: Curves.easeInOut))),
      
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: minHeight, end: maxHeight), weight: 1),
        TweenSequenceItem(tween: Tween(begin: maxHeight, end: minHeight), weight: 1),
      ]).animate(CurvedAnimation(parent: _uploadAnimController, curve: Interval(0.2, 0.8, curve: Curves.easeInOut))),
      
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: minHeight, end: maxHeight), weight: 1),
        TweenSequenceItem(tween: Tween(begin: maxHeight, end: minHeight), weight: 1),
      ]).animate(CurvedAnimation(parent: _uploadAnimController, curve: Interval(0.4, 1.0, curve: Curves.easeInOut))),
    ];

    return AnimatedBuilder(
      animation: _uploadAnimController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // <-- Center vertically
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: animations[index].value,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    // ✨ --- THIS IS THE FIX --- ✨
    // Reverted this block to the simpler version
    if (widget.message.uploadStatus == 'uploading') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.schedule,
              color: color.withOpacity(0.7),
              size: 30,
            ),
            onPressed: null,
          ),
          Expanded(
            child: _buildUploadingWidget(color), // Just the animation
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Text(
              _formatDuration(Duration(seconds: (widget.message.audioDuration ?? 0).toInt())),
              style: theme.textTheme.labelMedium?.copyWith(
                color: color.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    // ✨ --- END OF FIX --- ✨
    
    if (widget.message.uploadStatus == 'failed' || _hasError) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(width: 12),
        Text("Upload failed", style: TextStyle(color: theme.colorScheme.error))
      ]);
    }

    // Main Player UI
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: _isLoading
              ? Icon(Icons.downloading_rounded, color: color, size: 30)
              : AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _playPauseController,
                  color: color,
                  size: 30,
                ),
          onPressed: _isLoading ? null : _togglePlayPause,
        ),
        
        Expanded(
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              _waveformLoaded
                ? AudioFileWaveforms(
                    size: const Size(double.infinity, 40),
                    playerController: _waveformController,
                    waveformType: WaveformType.long,
                    enableSeekGesture: true,
                    padding: const EdgeInsets.only(right: 50), 
                    margin: EdgeInsets.zero,
                    playerWaveStyle: PlayerWaveStyle(
                      fixedWaveColor: color.withOpacity(0.4),
                      liveWaveColor: color,
                      showSeekLine: false,
                    ),
                  )
                : Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 50),
                    child: Container(
                      height: 2.0,
                      color: color.withOpacity(0.4),
                    ),
                  ),
              
              Padding(
                padding: const EdgeInsets.only(right: 4.0), 
                child: Text(
                  _formatDuration(
                    _isPlaying
                      ? _currentPosition 
                      : (_totalDuration.inSeconds == 0 ? Duration(seconds: (widget.message.audioDuration ?? 0).toInt()) : _totalDuration)
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}