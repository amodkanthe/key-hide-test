import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obfs_demo/signature_vault.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THREE SHA VALUES EXPLAINED
// ─────────────────────────────────────────────────────────────────────────────
// SHA_DEBUG   → ~/.android/debug.keystore   → used on flutter run / USB install
// SHA_UPLOAD  → your production .jks file   → used to upload .aab to Play Console
//               ⚠️ Google STRIPS this before delivery. NO user device ever sees it.
// SHA_PLAY    → Google's App Signing Key    → Play Console → App integrity → SHA-256
//               This is what PackageManager returns on a Play Store installed app.
//
// ONLY SHA_DEBUG and SHA_PLAY need to be in signature_vault.dart.
// SHA_UPLOAD is irrelevant at runtime.
// ─────────────────────────────────────────────────────────────────────────────

// Actual debug cert from ~/.android/debug.keystore (matches _debugCert in vault)
const kDebugSHA =
    'f0143ceae7de1b0948075ffc05c02dbfc68401460ef272b0da05daab6a72aeda';

// Simulated upload/release keystore SHA — what keytool on your .jks returns
// IMPORTANT: No user device ever reports this SHA when Play App Signing is on
const kUploadKeySHA =
    'ccddee112233445566778899aabbccdd11223344556677889900aabbccddeeff';

// Play Console App Signing SHA — matches _releaseCert in vault
// Source: Play Console → your app → Release → Setup → App integrity → SHA-256
const kPlayStoreSHA =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0';

// Completely unknown cert — attacker re-signed the APK after decompiling it
const kAttackerSHA =
    'deadbeef99999999deadbeef99999999deadbeef99999999deadbeef99999999';

const kRawSecret = 'sk_sigvault_5555555555_secret_ghi789';

// Shared crypto helpers (same algorithm as signature_vault.dart)
final _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);
final _aes = AesGcm.with256bits();
final _salt = List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);

Future<SecretBox> encryptWithCert(String certSha) async {
  final key = await _pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(certSha)),
    nonce: _salt,
  );
  return _aes.encrypt(utf8.encode(kRawSecret), secretKey: key);
}

Future<String?> tryDecryptWithCert(SecretBox box, String certSha) async {
  try {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(certSha)),
      nonce: _salt,
    );
    final bytes = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(bytes);
  } on SecretBoxAuthenticationError {
    return null; // Wrong cert → AES-GCM authentication tag mismatch
  }
}

