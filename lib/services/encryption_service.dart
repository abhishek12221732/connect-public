// lib/services/encryption_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  static EncryptionService get instance => _instance;

  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  
  // For Data Encryption (Symmetric)
  final _chacha = Chacha20.poly1305Aead();
  
  // For Key Exchange (Asymmetric)
  final _x25519 = X25519();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);


  // 1. A Signal (Completer) that completes when the key is loaded
  Completer<void> _cmkReadyCompleter = Completer<void>();
  
  // 1b. A Stream that broadcasts when the Key status changes
  final _isReadyController = StreamController<bool>.broadcast();
  Stream<bool> get onKeyReady => _isReadyController.stream;

  // 2. The Future that Providers will await
  Future<void> get cmkReadyFuture => _cmkReadyCompleter.future;

  SecretKey? _cachedCoupleMasterKey;
  SimpleKeyPair? _deviceKeyPair;

  bool get isReady => _cachedCoupleMasterKey != null;

  /// Clear session keys (CMK) from memory and storage, but PRESERVE Device Identity.
  /// Call this on standard Logout.
  Future<void> clearSessionKeys() async {
    debugPrint("🔐 [Encryption] Clearing session keys...");
    _cachedCoupleMasterKey = null;
    // Keep _deviceKeyPair loaded! It belongs to the device, not the user session technically.
    // Or we can clear it from memory but NOT storage. 
    // Let's clear memory to be safe, it will reload from storage on next login.
    _deviceKeyPair = null;
    
    try {
      // ✨ SAFE WIPE: Delete all CMKs, but KEEP 'device_private_key'
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
         if (key.startsWith('cmk_')) {
            await _storage.delete(key: key);
         }
      }
      debugPrint("🔐 [Encryption] Session keys wiped from storage.");
    } catch (e) {
       debugPrint("⚠️ [Encryption] Failed to wipe session keys: $e");
    }

    // Reset the signal for the next user
    if (_cmkReadyCompleter.isCompleted) {
      _cmkReadyCompleter = Completer<void>();
    }
    // Notify listeners that we are no longer ready
    _isReadyController.add(false);
  }

  /// DANGER: Wipes EVERYTHING including Device Identity.
  /// Call this only on "Delete Account" or "Reset App".
  Future<void> hardReset() async {
     debugPrint("🚨 [Encryption] HARD RESET: Wiping Identity and Keys...");
     _cachedCoupleMasterKey = null;
     _deviceKeyPair = null;
     await _storage.deleteAll();
     
     if (_cmkReadyCompleter.isCompleted) {
      _cmkReadyCompleter = Completer<void>();
    }
    _isReadyController.add(false);
  }

  /// 1. Initialize & Load Device Identity
  Future<void> init() async {
    debugPrint("🔐 [Encryption] Starting initialization...");
    try {
      String? encodedPrivateKey = await _storage.read(key: 'device_private_key');
      debugPrint("🔐 [Encryption] Storage check: ${encodedPrivateKey != null ? 'Found existing private key' : 'No private key found'}");
      
      if (encodedPrivateKey == null) {
        debugPrint("🔐 [Encryption] Generating new device identity (X25519)...");
        final keyPair = await _x25519.newKeyPair();
        final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
        await _storage.write(key: 'device_private_key', value: base64Encode(privateKeyBytes));
        _deviceKeyPair = keyPair;
        debugPrint("🔐 [Encryption] New Device Identity generated and saved.");
      } else {
        final privateKeyBytes = base64Decode(encodedPrivateKey);
        _deviceKeyPair = await _x25519.newKeyPairFromSeed(privateKeyBytes);
        debugPrint("🔐 [Encryption] Device Identity loaded from storage.");
      }
    } catch (e) {
      debugPrint("❌ [Encryption] Initialization FAILED: $e");
    }
  }

  /// Helper: Get my Public Key (to share with partner)
  Future<String> getDevicePublicKey() async {
    if (_deviceKeyPair == null) await init();
    final pubKey = await _deviceKeyPair!.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }

  /// 2. Generate Master Key (User A does this)
  Future<void> generateAndSaveMasterKey(String coupleId) async {
    final secretKey = await _chacha.newSecretKey();
    _cachedCoupleMasterKey = secretKey;
    final bytes = await secretKey.extractBytes();
    await _storage.write(key: 'cmk_$coupleId', value: base64Encode(bytes));
    debugPrint("🔐 [Encryption] New CMK generated.");
  }

  // 3. Update loadMasterKey to complete the signal
  Future<bool> loadMasterKey(String coupleId) async {
    final encodedKey = await _storage.read(key: 'cmk_$coupleId');
    debugPrint("🔐 [Encryption] loadMasterKey for $coupleId: ${encodedKey != null ? 'Start' : 'Not Found'}");
    if (encodedKey != null) {
      _cachedCoupleMasterKey = SecretKey(base64Decode(encodedKey));
      
      // ✨ Signal ready!
      if (!_cmkReadyCompleter.isCompleted) {
        _cmkReadyCompleter.complete();
      }
      _isReadyController.add(true); // Notify listeners
      return true;
    }
    return false;
  }

  // =========================================================
  // NEW: KEY EXCHANGE LOGIC (The Handshake)
  // =========================================================

  /// 4. Encrypt the CMK for the Partner (User A -> User B)
  /// Uses ECDH: My Private Key + Partner Public Key = Shared Secret
  Future<Map<String, String>> encryptMasterKeyForPartner(String partnerPublicKeyBase64) async {
    if (_cachedCoupleMasterKey == null) throw Exception("No CMK to share!");
    if (_deviceKeyPair == null) await init();

    // A. Reconstruct Partner's Public Key
    final partnerPubKeyBytes = base64Decode(partnerPublicKeyBase64);
    final partnerPublicKey = SimplePublicKey(partnerPubKeyBytes, type: KeyPairType.x25519);

    // B. Derive Shared Secret (ECDH)
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _deviceKeyPair!,
      remotePublicKey: partnerPublicKey,
    );

    // C. Derive a strong encryption key from that shared secret (HKDF)
    final derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [], // Context-specific info could go here
    );

    // D. Encrypt the CMK using this derived key
    final cmkBytes = await _cachedCoupleMasterKey!.extractBytes();
    final nonce = _chacha.newNonce();
    
    final secretBox = await _chacha.encrypt(
      cmkBytes,
      secretKey: derivedKey,
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// 5. Decrypt the CMK received from Partner (User B receives)
  Future<void> decryptAndSaveMasterKey(String coupleId, String partnerPublicKeyBase64, Map<String, dynamic> encryptedData) async {
    if (_deviceKeyPair == null) await init();

    // A. Reconstruct Partner's Public Key
    final partnerPubKeyBytes = base64Decode(partnerPublicKeyBase64);
    final partnerPublicKey = SimplePublicKey(partnerPubKeyBytes, type: KeyPairType.x25519);

    // B. Derive SAME Shared Secret (ECDH)
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _deviceKeyPair!,
      remotePublicKey: partnerPublicKey,
    );

    // C. Derive SAME encryption key (HKDF)
    final derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [],
    );

    // D. Decrypt
    final secretBox = SecretBox(
      base64Decode(encryptedData['ciphertext']),
      nonce: base64Decode(encryptedData['nonce']),
      mac: Mac(base64Decode(encryptedData['mac'])),
    );

    final cmkBytes = await _chacha.decrypt(
      secretBox,
      secretKey: derivedKey,
    );

    // E. Save to Storage
      _cachedCoupleMasterKey = SecretKey(cmkBytes);
      await _storage.write(key: 'cmk_$coupleId', value: base64Encode(cmkBytes));
      
      // ✨ Signal ready!
      if (!_cmkReadyCompleter.isCompleted) {
        _cmkReadyCompleter.complete();
      }
      _isReadyController.add(true);
      debugPrint("🔐 [Encryption] Master Key saved & Ready Signal fired.");
  }

  /// 6. Encrypt Data (String -> Encrypted Blob)
  Future<Map<String, dynamic>> encryptText(String plaintext) async {
    if (_cachedCoupleMasterKey == null) throw Exception("Encryption not ready: No Master Key");

    final nonce = _chacha.newNonce();
    
    // Encrypt
    final secretBox = await _chacha.encrypt(
      utf8.encode(plaintext),
      secretKey: _cachedCoupleMasterKey!,
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'version': 1,
    };
  }

  /// 7. Decrypt Data (Encrypted Blob -> String)
  Future<String> decryptText(String ciphertext, String nonce, String mac) async {
    if (_cachedCoupleMasterKey == null) throw Exception("Encryption not ready: No Master Key");

    final secretBox = SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );

    final clearTextBytes = await _chacha.decrypt(
      secretBox,
      secretKey: _cachedCoupleMasterKey!,
    );

    return utf8.decode(clearTextBytes);
  }



  /// 8. Encrypt Binary Data (For Voice Messages)
  /// Returns { 'ciphertext': List<int>, 'nonce': String, 'key': String }
  /// We return the One-Time Key (OTK) so you can encrypt it separately.
  Future<Map<String, dynamic>> encryptFile(File file) async {
    final bytes = await file.readAsBytes();
    
    // Generate a One-Time Key (OTK) for this specific file
    final otk = await _chacha.newSecretKey();
    final nonce = _chacha.newNonce();
    
    // Encrypt the file bytes
    final secretBox = await _chacha.encrypt(
      bytes,
      secretKey: otk,
      nonce: nonce,
    );

    // Export the key so we can save it (encrypted) in Firestore
    final otkBytes = await otk.extractBytes();

    return {
      'fileBytes': secretBox.cipherText + secretBox.mac.bytes, // Combine for storage
      'nonce': base64Encode(secretBox.nonce),
      'otk': base64Encode(otkBytes), // This is the key needed to decrypt
    };
  }

  /// 9. Decrypt Binary Data
  Future<List<int>> decryptFile(List<int> encryptedBytes, String nonceBase64, String otkBase64) async {
    final nonce = base64Decode(nonceBase64);
    final otk = SecretKey(base64Decode(otkBase64));
    
    // Separate MAC (last 16 bytes) from Ciphertext
    // Poly1305 MAC is always 16 bytes
    final macBytes = encryptedBytes.sublist(encryptedBytes.length - 16);
    final ciphertextBytes = encryptedBytes.sublist(0, encryptedBytes.length - 16);
    
    final secretBox = SecretBox(
      ciphertextBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    return await _chacha.decrypt(
      secretBox,
      secretKey: otk,
    );
  }

  // =========================================================
  // ✨ KEY BACKUP & RECOVERY (Passphrase Wrapping)
  // =========================================================

  /// 10. Backup Master Key (Wrap with Passphrase)
  /// Derives a key from the passphrase using Argon2id and encrypts the CMK.
  Future<Map<String, dynamic>> backupMasterKey(String passphrase) async {
    if (_cachedCoupleMasterKey == null) throw Exception("No Master Key loaded to backup!");

    // A. Generate a random salt
    final salt = _chacha.newNonce();

    // B. Derive Key from Passphrase using Argon2id
    final argon2id = Argon2id(
      parallelism: 1,
      memory: 65536, // 64 MB
      iterations: 2,
      hashLength: 32,
    );

    final secretKey = await argon2id.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    // C. Encrypt the CMK with the derived key
    final cmkBytes = await _cachedCoupleMasterKey!.extractBytes();
    final nonce = _chacha.newNonce();
    
    final secretBox = await _chacha.encrypt(
      cmkBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    debugPrint("🔐 [Encryption] Master Key backup created");

    // Return the blob to be uploaded to Firestore
    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'salt': base64Encode(salt),
      'version': 1, // To support future algo changes
    };
  }

  /// 11. Restore Master Key (Unwrap with Passphrase)
  Future<void> restoreMasterKey(String coupleId, String passphrase, Map<String, dynamic> backupBlob) async {
    final salt = base64Decode(backupBlob['salt']);
    final ciphertext = base64Decode(backupBlob['ciphertext']);
    final nonce = base64Decode(backupBlob['nonce']);
    final mac = base64Decode(backupBlob['mac']);

    // A. Derive Key from Passphrase (MUST match backup params)
    final argon2id = Argon2id(
      parallelism: 1,
      memory: 65536,
      iterations: 2,
      hashLength: 32,
    );

    final secretKey = await argon2id.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    // B. Decrypt the CMK
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    final cmkBytes = await _chacha.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    // C. Save the restored key locally
    await _storage.write(key: 'cmk_$coupleId', value: base64Encode(cmkBytes));
    _cachedCoupleMasterKey = SecretKey(cmkBytes);

    // D. Signal Ready
    if (!_cmkReadyCompleter.isCompleted) {
       _cmkReadyCompleter.complete();
    }
    _isReadyController.add(true);
    
    debugPrint("✅ [Encryption] Master Key Restored from Backup!");
  }

  
}