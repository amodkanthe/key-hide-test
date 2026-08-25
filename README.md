# Flutter Secure Key Obfuscation & Vault Techniques

A Flutter project demonstrating three key hiding and security techniques for API keys and secrets on mobile (Android & iOS).

To illustrate each approach clearly, this project maps **one isolated key constant** to each method:
- `ENVIED_API_KEY` ➡️ **Envied XOR Obfuscation**
- `ARMOR_API_KEY` ➡️ **Native Armor Vault (C++ / JNI)**
- `SIGVAULT_API_KEY` ➡️ **Signature-Bound AES-256 Native Vault**

---

## 🛡️ Implementation Details for Each Method

### Method 1: `envied` (Compile-Time XOR Obfuscation)

#### 1. How It Works
- At compile time, `build_runner` reads the key from `.env`.
- Instead of generating a plain string literal in Dart, it breaks the string into byte chunks and XORs them with randomized integer keys (`_enviedkey...`).
- At runtime, when `EnviedVault.apiKey` is accessed, it executes a small bitwise loop (`List.generate(...)`) in Dart memory to decode the bytes into the final string.

#### 2. Key Files & Configuration
- **Configuration**: `.env`
  ```env
  ENVIED_API_KEY=sk_envied_9876543210_secret_abc123
  ```
- **Definition** (`lib/envied_vault.dart`):
  ```dart
  import 'package:envied/envied.dart';
  part 'envied_vault.g.dart';

  @Envied(path: '.env', obfuscate: true)
  abstract class EnviedVault {
    @EnviedField(varName: 'ENVIED_API_KEY')
    static final String apiKey = _EnviedVault.apiKey;
  }
  ```
- **Generated Code** (`lib/envied_vault.g.dart`):
  ```dart
  final class _EnviedVault {
    static const List<int> _enviedkeyapiKey = [
      138, 143, 237, 237, 248, ...
    ];
    static final String apiKey = String.fromCharCodes(
      List.generate(_enviedkeyapiKey.length, (i) => _enviedkeyapiKey[i] ^ _key[i % _key.length])
    );
  }
  ```

#### 3. Security Analysis
- ✅ **Bytecode Safety**: Running `strings` on `libapp.so` will not reveal `sk_envied_...` in plaintext.
- ⚠️ **Limitations**: The XOR keys and decoding algorithm are embedded within the Dart bytecode. A dedicated reverse engineer can extract the integer array and XOR key with a disassembler or Dart memory hook (Frida).

---

### Method 2: `native_armor_vault` (Native C++ / JNI Bridge)

#### 1. How It Works
- The CLI tool `native_armor_vault:build` compiles your secrets into C++ source files (`native_vault.cpp`) for Android and iOS.
- The secrets are obfuscated inside C++ using rotating XOR keys and S-box lookup tables.
- The C++ files are compiled by NDK/CMake into native shared libraries (`.so` on Android, Framework on iOS).
- Flutter accesses the secret through `dart:ffi` / Platform Channels at runtime.

#### 2. Key Files & Configuration
- **Configuration** (`native_vault.yaml`):
  ```yaml
  xor_key: "demo_secure_seed_987654321"
  secrets:
    ARMOR_API_KEY: "sk_armor_1234567890_secret_def456"
  ```
- **Native Implementation** (`android/src/main/cpp/native_vault.cpp` & `ios/Classes/native_vault.cpp`):
  ```cpp
  #include <string>
  // Obfuscated byte sequence and unmasking routine in C++
  extern "C" const char* get_armor_api_key() {
      // Reconstitutes key in native heap/stack
      return decrypted_key;
  }
  ```
- **Dart Bridge** (`lib/armor_vault.g.dart` & `lib/native_armor_vault.dart`):
  ```dart
  class ArmorVault {
    static String get armor_api_key => _native_get_armor_api_key();
  }
  ```

#### 3. Security Analysis
- ✅ **No Dart/Java Footprint**: Keys are absent from `libapp.so`, `classes.dex`, and Java/Kotlin decompilers (Jadx).
- ✅ **High Reverse Engineering Barrier**: Requires disassembly and decompilation of ARM ELF binaries using tools like Ghidra or IDA Pro.
- ⚠️ **Limitations**: Static reverse engineering of the `.so` binary is still possible with sufficient effort because the key and unmasking logic reside in the binary.

---

### Method 3: Signature-Bound AES-256 Native Vault (Highest Security)

#### 1. How It Works
This technique prevents static extraction **and** APK re-packaging/tampering:
1. **Pre-build Encryption**: Secrets are encrypted using **AES-256-GCM** offline (`tool/encrypt_secrets.dart`). The encryption key is mathematically derived using PBKDF2 (10,000 rounds) bound to the SHA-256 fingerprint of the authorized signing certificate.
2. **Zero Plaintext**: Only ciphertext hex, nonce, and authentication tag are placed into the source code.
3. **Runtime Native Verification**:
   - Flutter requests the signing certificate SHA-256 from the Android kernel via `MethodChannel` (`MainActivity.kt`).
   - Android queries `PackageManager.getPackageInfo(..., GET_SIGNING_CERTIFICATES)` to obtain the authentic active signing certificate.
