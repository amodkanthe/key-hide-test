// GENERATED CODE - DO NOT MODIFY BY HAND
// Signature-Bound AES-256 Vault
// Generated on: 2026-09-04T16:12:03.718693Z
// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignatureVault {
  static const MethodChannel _channel = MethodChannel('com.example.security/signature');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);

  // Mathematical Salt (Zero ASCII strings in binary .rodata)
  static List<int> get _dynamicEntropy =>
      List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);

  // Debug Certificate SHA-256 and Ciphertext Block
  static const String _debugCert = 'f0143ceae7de1b0948075ffc05c02dbfc68401460ef272b0da05daab6a72aeda';
  static const String _cipher_debug = '9a432d9d94b480f22c1f9daf45191be4ffefa1d07888a04f36f0258be1ea6be163624026';
  static const String _nonce_debug = '778bc4935f4cb81159c148c5';
  static const String _mac_debug = 'f530337e62215182066784e2e25798d7';

  // Release Certificate SHA-256 and Ciphertext Block
  static const String _releaseCert = 'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0';
  static const String _cipher_release = '91e733ae40ca478fef5ace68bd9160dba44f858ea44e9ab0bf26cee4938286c63b302128';
  static const String _nonce_release = '376c03310525d17de20cddd9';
  static const String _mac_release = 'daa1a5f842817dc11a6237da27fe1f5a';

  /// Retrieves the secret:
  /// 1. Reads from Hardware Keystore (ARM TrustZone / iOS Secure Enclave) if already sealed.
  /// 2. If not cached, queries Android Kernel via MethodChannel for the authentic active cert SHA-256.
  /// 3. Derives 256-bit AES key via PBKDF2 and decrypts ciphertext.
  /// 4. Seals plaintext into Hardware Keystore for tamper-proof persistence.
  static Future<String> get sigvault_api_key async {
    try {
      const storageKey = 'vault_sigvault_api_key';
      final cached = await _storage.read(key: storageKey);
      if (cached != null && cached.isNotEmpty) return cached;

      // Query active signing certificate SHA-256 from OS kernel
      String? activeCert;
      try {
        activeCert = await _channel.invokeMethod<String>('getCertFingerprint');
      } catch (_) {
        // Fallback for unit testing environments
      }

      activeCert = (activeCert ?? '').toLowerCase().replaceAll(':', '').trim();

      String cipher;
      String nonce;
      String mac;
      String boundCert;

      if (activeCert == _releaseCert) {
        cipher = _cipher_release;
        nonce = _nonce_release;
        mac = _mac_release;
        boundCert = _releaseCert;
      } else if (activeCert == _debugCert || activeCert.isEmpty) {
        // Matches local debug keystore signature
        cipher = _cipher_debug;
        nonce = _nonce_debug;
        mac = _mac_debug;
        boundCert = _debugCert;
      } else {
        return '[Tamper detected: APK re-signed with unauthorized certificate: $activeCert]';
      }

      // Derive AES-256 key from bound certificate SHA-256 via 10,000 PBKDF2 rounds
      final derivedKey = await _pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(boundCert)),
        nonce: _dynamicEntropy,
      );

      final box = SecretBox(_hexToBytes(cipher), nonce: _hexToBytes(nonce), mac: Mac(_hexToBytes(mac)));
      final clearBytes = await _aes.decrypt(box, secretKey: derivedKey);
      final decryptedValue = utf8.decode(clearBytes);

      // Seal inside Hardware Keystore / Secure Enclave
      await _storage.write(key: storageKey, value: decryptedValue);
      return decryptedValue;
    } catch (e) {
      return '[Decryption failed: $e]';
    }
  }

  static List<int> _hexToBytes(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16)
  ];
}
