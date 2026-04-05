import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:sy3/utils/encryption_utils.dart';

void main() {
  group('EncryptionUtils', () {
    late enc.Key key;

    setUp(() {
      key = EncryptionUtils.deriveKeyFromPin('test-pin-1234');
    });

    group('deriveKeyFromPin', () {
      test('is deterministic — same pin produces same key', () {
        final k1 = EncryptionUtils.deriveKeyFromPin('mypin');
        final k2 = EncryptionUtils.deriveKeyFromPin('mypin');
        expect(k1.bytes, equals(k2.bytes));
      });

      test('different pins produce different keys', () {
        final k1 = EncryptionUtils.deriveKeyFromPin('pin-a');
        final k2 = EncryptionUtils.deriveKeyFromPin('pin-b');
        expect(k1.bytes, isNot(equals(k2.bytes)));
      });

      test('key is 32 bytes (256-bit)', () {
        final k = EncryptionUtils.deriveKeyFromPin('short');
        expect(k.bytes.length, 32);
      });
    });

    group('encryptText / decryptText', () {
      test('round-trip returns original plaintext', () {
        const plain = 'Hello, world!';
        final cipher = EncryptionUtils.encryptText(plain, key);
        final restored = EncryptionUtils.decryptText(cipher, key);
        expect(restored, plain);
      });

      test('empty string passes through without modification', () {
        final cipher = EncryptionUtils.encryptText('', key);
        expect(cipher, isEmpty);
        final dec = EncryptionUtils.decryptText('', key);
        expect(dec, isEmpty);
      });

      test('ciphertext contains a colon separator (IV:data format)', () {
        final cipher = EncryptionUtils.encryptText('test', key);
        expect(cipher, contains(':'));
      });

      test('ciphertext differs on each call (random IV)', () {
        final c1 = EncryptionUtils.encryptText('same text', key);
        final c2 = EncryptionUtils.encryptText('same text', key);
        expect(c1, isNot(equals(c2)));
      });

      test('wrong key returns null', () {
        const plain = 'secret';
        final cipher = EncryptionUtils.encryptText(plain, key);
        final badKey = EncryptionUtils.deriveKeyFromPin('wrong-pin');
        final result = EncryptionUtils.decryptText(cipher, badKey);
        expect(result, isNull);
      });

      test('malformed ciphertext (no colon) returns null', () {
        final result = EncryptionUtils.decryptText('nodivider', key);
        expect(result, isNull);
      });

      test('ciphertext with three parts returns null', () {
        final result = EncryptionUtils.decryptText('a:b:c', key);
        expect(result, isNull);
      });

      test('unicode plaintext round-trips correctly', () {
        const plain = '日本語テスト 🎉';
        final cipher = EncryptionUtils.encryptText(plain, key);
        expect(EncryptionUtils.decryptText(cipher, key), plain);
      });

      test('long plaintext round-trips correctly', () {
        final plain = 'A' * 10000;
        final cipher = EncryptionUtils.encryptText(plain, key);
        expect(EncryptionUtils.decryptText(cipher, key), plain);
      });
    });

    group('hashPinPbkdf2 / verifyPinPbkdf2', () {
      test('verifyPinPbkdf2 returns true for correct pin', () async {
        final salt = EncryptionUtils.generateSalt();
        final saltBase64 = base64Encode(salt);
        final hash = await EncryptionUtils.hashPinPbkdf2('mypin', salt);
        final ok = await EncryptionUtils.verifyPinPbkdf2(
          'mypin',
          hash,
          saltBase64,
        );
        expect(ok, isTrue);
      });

      test('verifyPinPbkdf2 returns false for wrong pin', () async {
        final salt = EncryptionUtils.generateSalt();
        final saltBase64 = base64Encode(salt);
        final hash = await EncryptionUtils.hashPinPbkdf2('correctpin', salt);
        final ok = await EncryptionUtils.verifyPinPbkdf2(
          'wrongpin',
          hash,
          saltBase64,
        );
        expect(ok, isFalse);
      });
    });
  });
}