4. **Hardware Keystore Sealing**:
   - Once decrypted in memory, the secret is cached in hardware-backed storage (**Android Keystore / ARM TrustZone** or **iOS Secure Enclave** via `flutter_secure_storage`).

#### 2. Key Files & Implementation

- **1. Offline Cryptographic Tool** (`tool/encrypt_secrets.dart`):
  Reads `.env`, computes the SHA-256 key from the keystore, runs PBKDF2 + AES-GCM, and prints/generates ciphertext blocks:
  ```bash
  dart run tool/encrypt_secrets.dart
  ```

- **2. Native Android Verification** (`android/app/src/main/kotlin/com/demo/obfs_demo/MainActivity.kt`):
  ```kotlin
  MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.security/signature")
      .setMethodCallHandler { call, result ->
          if (call.method == "getCertFingerprint") {
              val packageInfo = packageManager.getPackageInfo(
                  packageName, 
                  PackageManager.GET_SIGNING_CERTIFICATES
              )
              val signatures = packageInfo.signingInfo?.apkContentsSigners
              val md = MessageDigest.getInstance("SHA-256")
              val digest = md.digest(signatures[0].toByteArray())
              result.success(digest.joinToString("") { "%02x".format(it) })
          }
      }
  ```

- **3. Dart Vault & Hardware Sealing** (`lib/signature_vault.dart`):
  ```dart
  class SignatureVault {
    static const MethodChannel _channel = MethodChannel('com.example.security/signature');
    static const FlutterSecureStorage _storage = FlutterSecureStorage();
    static final AesGcm _aes = AesGcm.with256bits();

    static Future<String> get sigvault_api_key async => _getOrDecrypt(
      'sigvault_api_key', 
      _cipher_sigvault_api_key, 
      _nonce_sigvault_api_key, 
      _mac_sigvault_api_key
    );

    static Future<String> _getOrDecrypt(String key, String c, String n, String m) async {
      // 1. Hardware Keystore / Secure Enclave cache
      final cached = await _storage.read(key: 'vault_$key');
      if (cached != null && cached.isNotEmpty) return cached;

      // 2. Derive key from OS Signing Certificate + PBKDF2
      final derivedKey = await _getDerivedKey();
      final box = SecretBox(_hexToBytes(c), nonce: _hexToBytes(n), mac: Mac(_hexToBytes(m)));
      final clearBytes = await _aes.decrypt(box, secretKey: derivedKey);
      final value = utf8.decode(clearBytes);

      // 3. Seal inside Android Keystore / iOS Keychain
      await _storage.write(key: 'vault_$key', value: value);
      return value;
    }
  }
  ```

#### 3. Security Analysis
- 🛡️ **Anti-Tamper & Anti-Cloning**: If an attacker decompiles the app, modifies it, and re-signs it with a custom keystore, the OS certificate SHA-256 fingerprint will not match the encryption key. AES-GCM decryption will fail (`Mac validation failed`), completely neutralizing key theft.
- 🛡️ **Zero Binary Plaintext**: No plaintext bytes, XOR patterns, or constant tables exist in `libapp.so`, `classes.dex`, or native `.so` files.
- 🛡️ **Hardware Security**: Sealing the secret in the Android Keystore / ARM TrustZone prevents subsequent memory snooping.

---

## 📊 Security Comparison Matrix

| Security Feature | Plain `.env` / Const | `envied` | `native_armor_vault` | Signature-Bound AES-256 |
| :--- | :---: | :---: | :---: | :---: |
| **Plaintext in APK strings** | ❌ Visible | ✅ Hidden | ✅ Hidden | ✅ Hidden |
| **Protected against `jadx` / Dex decompiler** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Protected against `libapp.so` strings inspection** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Protected against C++ Disassembly (Ghidra/IDA)** | ❌ No | ❌ No | ⚠️ Obfuscated | ✅ Complete (Ciphertext Only) |
| **Tamper & Re-signing Resistance** | ❌ None | ❌ None | ❌ None | 🛡️ **Fails if re-signed** |
| **Hardware Keystore / Secure Enclave Sealing** | ❌ No | ❌ No | ❌ No | 🛡️ **Yes (ARM TrustZone / Keystore)** |

---

## 🚀 How to Run & Build

### 1. Prerequisites
Ensure Flutter and Dart SDK are installed.

### 2. Setup Configuration
```bash
# Configuration files are provided in the repo:
# - .env (for Envied & Signature Vault)
# - native_vault.yaml (for Native Armor Vault)
```

### 3. Generate Code
```bash
# 1. Generate Envied code
dart run build_runner build --delete-conflicting-outputs

# 2. Generate Native Armor C++ code
dart run native_armor_vault:build

# 3. Encrypt Secrets for Signature Vault
dart run tool/encrypt_secrets.dart
```

### 4. Run the Demo App
```bash
flutter run
```

---

## 🔬 Decompilation & Verification Script

Run the automated verification script to compile a release APK and verify that no secret strings are exposed in plain text:

```bash
chmod +x scripts/verify_release_apk.sh
./scripts/verify_release_apk.sh
```

The script inspects:
1. Java / Kotlin bytecode in `classes.dex`
2. Dart AOT compiled binary in `libapp.so`
3. Native C++ shared library in `libnative_vault.so`
