// lib/providers/secret_note_provider.dart

import 'dart:async';
import 'dart:io';
import 'dart:math'; // ✨ --- NEW IMPORT --- ✨
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Still needed for auth guard

// --- Imports from your project ---
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:feelings/features/media/repository/media_repository.dart';
import 'package:feelings/features/chat/repositories/chat_repository.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import 'package:feelings/features/secret_note/repositories/secret_note_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';

// ✨ --- ENUM UPDATED --- ✨
/// Defines the 7 possible locations where a secret note can appear.
enum SecretNoteLocation {
  moodBox,
  rhmMeter,
  bucketList,
  journal,
  calendar,
  chatAppBar,
  tipCard // <-- Now includes the new location
}
// ✨ --- END ENUM UPDATE --- ✨

class SecretNoteProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random(); 

  // Repositories
  final MediaRepository _mediaRepository;
  final ChatRepository _chatRepository;
  final SecretNoteRepository _secretNoteRepository;
  final RhmRepository _rhmRepository;

  // --- State ---
  List<MessageModel> _unreadNotes = []; // Full list of all unread notes
  StreamSubscription<List<MessageModel>>? _notesSubscription;
  String? _currentCoupleId;
  String? _currentUserId;
  bool _isLoading = false;

  // ✨ --- NEW ACTIVE NOTE STATE --- ✨
  /// The *single* note that is currently being shown somewhere in the UI.
  MessageModel? _activeSecretNote;

  /// The randomly chosen location for the `_activeSecretNote`.
  SecretNoteLocation? _activeNoteLocation;
  // ✨ --- END NEW ACTIVE NOTE STATE --- ✨

  // --- Public Getters ---

  /// Whether a note is currently being sent.
  bool get isLoading => _isLoading;

  /// The specific note to display in the UI.
  MessageModel? get activeSecretNote => _activeSecretNote;

  /// The specific location to display the note.
  SecretNoteLocation? get activeNoteLocation => _activeNoteLocation;

  SecretNoteProvider({
    MediaRepository? mediaRepository,
    ChatRepository? chatRepository,
    SecretNoteRepository? secretNoteRepository,
    RhmRepository? rhmRepository, // Add this
  })  : _mediaRepository = mediaRepository ?? MediaRepository(),
        _chatRepository = chatRepository ?? ChatRepository(),
        _secretNoteRepository =
            secretNoteRepository ?? SecretNoteRepository(),
        _rhmRepository = rhmRepository ?? RhmRepository();

  /// Listens for new, unread secret notes directed at the current user.
  void listenForUnreadNotes(String coupleId, String currentUserId) {
    if (_notesSubscription != null &&
        _currentCoupleId == coupleId &&
        _currentUserId == currentUserId) {
      return;
    }

    clear(); // Clear old state first

    _currentCoupleId = coupleId;
    _currentUserId = currentUserId;

    debugPrint(
        '[SecretNoteProvider] STARTING LISTENER for couple: $coupleId, user: $currentUserId');

    _notesSubscription = _secretNoteRepository
        .listenToUnreadNotes(coupleId, currentUserId)
        .listen(
      (notes) {
        if (_auth.currentUser == null) {
          debugPrint(
              "[SecretNoteProvider] Event received, but user is logged out. Ignoring.");
          return;
        }

        debugPrint(
            '[SecretNoteProvider] DATA RECEIVED: Found ${notes.length} unread notes.');

        // Update the main list
        _unreadNotes = notes;

        // ✨ --- NEW LOGIC: RANDOMLY ASSIGN NOTE & LOCATION --- ✨
        if (_unreadNotes.isEmpty) {
          // No notes? Clear the active note.
          _clearActiveNote();
        } else {
          // If there's already an active note, check if it's still in the unread list.
          // If it is, we don't change anything (prevents the icon from jumping).
          if (_activeSecretNote != null &&
              _unreadNotes.any((note) => note.id == _activeSecretNote!.id)) {
            // The current note is still active, do nothing.
            return;
          }

          // If there's no active note (or the old one was just read),
          // pick a new one to display.
          _assignNewActiveNote();
        }
        // ✨ --- END NEW LOGIC --- ✨
      },
      onError: (error) {
        debugPrint("[SecretNoteProvider] LISTENER ERROR: $error");
        _unreadNotes = [];
        _clearActiveNote(); // Clear on error too
      },
    );
  }

  /// Marks a specific note as read, which will remove it from the UI.
  Future<void> markNoteAsRead(String noteId) async {
    if (_currentCoupleId == null) {
      debugPrint("[SecretNoteProvider] Cannot mark as read: coupleId is null.");
      return;
    }

    // ✨ --- NEW LOGIC --- ✨
    // Clear the active note *immediately* from the UI.
    // This makes the icon disappear the moment the dialog is opened.
    if (noteId == _activeSecretNote?.id) {
      _clearActiveNote();
    }
    // ✨ --- END NEW LOGIC --- ✨

    // Update the document in Firestore in the background
    try {
      await _secretNoteRepository.markNoteAsRead(_currentCoupleId!, noteId);
      // When the listener receives the updated list, it will
      // automatically pick a new note if one is available.
    } catch (e) {
      debugPrint("Error marking note as read: $e");
      // If this fails, the listener will eventually re-add the note,
      // but the UI will be correct for now.
    }
  }

  // --- NEW HELPER METHODS ---

  /// Picks a new random note and location from the unread list.
  void _assignNewActiveNote() {
    if (_unreadNotes.isEmpty) {
      _clearActiveNote();
      return;
    }
    
    // 1. Pick a random note from the list
    _activeSecretNote = _unreadNotes[_random.nextInt(_unreadNotes.length)];
    
    // 2. Pick a random location
    _activeNoteLocation = SecretNoteLocation
        .values[_random.nextInt(SecretNoteLocation.values.length)];

    debugPrint(
        '[SecretNoteProvider] New Active Note: ${_activeSecretNote!.id} at location: $_activeNoteLocation');
    
    notifyListeners();
  }

  /// Clears the active note and location and notifies the UI.
  void _clearActiveNote() {
    if (_activeSecretNote != null || _activeNoteLocation != null) {
      _activeSecretNote = null;
      _activeNoteLocation = null;
      notifyListeners();
    }
  }

  // --- END NEW HELPER METHODS ---

  // ✨ --- CODE WAS MISSING FROM HERE DOWN --- ✨

  /// Sends a secret note (text, image, or audio) to the partner.
  Future<void> sendSecretNote({
    required String coupleId,
    required String senderId,
    required String receiverId,
    required String content, // Caption for image, text for text
    File? imageFile,
    File? audioFile,
  }) async {
    if (content.trim().isEmpty && imageFile == null && audioFile == null) {
      throw Exception("Cannot send an empty secret note.");
    }

    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      String messageType = 'text';
      String? googleDriveImageId;
      String? audioUrl;
      double? audioDuration;

      // --- 1. Handle Image Upload (Unchanged) ---
      if (imageFile != null) {
        messageType = 'image';
        debugPrint("[SecretNoteProvider] Uploading image to Google Drive...");
        googleDriveImageId = await _mediaRepository.uploadToGoogleDrive(
          imageFile,
          (progress) {
            debugPrint('[SecretNoteProvider] Image Upload Progress: $progress');
          },
        );
        if (googleDriveImageId == null) {
          throw Exception('Image upload failed, Google Drive ID was null.');
        }
        await LocalStorageHelper.saveImageLocally(
            imageFile, googleDriveImageId);
      }

      // --- 2. Handle Audio Upload (Unchanged) ---
      if (audioFile != null) {
        messageType = 'voice';
        debugPrint("[SecretNoteProvider] Uploading audio to Storage...");

        try {
          final duration = await _audioPlayer.setFilePath(audioFile.path);
          audioDuration =
              (duration?.inMilliseconds.toDouble() ?? 0.0) / 1000.0;
        } catch (e) {
          debugPrint("Error getting audio duration: $e");
          audioDuration = 0.0; // Fallback
        }

        final tempId =
            'secret_note_audio_${DateTime.now().millisecondsSinceEpoch}';
        audioUrl = await _chatRepository.uploadAudioToFirebaseStorage(
          audioFile,
          senderId,
          receiverId,
          tempId,
        );
      }

      // --- 3. Create Model and Send to Repository (Unchanged) ---
      final note = MessageModel(
        id: '', // The repository will generate this
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        timestamp: DateTime.now(),
        status: 'sent', // Set a default status
        participants: [senderId, receiverId],
        messageType: messageType,
        googleDriveImageId: googleDriveImageId,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
      );

      await _secretNoteRepository.sendSecretNote(coupleId, note);
      _logRhmPoints(coupleId, senderId);

      debugPrint("[SecretNoteProvider] Secret note sent successfully!");
    } catch (e) {
      debugPrint("Error sending secret note: $e");
      rethrow; // Let the UI show an error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _logRhmPoints(String coupleId, String userId) async {
    const String actionType = 'secret_note_sent';
    const int points = 3;
    const Duration limit = Duration(hours: 24);

    try {
      final lastActionTime = 
          await _rhmRepository.getLastActionTimestampForUser(
        coupleId,
        userId,
        actionType,
      );

      if (lastActionTime == null || 
          DateTime.now().difference(lastActionTime) > limit) {
        
        await _rhmRepository.logAction(
          coupleId: coupleId,
          userId: userId,
          actionType: actionType,
          points: points,
        );
        debugPrint("[SecretNoteProvider] Logged $points RHM points for $actionType.");
      } else {
        debugPrint("[SecretNoteProvider] RHM points for $actionType are on cooldown.");
      }
    } catch (e) {
      debugPrint("[SecretNoteProvider] Error logging RHM points: $e");
    }
  }

  /// Clears all local state and cancels listeners.
  /// Called on logout.
  void clear() {
    _notesSubscription?.cancel();
    _notesSubscription = null;
    _unreadNotes = [];
    _isLoading = false;
    _currentCoupleId = null;
    _currentUserId = null;
    _activeSecretNote = null;
    _activeNoteLocation = null;

    debugPrint("[SecretNoteProvider] Cleared and reset state.");
  }

  @override
  void dispose() {
    clear();
    _audioPlayer.dispose();
    super.dispose();
  }
}