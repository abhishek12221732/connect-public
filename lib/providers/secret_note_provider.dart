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

import 'package:feelings/services/encryption_service.dart'; // Needed for OTK encryption
import 'package:path_provider/path_provider.dart'; // Needed for playback
import 'package:http/http.dart' as http; // Needed for download

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
  StreamSubscription? _keyWaitSub;
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
  void listenForUnreadNotes(String coupleId, String currentUserId) async{
    if (_notesSubscription != null &&
        _currentCoupleId == coupleId &&
        _currentUserId == currentUserId) {
      return;
    }

    clear(); // Clear old state first

    _currentCoupleId = coupleId;
    _currentUserId = currentUserId;

    // ✨ LISTEN FOR KEY READY
    _keyWaitSub?.cancel();
    _keyWaitSub = EncryptionService.instance.onKeyReady.listen((isReady) {
      if (isReady) {
        debugPrint("[SecretNotes] Key ready! Refreshing notes...");
        listenForUnreadNotes(coupleId, currentUserId);
      }
    });

    _notesSubscription = _secretNoteRepository
        .listenToUnreadNotes(coupleId, currentUserId)
        .listen(
      (notes) async{
        // ✨ DECRYPTION LOGIC START
        final List<MessageModel> decryptedNotes = [];

        for (var note in notes) {
          if (note.encryptionVersion == 1) {
            final decryptedString = await note.getDecryptedContent();
            
            if (note.messageType == 'image') {
               // For images, the decrypted string is the ID
               decryptedNotes.add(note.copyWith(googleDriveImageId: decryptedString));
            } else {

               // For text, it's the content
               decryptedNotes.add(note.copyWith(content: decryptedString));
            }
          } 
          // ✨ MIGRATION LOGIC
          else if (EncryptionService.instance.isReady && note.encryptionVersion == null) {
            bool needsMigration = (note.messageType == 'text' && note.content.isNotEmpty) ||
                                  (note.messageType == 'image' && note.googleDriveImageId != null);
            
            if (needsMigration) {
               _secretNoteRepository.migrateLegacySecretNote(coupleId, note);
            }
            decryptedNotes.add(note);
          }
          else {
            decryptedNotes.add(note);
          }
        }
        // ✨ DECRYPTION LOGIC END
        // ✨ LOGGING TO DEBUG IMAGE ID
        for (var n in decryptedNotes) {
          if (n.messageType == 'image') {
            debugPrint("[SecretNotes] Decrypted Image ID: ${n.googleDriveImageId} (Original v=${n.encryptionVersion})");
          }
        }
        if (_auth.currentUser == null) {
          debugPrint(
              "[SecretNoteProvider] Event received, but user is logged out. Ignoring.");
          return;
        }

        debugPrint(
            '[SecretNoteProvider] DATA RECEIVED: Found ${notes.length} unread notes.');

        // Update the main list
        _unreadNotes = decryptedNotes;

        // ✨ --- NEW LOGIC: RANDOMLY ASSIGN NOTE & LOCATION --- ✨
        if (_unreadNotes.isEmpty) {
          // No notes? Clear the active note.
          _clearActiveNote();
        } else {
          // If there's already an active note, check if it's still in the unread list.
          // If it is, we don't change anything (prevents the icon from jumping).
          if (_activeSecretNote != null &&
              _unreadNotes.any((note) => note.id == _activeSecretNote!.id)) {
            // ✨ FIX: Update the active note reference to the NEW (decrypted) one
            _activeSecretNote = _unreadNotes.firstWhere((note) => note.id == _activeSecretNote!.id);
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

  /// Deletes the secret note from the database (True Ephemerality).
  /// This removes it from the UI immediately.
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

    // ✨ --- UPDATED LOGIC --- ✨
    // DELETE the document from Firestore.
    // This creates "True Ephemerality" - once seen, it is gone forever.
    try {
      await _secretNoteRepository.deleteSecretNote(_currentCoupleId!, noteId);
    } catch (e) {
      debugPrint("Error deleting secret note: $e");
      // If deletion fails, we might retry or just leave it. 
      // It will stay in the list until deleted.
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
    // 1. Validation
    if (content.trim().isEmpty && imageFile == null && audioFile == null) {
      throw Exception("Cannot send an empty secret note.");
    }

    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 2. Setup Variables
      String messageType = 'text';
      String? googleDriveImageId;
      String? audioUrl;
      double? audioDuration;
      
      // Encryption Vars
      String finalContent = content.trim();
      String? finalGoogleDriveImageId;
      
      String? ciphertext;
      String? nonce;
      String? mac;
      int? encryptionVersion;

      // ---------------------------------------------------------
      // A. IMAGE HANDLING
      // ---------------------------------------------------------
      if (imageFile != null) {
        messageType = 'image';
        debugPrint("[SecretNoteProvider] Uploading image to Google Drive...");
        googleDriveImageId = await _mediaRepository.uploadToGoogleDrive(
          imageFile,
          (progress) => debugPrint('[SecretNote] Image Progress: $progress'),
        );
        if (googleDriveImageId == null) {
          throw Exception('Image upload failed.');
        }
        await LocalStorageHelper.saveImageLocally(imageFile, googleDriveImageId);
        finalGoogleDriveImageId = googleDriveImageId;
      }

      // ---------------------------------------------------------
      // B. AUDIO HANDLING (Now Encrypted!)
      // ---------------------------------------------------------
      if (audioFile != null) {
        messageType = 'voice';
        debugPrint("[SecretNoteProvider] Uploading Secure Audio...");

        // 1. Get Duration
        try {
          final duration = await _audioPlayer.setFilePath(audioFile.path);
          audioDuration = (duration?.inMilliseconds.toDouble() ?? 0.0) / 1000.0;
        } catch (e) {
          audioDuration = 0.0;
        }

        // 2. Generate ID
        final tempId = 'secret_note_audio_${DateTime.now().millisecondsSinceEpoch}';

        // 3. ✨ UPLOAD SECURELY (Reusing ChatRepository logic)
        // This encrypts the file bytes locally and uploads the encrypted blob.
        final uploadResult = await _chatRepository.uploadSecureAudio(
          audioFile, 
          senderId, 
          receiverId, 
          tempId
        );

        audioUrl = uploadResult['url'];
        
        // 4. ✨ HANDLE ENCRYPTION METADATA FOR AUDIO
        // If we have an OTK (One-Time Key), we must encrypt it with the Master Key.
        if (EncryptionService.instance.isReady && uploadResult['otk'] != null && uploadResult['otk']!.isNotEmpty) {
           final encOtk = await EncryptionService.instance.encryptText(uploadResult['otk']!);
           
           ciphertext = encOtk['ciphertext']; // Encrypted OTK
           nonce = encOtk['nonce'];           // Nonce for OTK
           mac = encOtk['mac'];
           encryptionVersion = 1;
           
           // Store the File Nonce in 'content' so we can decrypt later
           finalContent = uploadResult['nonce'] ?? ''; 
        }
      }

      // ---------------------------------------------------------
      // C. TEXT / IMAGE ID ENCRYPTION (If Audio didn't already happen)
      // ---------------------------------------------------------
      if (EncryptionService.instance.isReady && audioFile == null) {
         // Case 1: Text Note
         if (messageType == 'text' && finalContent.isNotEmpty) {
            final encrypted = await EncryptionService.instance.encryptText(finalContent);
            ciphertext = encrypted['ciphertext'];
            nonce = encrypted['nonce'];
            mac = encrypted['mac'];
            encryptionVersion = 1;
            finalContent = ""; // Hide
         }
         // Case 2: Image Note (Encrypt ID)
         else if (messageType == 'image' && finalGoogleDriveImageId != null) {
            final encrypted = await EncryptionService.instance.encryptText(finalGoogleDriveImageId!);
            ciphertext = encrypted['ciphertext'];
            nonce = encrypted['nonce'];
            mac = encrypted['mac'];
            encryptionVersion = 1;
            finalGoogleDriveImageId = ""; // Hide
         }
      }

      // ---------------------------------------------------------
      // D. SEND TO FIRESTORE
      // ---------------------------------------------------------
      final note = MessageModel(
        id: '', // Repo generates this
        senderId: senderId,
        receiverId: receiverId,
        timestamp: DateTime.now(),
        status: 'sent',
        participants: [senderId, receiverId],
        
        messageType: messageType,
        content: finalContent, // Plaintext OR FileNonce
        googleDriveImageId: finalGoogleDriveImageId, // Plain ID OR Empty
        
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        
        // Encrypted Fields
        ciphertext: ciphertext,
        nonce: nonce,
        mac: mac,
        encryptionVersion: encryptionVersion,
      );

      await _secretNoteRepository.sendSecretNote(coupleId, note);
      _logRhmPoints(coupleId, senderId);

      debugPrint("[SecretNoteProvider] Secret note sent securely!");

    } catch (e) {
      if (e.toString().contains("GoogleAuthCancelledException")) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      debugPrint("Error sending secret note: $e");
      rethrow;
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

  /// Helper to prepare audio for playback
  Future<String> prepareAudioFile(MessageModel msg) async {
    // 1. Check for PREVIOUSLY DECRYPTED file (Cached)
    final tempDir = await getTemporaryDirectory();
    final decryptedFile = File('${tempDir.path}/${msg.id}_dec.m4a');
    
    if (await decryptedFile.exists()) {
      return decryptedFile.path;
    }

    // 2. Check for ORIGINAL RECORDING (Sent by me)
    // IMPORTANT: Only return this if it's the sender and the file actually exists on disk.
    // This relies on listenToMessages correctly preserving the localAudioPath.
    if (msg.localAudioPath != null) {
      final originalFile = File(msg.localAudioPath!);
      if (await originalFile.exists()) {
        return originalFile.path;
      }
    }

    // 3. Download & Decrypt
    try {
      if (msg.audioUrl == null) throw Exception("Audio URL is null");
      
      // debugPrint("⬇️ [Audio] Downloading from: ${msg.audioUrl}");
      final response = await http.get(Uri.parse(msg.audioUrl!));
      
      if (response.statusCode != 200) {
        throw Exception("Download failed with status: ${response.statusCode}");
      }
      
      final encryptedBytes = response.bodyBytes;
      List<int> playableBytes = encryptedBytes;

      // 4. Decrypt (if needed)
      if (msg.encryptionVersion == 1) {
         if (msg.ciphertext == null || msg.content.isEmpty) {
           debugPrint("⚠️ [Audio] Encryption flag set, but metadata missing. Playing as-is.");
         } else {
           // debugPrint("🔐 [Audio] Decrypting audio...");
           final otkBase64 = await EncryptionService.instance.decryptText(
             msg.ciphertext!, msg.nonce!, msg.mac!
           );
           
           playableBytes = await EncryptionService.instance.decryptFile(
             encryptedBytes, 
             msg.content, // File Nonce
             otkBase64
           );
         }
      }

      // 5. Save to temp file
      if (playableBytes.isEmpty) throw Exception("Decryption resulted in empty file");
      
      await decryptedFile.writeAsBytes(playableBytes);
      debugPrint("✅ [Audio] Saved ready-to-play file: ${decryptedFile.path}");
      return decryptedFile.path;

    } catch (e) {
      debugPrint("❌ [Audio] Prep failed: $e");
      rethrow;
    }
  }

  /// Clears all local state and cancels listeners.
  /// Called on logout.
  void clear() {
    _notesSubscription?.cancel();
    _notesSubscription = null;
    _keyWaitSub?.cancel();
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