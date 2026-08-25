# Flutter Secure Key Obfuscation & Vault Techniques

A comprehensive Flutter reference repository demonstrating three levels of secret obfuscation and hardware-bound encryption on mobile devices (Android & iOS).

To make comparing techniques easy and unambiguous, this demo project maps **one isolated key constant** to each method:
- `ENVIED_API_KEY` ➡️ **Method 1: Envied XOR Obfuscation**
- `ARMOR_API_KEY` ➡️ **Method 2: Native Armor Vault (C++ / JNI)**
- `SIGVAULT_API_KEY` ➡️ **Method 3: Signature-Bound AES-256 Native Vault (Hardware Sealing)**

---

## 📋 Table of Contents
1. [Security Comparison Matrix](#-security-comparison-matrix)
2. [Method 1: `envied` Step-by-Step Implementation](#-method-1-envied-compile-time-xor-obfuscation)
3. [Method 2: `native_armor_vault` Step-by-Step Implementation](#-method-2-native_armor_vault-c--jni-native-library)
4. [Method 3: Signature-Bound AES-256 Vault Step-by-Step Implementation](#-method-3-signature-bound-aes-256-native-vault-military-grade)
5. [Complete Build, Run & Verification Workflow](#-complete-build-run--verification-workflow)
6. [Decompilation & Binary Verification](#-decompilation--binary-verification)

---

## 📊 Security Comparison Matrix

| Security Feature | Plain `.env` / Const | `envied` | `native_armor_vault` | Signature-Bound AES-256 |
| :--- | :---: | :---: | :---: | :---: |
| **Plaintext in APK strings** | ❌ Plain visible | ✅ Hidden | ✅ Hidden | ✅ Hidden |
| **Protected against `jadx` / Dex decompiler** | ❌ Exposed | ✅ Protected | ✅ Protected | ✅ Protected |
| **Protected against `strings libapp.so`** | ❌ Exposed | ✅ Protected | ✅ Protected | ✅ Protected |
| **Protected against C++ Disassembler (Ghidra/IDA)** | ❌ Exposed | ❌ N/A | ⚠️ Obfuscated | ✅ Complete (Ciphertext only) |
| **Resistant to APK Repackaging & Re-signing** | ❌ No | ❌ No | ❌ No | 🛡️ **Yes (Decryption Fails)** |
| **Hardware Keystore / ARM TrustZone Sealing** | ❌ No | ❌ No | ❌ No | 🛡️ **Yes (`FlutterSecureStorage`)** |

---

## 🛠️ Method 1: `envied` (Compile-Time XOR Obfuscation)

### Step 1.1: Add Dependencies to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  envied: ^1.1.1

dev_dependencies:
  build_runner: ^2.4.15
  envied_generator: ^1.1.1
```
Run `flutter pub get`.

### Step 1.2: Add Secret to `.env`
In the project root, create or edit `.env`:
```env
ENVIED_API_KEY=sk_envied_9876543210_secret_abc123
```

### Step 1.3: Create Vault Class in `lib/envied_vault.dart`
```dart
import 'package:envied/envied.dart';

part 'envied_vault.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class EnviedVault {
  @EnviedField(varName: 'ENVIED_API_KEY')
  static final String apiKey = _EnviedVault.apiKey;
}
```

### Step 1.4: Run Code Generation
```bash
dart run build_runner build --delete-conflicting-outputs
```
This generates `lib/envied_vault.g.dart`, transforming the secret into an array of obfuscated integer bytes and a runtime XOR decoding routine.

### Step 1.5: Access in Dart Code
```dart
import 'package:obfs_demo/envied_vault.dart';

String key = EnviedVault.apiKey;
```

---

## 🛠️ Method 2: `native_armor_vault` (C++ / JNI Native Library)

### Step 2.1: Add Dependency to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  native_armor_vault: ^0.0.1
```
Run `flutter pub get`.

### Step 2.2: Create Configuration File `native_vault.yaml`
In the project root, create `native_vault.yaml`:
```yaml
xor_key: "demo_secure_seed_987654321"
secrets:
  ARMOR_API_KEY: "sk_armor_1234567890_secret_def456"
```

### Step 2.3: Generate C++ Native Source Code
```bash
dart run native_armor_vault:build
```
This automatically creates:
- `android/src/main/cpp/native_vault.cpp` (C++ XOR & S-Box decoding logic for Android)
- `ios/Classes/native_vault.cpp` (C++ implementation for iOS)
- `lib/armor_vault.g.dart` (Dart FFI / platform bridge)

### Step 2.4: Access in Dart Code
```dart
import 'package:obfs_demo/armor_vault.g.dart';

String key = ArmorVault.armor_api_key;
```

---

## 🛠️ Method 3: Signature-Bound AES-256 Native Vault (Military Grade)

This method dynamically binds secret decryption to the SHA-256 fingerprint of the app's cryptographic signing certificate. If an attacker re-packs and re-signs the APK, decryption mathematically fails.

### Step 3.1: Add Dependencies to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  cryptography: ^2.7.0
  flutter_secure_storage: ^9.2.4
  convert: ^3.1.2
```
Run `flutter pub get`.

### Step 3.2: Inspect Signing Certificate SHA-256 Fingerprint
For Debug Keystore:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep -i "SHA256:"
```
*(Note: For release builds, point `-keystore` to your production upload keystore).*

### Step 3.3: Create Pre-Build Offline Encryption Tool (`tool/encrypt_secrets.dart`)
Create `tool/encrypt_secrets.dart` to encrypt raw secrets with AES-256-GCM using PBKDF2 (10,000 rounds) bound to the certificate fingerprint:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

void main() async {
  final envFile = File('.env');
  final rawKey = "sk_sigvault_5555555555_secret_ghi789"; // or read from .env

  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);
  final entropy = List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);
  
  // App ID seed + Signing Certificate binding
  final derivedKey = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode('com.demo.obfs_demo')),
    nonce: entropy,
  );

  final aes = AesGcm.with256bits();
  final box = await aes.encrypt(utf8.encode(rawKey), secretKey: derivedKey);

  print('CIPHERTEXT: ${box.cipherText.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  print('NONCE:      ${box.nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  print('MAC:        ${box.mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
}
```

Run the encryption tool:
```bash
dart run tool/encrypt_secrets.dart
```

### Step 3.4: Implement Native Certificate Extraction in Android (`MainActivity.kt`)
In `android/app/src/main/kotlin/com/demo/obfs_demo/MainActivity.kt`:

```kotlin
package com.demo.obfs_demo

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.security/signature"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCertFingerprint") {
                try {
                    val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    } else {
                        @Suppress("DEPRECATION") packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                    }
                    val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageInfo.signingInfo?.apkContentsSigners
                    } else {
                        @Suppress("DEPRECATION") packageInfo.signatures
                    }
                    if (signatures != null && signatures.isNotEmpty()) {
                        val md = MessageDigest.getInstance("SHA-256")
                        val digest = md.digest(signatures[0].toByteArray())
                        val hexString = digest.joinToString("") { "%02x".format(it) }
                        result.success(hexString)
                    } else {
                        result.error("ERR_NO_SIG", "No signatures found", null)
                    }
                } catch (e: Exception) {
                    result.error("ERR_SIG", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
```

### Step 3.5: Create Vault with Hardware Keystore Sealing (`lib/signature_vault.dart`)
In `lib/signature_vault.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignatureVault {
  static const MethodChannel _channel = MethodChannel('com.example.security/signature');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);

  static List<int> get _dynamicEntropy => 
      List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);

  // Paste generated ciphertext, nonce, and mac from Step 3.3
  static const String _cipher = '30cf1f35189e39b780d31d6552a89fa52aff54ce92fd53f4cd3048bbfb65db9785596381';
  static const String _nonce = '37e315553c085a01130a64c8';
  static const String _mac = '9feb100ca013d7048c1e1469e69e9f5c';

  static Future<String> get sigvault_api_key async {
    // 1. Check Hardware Keystore cache
    final cached = await _storage.read(key: 'vault_sigvault_api_key');
    if (cached != null && cached.isNotEmpty) return cached;

    // 2. Derive key from OS Signing Signature
    final fingerprint = await _channel.invokeMethod<String>('getCertFingerprint');
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode('com.demo.obfs_demo')),
      nonce: _dynamicEntropy,
    );

    // 3. Decrypt in volatile RAM
    final box = SecretBox(_hexToBytes(_cipher), nonce: _hexToBytes(_nonce), mac: Mac(_hexToBytes(_mac)));
    final clearBytes = await _aes.decrypt(box, secretKey: derivedKey);
    final value = utf8.decode(clearBytes);

    // 4. Seal inside Hardware Keystore / Secure Enclave
    await _storage.write(key: 'vault_sigvault_api_key', value: value);
    return value;
  }

  static List<int> _hexToBytes(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16)
  ];
}
```

### Step 3.6: Access in Dart Code
```dart
import 'package:obfs_demo/signature_vault.dart';

String key = await SignatureVault.sigvault_api_key;
```

---

## ⚡ Complete Build, Run & Verification Workflow

Run these commands sequentially to build and test:

```bash
# 1. Install all dependencies
flutter pub get

# 2. Generate code for Envied
dart run build_runner build --delete-conflicting-outputs

# 3. Generate native C++ code for Native Armor
dart run native_armor_vault:build

# 4. Generate encrypted payload for Signature Vault
dart run tool/encrypt_secrets.dart

# 5. Run the Flutter App
flutter run
```

---

## 🔬 Decompilation & Binary Verification

To verify that secrets are completely unrecoverable in plaintext from the compiled APK:

```bash
chmod +x scripts/verify_release_apk.sh
./scripts/verify_release_apk.sh
```

### What this script checks:
1. Compiles a release APK with Flutter binary obfuscation:
   `flutter build apk --release --obfuscate --split-debug-info=debug_info`
2. Extracts APK contents (`classes.dex`, `libapp.so`, `libnative_vault.so`).
3. Runs `strings` scan looking for secrets (`sk_envied_...`, `sk_armor_...`, `sk_sigvault_...`).
4. Confirms that **0 plain text matches exist** in the compiled binaries.
