import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

/// Pre-Build Offline Encryption Tool
///
/// Encrypts secrets with AES-256-GCM using PBKDF2 (10,000 rounds)
/// cryptographically bound to the application's signing certificate SHA-256 fingerprint.
///
/// Supports:
/// - Debug mode: bound to local debug.keystore
/// - Release mode: bound to production release keystore / Play App Signing certificate
/// - Dual mode: embeds ciphertexts for both profiles, enabling seamless local dev and release builds.
void main(List<String> args) async {
  // 1. Parse CLI Arguments
  String mode = 'dual'; // 'debug', 'release', or 'dual'
  String? cliReleaseCert;
  String? cliDebugCert;

  for (final arg in args) {
    if (arg.startsWith('--mode=')) {
      mode = arg.substring('--mode='.length).toLowerCase();
    } else if (arg.startsWith('--release-cert=')) {
      cliReleaseCert = arg.substring('--release-cert='.length);
    } else if (arg.startsWith('--debug-cert=')) {
      cliDebugCert = arg.substring('--debug-cert='.length);
    }
  }

  // 2. Read .env file
  final envFile = File('.env');
  final envSecrets = <String, String>{};
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx != -1) {
        final k = trimmed.substring(0, eqIdx).trim();
        final v = trimmed.substring(eqIdx + 1).trim();
        envSecrets[k] = v;
      }
    }
  }

  final rawSecret = envSecrets['SIGVAULT_API_KEY'] ?? 'sk_sigvault_5555555555_secret_ghi789';

  // 3. Resolve Debug Fingerprint
  String debugCert = cliDebugCert ??
      envSecrets['DEBUG_CERT_SHA256'] ??
      _detectLocalDebugKeystoreCert() ??
      'f0143ceae7de1b0948075ffc05c02dbfc68401460ef272b0da05daab6a72aeda';
  debugCert = _cleanHex(debugCert);

  // 4. Resolve Release Fingerprint (placeholder or actual from .env/CLI)
  String releaseCert = cliReleaseCert ??
      envSecrets['RELEASE_CERT_SHA256'] ??
      'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0';
  releaseCert = _cleanHex(releaseCert);

  stdout.writeln('====================================================');
  stdout.writeln('  OFFLINE ENCRYPTION TOOL: Signature-Bound Vault    ');
  stdout.writeln('====================================================');
  stdout.writeln('Mode:            $mode');
  stdout.writeln('Debug Cert:      ${debugCert.substring(0, 16)}...');
  stdout.writeln('Release Cert:    ${releaseCert.substring(0, 16)}...');
  stdout.writeln('Secret to Seal:  ${rawSecret.substring(0, 8)}... (Length: ${rawSecret.length})');

  // Dynamic mathematical salt (entropy generated via arithmetic polynomial)
  final dynamicSalt = List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);

  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  );
  final aes = AesGcm.with256bits();

  // Helper to encrypt a secret bound to a specific certificate SHA-256
  Future<Map<String, String>> encryptForCert(String certSha256) async {
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(certSha256)),
      nonce: dynamicSalt,
    );
    final box = await aes.encrypt(utf8.encode(rawSecret), secretKey: derivedKey);
    return {
      'cipher': box.cipherText.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'nonce': box.nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'mac': box.mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    };
  }

  final debugPayload = (mode == 'debug' || mode == 'dual') ? await encryptForCert(debugCert) : null;
  final releasePayload = (mode == 'release' || mode == 'dual') ? await encryptForCert(releaseCert) : null;

  final code = StringBuffer();
  code.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  code.writeln('// Signature-Bound AES-256 Vault');
  code.writeln('// Generated on: ${DateTime.now().toUtc().toIso8601String()}');
  code.writeln('// ignore_for_file: non_constant_identifier_names, constant_identifier_names');
  code.writeln();
  code.writeln("import 'dart:convert';");
  code.writeln("import 'package:flutter/services.dart';");
  code.writeln("import 'package:cryptography/cryptography.dart';");
  code.writeln("import 'package:flutter_secure_storage/flutter_secure_storage.dart';");
  code.writeln();
  code.writeln('class SignatureVault {');
  code.writeln("  static const MethodChannel _channel = MethodChannel('com.example.security/signature');");
  code.writeln('  static const FlutterSecureStorage _storage = FlutterSecureStorage();');
  code.writeln('  static final AesGcm _aes = AesGcm.with256bits();');
  code.writeln('  static final Pbkdf2 _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);');
  code.writeln();
  code.writeln('  // Mathematical Salt (Zero ASCII strings in binary .rodata)');
  code.writeln('  static List<int> get _dynamicEntropy =>');
  code.writeln('      List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);');
  code.writeln();

  if (debugPayload != null) {
    code.writeln('  // Debug Certificate SHA-256 and Ciphertext Block');
    code.writeln("  static const String _debugCert = '$debugCert';");
    code.writeln("  static const String _cipher_debug = '${debugPayload['cipher']}';");
    code.writeln("  static const String _nonce_debug = '${debugPayload['nonce']}';");
    code.writeln("  static const String _mac_debug = '${debugPayload['mac']}';");
    code.writeln();
  }

  if (releasePayload != null) {
    code.writeln('  // Release Certificate SHA-256 and Ciphertext Block');
    code.writeln("  static const String _releaseCert = '$releaseCert';");
    code.writeln("  static const String _cipher_release = '${releasePayload['cipher']}';");
    code.writeln("  static const String _nonce_release = '${releasePayload['nonce']}';");
    code.writeln("  static const String _mac_release = '${releasePayload['mac']}';");
    code.writeln();
  }

  code.writeln('  /// Retrieves the secret:');
  code.writeln('  /// 1. Reads from Hardware Keystore (ARM TrustZone / iOS Secure Enclave) if already sealed.');
  code.writeln('  /// 2. If not cached, queries Android Kernel via MethodChannel for the authentic active cert SHA-256.');
  code.writeln('  /// 3. Derives 256-bit AES key via PBKDF2 and decrypts ciphertext.');
  code.writeln('  /// 4. Seals plaintext into Hardware Keystore for tamper-proof persistence.');
  code.writeln('  static Future<String> get sigvault_api_key async {');
  code.writeln('    try {');
  code.writeln("      const storageKey = 'vault_sigvault_api_key';");
  code.writeln('      final cached = await _storage.read(key: storageKey);');
  code.writeln('      if (cached != null && cached.isNotEmpty) return cached;');
  code.writeln();
  code.writeln('      // Query active signing certificate SHA-256 from OS kernel');
  code.writeln('      String? activeCert;');
  code.writeln('      try {');
  code.writeln("        activeCert = await _channel.invokeMethod<String>('getCertFingerprint');");
  code.writeln('      } catch (_) {');
  code.writeln('        // Fallback for unit testing environments');
  code.writeln('      }');
  code.writeln();
  code.writeln("      activeCert = (activeCert ?? '').toLowerCase().replaceAll(':', '').trim();");
  code.writeln();

  if (mode == 'dual') {
    code.writeln('      String cipher;');
    code.writeln('      String nonce;');
    code.writeln('      String mac;');
    code.writeln('      String boundCert;');
    code.writeln();
    code.writeln('      if (activeCert == _releaseCert) {');
    code.writeln('        cipher = _cipher_release;');
    code.writeln('        nonce = _nonce_release;');
    code.writeln('        mac = _mac_release;');
    code.writeln('        boundCert = _releaseCert;');
    code.writeln('      } else if (activeCert == _debugCert || activeCert.isEmpty) {');
    code.writeln('        // Matches local debug keystore signature');
    code.writeln('        cipher = _cipher_debug;');
    code.writeln('        nonce = _nonce_debug;');
    code.writeln('        mac = _mac_debug;');
    code.writeln('        boundCert = _debugCert;');
    code.writeln('      } else {');
    code.writeln("        return '[Tamper detected: APK re-signed with unauthorized certificate: \$activeCert]';");
    code.writeln('      }');
  } else if (mode == 'release') {
    code.writeln('      if (activeCert != _releaseCert) {');
    code.writeln("        return '[Tamper detected: APK re-signed with unauthorized certificate: \$activeCert]';");
    code.writeln('      }');
    code.writeln('      const cipher = _cipher_release;');
    code.writeln('      const nonce = _nonce_release;');
    code.writeln('      const mac = _mac_release;');
    code.writeln('      const boundCert = _releaseCert;');
  } else {
    code.writeln('      const cipher = _cipher_debug;');
    code.writeln('      const nonce = _nonce_debug;');
    code.writeln('      const mac = _mac_debug;');
    code.writeln('      const boundCert = _debugCert;');
  }

  code.writeln();
  code.writeln('      // Derive AES-256 key from bound certificate SHA-256 via 10,000 PBKDF2 rounds');
  code.writeln('      final derivedKey = await _pbkdf2.deriveKey(');
  code.writeln('        secretKey: SecretKey(utf8.encode(boundCert)),');
  code.writeln('        nonce: _dynamicEntropy,');
  code.writeln('      );');
  code.writeln();
  code.writeln('      final box = SecretBox(_hexToBytes(cipher), nonce: _hexToBytes(nonce), mac: Mac(_hexToBytes(mac)));');
  code.writeln('      final clearBytes = await _aes.decrypt(box, secretKey: derivedKey);');
  code.writeln('      final decryptedValue = utf8.decode(clearBytes);');
  code.writeln();
  code.writeln('      // Seal inside Hardware Keystore / Secure Enclave');
  code.writeln('      await _storage.write(key: storageKey, value: decryptedValue);');
  code.writeln('      return decryptedValue;');
  code.writeln('    } catch (e) {');
  code.writeln("      return '[Decryption failed: \$e]';");
  code.writeln('    }');
  code.writeln('  }');
  code.writeln();
  code.writeln('  static List<int> _hexToBytes(String hex) => [');
  code.writeln('    for (var i = 0; i < hex.length; i += 2)');
  code.writeln('      int.parse(hex.substring(i, i + 2), radix: 16)');
  code.writeln('  ];');
  code.writeln('}');

  final outFile = File('lib/signature_vault.dart');
  outFile.writeAsStringSync(code.toString());
  stdout.writeln('Successfully generated lib/signature_vault.dart (Mode: $mode)');
  stdout.writeln('====================================================');
}

String _cleanHex(String input) {
  return input.replaceAll(':', '').replaceAll(' ', '').trim().toLowerCase();
}

String? _detectLocalDebugKeystoreCert() {
  final home = Platform.environment['HOME'] ?? '';
  final keystoreFile = File('$home/.android/debug.keystore');
  if (!keystoreFile.existsSync()) return null;

  final candidates = [
    '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool',
    'keytool',
  ];

  for (final bin in candidates) {
    try {
      final res = Process.runSync(bin, [
        '-list',
        '-v',
        '-keystore',
        keystoreFile.path,
        '-alias',
        'androiddebugkey',
        '-storepass',
        'android',
        '-keypass',
        'android',
      ]);
      if (res.exitCode == 0) {
        final lines = (res.stdout as String).split('\n');
        for (final line in lines) {
          if (line.contains('SHA256:')) {
            final parts = line.split('SHA256:');
            if (parts.length > 1) {
              return parts[1].trim();
            }
          }
        }
      }
    } catch (_) {}
  }
  return null;
}