void main() {
  // ── SECTION 1: Pure Crypto Tests ───────────────────────────────────────────
  group('SECTION 1 — Cryptographic Correctness (no device needed)', () {
    test('1a. Debug cert encrypts → same debug cert decrypts → SUCCESS', () async {
      final box = await encryptWithCert(kDebugSHA);
      final result = await tryDecryptWithCert(box, kDebugSHA);
      expect(result, equals(kRawSecret));
    });

    test('1b. Play Store cert encrypts → same Play Store cert decrypts → SUCCESS', () async {
      final box = await encryptWithCert(kPlayStoreSHA);
      final result = await tryDecryptWithCert(box, kPlayStoreSHA);
      expect(result, equals(kRawSecret));
    });

    test(
        '1c. Play Store cert encrypts → Upload Key cert tries to decrypt → FAILS\n'
        '    (PROOF: keytool on your .jks gives upload SHA, which is different from Play SHA)', () async {
      // This is THE key test. Upload SHA ≠ Play Store SHA.
      // This proves why keytool on your local .jks file gives you the WRONG cert.
      final box = await encryptWithCert(kPlayStoreSHA);
      final result = await tryDecryptWithCert(box, kUploadKeySHA);
      expect(result, isNull,
          reason:
              'Upload key SHA != Play Store SHA. They are two completely different certs. '
              'This is why you must use the SHA from Play Console, not from keytool on your .jks.');
    });

    test('1d. Debug cert encrypts → Upload Key cert tries to decrypt → FAILS', () async {
      final box = await encryptWithCert(kDebugSHA);
      final result = await tryDecryptWithCert(box, kUploadKeySHA);
      expect(result, isNull);
    });

    test('1e. Play Store cert encrypts → Attacker cert tries to decrypt → FAILS (AES-GCM auth error)', () async {
      final box = await encryptWithCert(kPlayStoreSHA);
      final result = await tryDecryptWithCert(box, kAttackerSHA);
      expect(result, isNull,
          reason: 'Even if attacker knows the algorithm, wrong cert = wrong AES key = auth failure');
    });
  });

  // ── SECTION 2: Full Runtime Tests (mocked MethodChannel) ──────────────────
  group('SECTION 2 — SignatureVault Runtime: All Real-World Scenarios', () {
    const channel = MethodChannel('com.example.security/signature');

    void mockDeviceCert(String sha) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getCertFingerprint') return sha;
        return null;
      });
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
        '2a. [flutter run / adb install] Device cert = DEBUG SHA\n'
        '    → vault matches _debugCert → decrypts _cipher_debug → SECRET ✅', () async {
      mockDeviceCert(kDebugSHA);
      final secret = await SignatureVault.sigvault_api_key;
      expect(secret, equals(kRawSecret),
          reason: 'Local debug build should work. '
              '_debugCert in vault = SHA from ~/.android/debug.keystore');
    });

    test(
        '2b. [Play Store Install] Device cert = PLAY STORE SHA (Googles key)\n'
        '    → vault matches _releaseCert → decrypts _cipher_release → SECRET ✅', () async {
      // When user downloads from Google Play:
      // Google has stripped your upload key and re-signed with their App Signing Key
      // PackageManager returns Google's SHA (what you see in Play Console → App integrity)
      FlutterSecureStorage.setMockInitialValues({});
      mockDeviceCert(kPlayStoreSHA);
      final secret = await SignatureVault.sigvault_api_key;
      expect(secret, equals(kRawSecret),
          reason: 'Play Store installed app must decrypt. '
              'RELEASE_CERT_SHA256 in .env MUST be from Play Console App integrity page, '
              'NOT from keytool on your local .jks file.');
    });

    test(
        '2c. [UPLOAD KEY at runtime — should NOT happen with Play App Signing]\n'
        '    Device cert = UPLOAD KEY SHA → vault has no entry for it → TAMPER DETECTED ⚠️\n'
        '    (FIX: only use Play Internal Testing track, never sideload the upload .aab)', () async {
      // The upload key SHA only appears at runtime if you:
      // a) Manually install an .apk built with your .jks WITHOUT going through Play Console
      // b) Have NOT enrolled in Play App Signing
      //
      // With Play App Signing enabled (the default for new apps):
      // This case NEVER occurs for real users.
      FlutterSecureStorage.setMockInitialValues({});
      mockDeviceCert(kUploadKeySHA);
      final result = await SignatureVault.sigvault_api_key;
      expect(result, contains('Tamper detected'),
          reason:
              'Upload key SHA is NOT registered. The vault correctly rejects it. '
              'To test release locally, use Play Internal Testing track instead.');
    });

    test(
        '2d. [Attacker re-signed APK] Device cert = unknown attacker SHA\n'
        '    → vault rejects immediately → TAMPER DETECTED ⚠️', () async {
      // Attacker decompiled, added malware, re-signed with their own key
      // Android forces every APK to be signed — but attacker cannot use your key
      // So their SHA is completely unknown
      FlutterSecureStorage.setMockInitialValues({});
      mockDeviceCert(kAttackerSHA);
      final result = await SignatureVault.sigvault_api_key;
      expect(result, contains('Tamper detected'));
      expect(result, contains(kAttackerSHA),
          reason: 'Tamper message includes the attacker SHA for forensics');
    });

    test(
        '2e. [Caching] Second call returns from secure storage — MethodChannel NOT called again', () async {
      FlutterSecureStorage.setMockInitialValues({});
      int channelCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getCertFingerprint') {
          channelCallCount++;
          return kDebugSHA;
        }
        return null;
      });

      final first = await SignatureVault.sigvault_api_key;
      final second = await SignatureVault.sigvault_api_key;

      expect(first, equals(kRawSecret));
      expect(second, equals(kRawSecret));
      expect(channelCallCount, equals(1),
          reason: 'Second call must come from FlutterSecureStorage, not re-decrypt');
    });
  });
}
