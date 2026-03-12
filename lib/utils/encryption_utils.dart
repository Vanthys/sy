import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';

Future<String> _computePbkdf2(Map<String, dynamic> args) async {
  final pin = args['pin'] as String;
  final salt = args['salt'] as List<int>;

  final pbkdf2 = crypto.Pbkdf2(
    macAlgorithm: crypto.Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  final secretKey = crypto.SecretKeyData(utf8.encode(pin));
  final mac = await pbkdf2.deriveKey(
    secretKey: secretKey,
    nonce: salt,
  );
  final bytes = await mac.extractBytes();
  return base64Encode(bytes);
}

class EncryptionUtils {
  /// Generates a random 16-byte salt for PBKDF2
  static List<int> generateSalt() {
    return enc.IV.fromSecureRandom(16).bytes;
  }

  /// Hashes a PIN using PBKDF2 with the provided salt.
  /// Returns a base64 encoded string of the hash.
  static Future<String> hashPinPbkdf2(String pin, List<int> salt) async {
    return compute(_computePbkdf2, {'pin': pin, 'salt': salt});
  }

  /// Verifies a PIN against a previously hashed PBKDF2 hash.
  static Future<bool> verifyPinPbkdf2(String pin, String storedHashBase64, String saltBase64) async {
    final salt = base64Decode(saltBase64);
    final computedHash = await hashPinPbkdf2(pin, salt);
    return computedHash == storedHashBase64;
  }

  /// Derives a 32-byte (256-bit) AES key from a given PIN or passphrase.
  /// We use SHA-256 to expand/hash the PIN into exactly 32 bytes safely.
  /// (This is the legacy/existing method used to generate the ACTUAL AES key)
  static enc.Key deriveKeyFromPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return enc.Key(digest.bytes as Uint8List);
  }

  /// Encrypts plain text using AES-256-GCM.
  /// The [key] is the pre-derived AES encryption key.
  static String encryptText(String plainText, enc.Key key) {
    if (plainText.isEmpty) return plainText;

    // Use AES with GCM mode for authenticated encryption
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    // Generate a random initialization vector
    // GCM standard IV size is 12 bytes
    final iv = enc.IV.fromSecureRandom(12);

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Prepend the IV to the ciphertext so we can decrypt it later
    // Format: base64(IV) + ":" + base64(ciphertext)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts ciphertext using AES-256-GCM.
  /// If the [key] is wrong, this will throw an exception (or return a fallback).
  static String? decryptText(String combinedCipher, enc.Key key) {
    if (combinedCipher.isEmpty) return combinedCipher;
    if (!combinedCipher.contains(':')) return null; // Not our format

    try {
      final parts = combinedCipher.split(':');
      if (parts.length != 2) return null;

      final iv = enc.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      return encrypter.decrypt64(ciphertext, iv: iv);
    } catch (e) {
      // Decryption failed (wrong PIN or corrupt data)
      return null;
    }
  }
}
