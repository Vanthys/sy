import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionUtils {
  /// Derives a 32-byte (256-bit) AES key from a given PIN or passphrase.
  /// We use SHA-256 to expand/hash the PIN into exactly 32 bytes safely.
  static enc.Key _deriveKey(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return enc.Key(digest.bytes as Uint8List);
  }

  /// Encrypts plain text using AES-256-GCM.
  /// The PIN acts as the encryption key.
  static String encryptText(String plainText, String pin) {
    if (plainText.isEmpty) return plainText;

    final key = _deriveKey(pin);
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
  /// If the PIN is wrong, this will throw an exception (or return a fallback).
  static String? decryptText(String combinedCipher, String pin) {
    if (combinedCipher.isEmpty) return combinedCipher;
    if (!combinedCipher.contains(':')) return null; // Not our format

    try {
      final parts = combinedCipher.split(':');
      if (parts.length != 2) return null;

      final iv = enc.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];

      final key = _deriveKey(pin);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      return encrypter.decrypt64(ciphertext, iv: iv);
    } catch (e) {
      // Decryption failed (wrong PIN or corrupt data)
      return null;
    }
  }
}
