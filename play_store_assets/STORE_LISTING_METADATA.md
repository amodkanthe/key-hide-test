# Google Play Store Listing Copy & Metadata

This folder contains all required visual assets and metadata fields needed to complete your Google Play Console store listing.

---

## 1. Store Listing Text Fields

### App Name (max 30 characters)
```text
Obfs Demo — Key Vault
```
*(Character count: 21 / 30)*

### Short Description (max 80 characters)
```text
Signature-bound cryptographic key protection and runtime SHA-256 diagnostics.
```
*(Character count: 77 / 80)*

### Full Description (max 4,000 characters)
```text
Obfs Demo is a security testing and demonstration application showcasing advanced signature-bound cryptographic key protection for Android and Flutter applications.

KEY FEATURES & CAPABILITIES:

1. Runtime Signature Binding (SHA-256)
API keys and sensitive payloads are encrypted at build time and can only be decrypted in memory when the executing APK's signing certificate matches the expected cryptographic fingerprint.

2. Google Play App Signing Compatibility
Demonstrates dual-mode key derivation, enabling developers to test seamlessly with local debug keystores while deploying securely through Google Play's App Signing infrastructure.

3. Live Certificate Diagnostics
Real-time inspection panel displaying active certificate SHA-256 fingerprints, Subject Distinguished Name (DN), signing lineage (Android 9+ SigningInfo API), and tamper detection status.

4. Zero-Trust Storage
No plaintext credentials or hardcoded keys remain inside the decompiled APK binary or DEX bytecode.

5. In-Memory Security
Payloads are decrypted strictly into transient memory on-demand and cleared from RAM when no longer needed.

Built for security researchers, mobile developers, and QA engineers validating Play Integrity and anti-reverse-engineering workflows.
```

---

## 2. Categorization & Contact Details

- **Application Type:** App
- **Category:** Tools / Developer Tools (or Productivity)
- **Tags:** Security, Developer Tools, Cryptography, Testing
- **Contact Email:** your-developer-email@example.com

---

## 3. Privacy Policy & Permissions

- **Permissions Requested:** None (no INTERNET permission required for core vault test, no camera, no location).
- **Data Safety Declaration:** 
  - Does your app collect or share user data? **No**
  - All cryptographic operations and diagnostics run 100% offline and locally on the device.
- **Privacy Policy URL:** (If required by Play Console, you can link a standard static GitHub Pages or Notion privacy statement stating zero data collection).

---

## 4. Visual Assets Inventory (in this folder)

| File | Dimension | Purpose | Status |
|---|---|---|---|
| `icon_512x512.png` | 512 x 512 | App Icon (Play Store Listing) | Required ✅ |
| `feature_graphic_1024x500.png` | 1024 x 500 | Feature Graphic (Top Banner) | Required ✅ |
| `screenshot_phone_1.png` | 1080 x 2400 | Phone Screenshot #1 (Signature Security) | Required ✅ |
| `screenshot_phone_2.png` | 1080 x 2400 | Phone Screenshot #2 (Play App Signing & Logs) | Required ✅ |
| `screenshot_tablet_7in.png` | 1200 x 1920 | 7-inch Tablet Screenshot | Optional / Ready ✅ |
| `screenshot_tablet_10in.png` | 1600 x 2560 | 10-inch Tablet Screenshot | Optional / Ready ✅ |
