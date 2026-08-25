# Flutter Secure Key Obfuscation & Vault Techniques

A Flutter project demonstrating three key hiding and security techniques for API keys and secrets on mobile (Android & iOS).

---

## 🛡️ Techniques Implemented

### 1. `envied` (XOR Array Obfuscation)
- **Mechanism**: Reads secrets from `.env` at build-time using `build_runner` and transforms the string into an array of obfuscated integer constants decrypted in Dart memory using bitwise operations.
- **Decompilation Resistance**: Prevents plaintext string search (`strings libapp.so` won't reveal plaintext). Vulnerable to Dart runtime memory inspection or hook techniques.

### 2. `native_armor_vault` (C++ / JNI Native Library)
- **Mechanism**: Stores keys inside compiled native shared objects (`.so` / C++). Communication happens via platform channels / JNI.
- **Decompilation Resistance**: Hides keys from Java/Kotlin bytecode decompiler tools like `jadx` and standard Dart bytecode inspection.

### 3. Signature-Bound AES-256 Native Vault (Most Secure)
- **Mechanism**: 
  1. Offline tool (`dart run tool/encrypt_secrets.dart`) encrypts the raw secret using **AES-256-CBC** where the key is the **SHA-256 digest of the app's signing certificate**.
  2. The ciphertext and IV are embedded in the app.
  3. At runtime, the native layer (`MainActivity.kt` / JNI) retrieves the real package signing certificate SHA-256 directly from `PackageManager`, decrypts the ciphertext in native memory, and returns it.
- **Tamper-Proof & Anti-Cloning**: If an attacker unpacks, modifies, and re-signs the APK with their own keystore, the SHA-256 fingerprint will change, causing AES decryption to fail and yield garbage or throw an exception.

---

## 🚀 Getting Started

### 1. Setup Environment
Copy the example configuration files:
```bash
cp .env.example .env
cp native_vault.example.yaml native_vault.yaml
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Generate Code
Generate `envied` obfuscated classes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Generate `native_armor_vault` files:
```bash
dart run native_armor_vault:build
```

### 4. Encrypt Secrets for Signature-Bound Vault
Run the encryption tool to bind secrets to your keystore SHA-256:
```bash
dart run tool/encrypt_secrets.dart
```

---

## 🔍 Verification & Decompilation Analysis

To build a release APK and verify that no plaintext strings leak in bytecode or `.so` libraries:
```bash
chmod +x scripts/verify_release_apk.sh
./scripts/verify_release_apk.sh
```

---

## 🔒 Security Comparison

| Technique | Plaintext in APK? | Visible in `jadx`? | Visible in `libapp.so` strings? | Resistant to Re-signing/Tampering? |
| :--- | :---: | :---: | :---: | :---: |
| **Plain String / `.env`** | ❌ Yes | ❌ Yes | ❌ Yes | ❌ No |
| **`envied` (obfuscated)** | ❌ No | ✅ No | ✅ No | ❌ No |
| **`native_armor_vault`** | ❌ No | ✅ No | ⚠️ Needs Ghidra/IDA | ❌ No |
| **Signature-Bound AES-256** | ❌ No | ✅ No | ✅ No | 🛡️ **Yes (Fails if re-signed)** |
