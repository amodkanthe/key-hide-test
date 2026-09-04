import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SignatureVault AES-256-GCM + PBKDF2 decryption and tamper verification', () async {
    const rawSecret = 'sk_sigvault_5555555555_secret_ghi789';
    const genuineCert = 'f0143ceae7de1b0948075ffc05c02dbfc68401460ef272b0da05daab6a72aeda';
    const attackerCert = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

    final dynamicSalt = List<int>.generate(24, (i) => ((i * 37 + 109) ^ 0x5A) & 0xFF);
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);
    final aes = AesGcm.with256bits();

    // 1. Encrypt bound to genuineCert
    final keyGenuine = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(genuineCert)),
      nonce: dynamicSalt,
    );
    final box = await aes.encrypt(utf8.encode(rawSecret), secretKey: keyGenuine);

    // 2. Decrypt with genuine key -> Should succeed
    final decryptedBytes = await aes.decrypt(box, secretKey: keyGenuine);
    final decrypted = utf8.decode(decryptedBytes);
    expect(decrypted, equals(rawSecret));

    // 3. Attempt decrypt with attacker's key -> Decryption MUST fail (MAC verification failure)
    final keyAttacker = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(attackerCert)),
      nonce: dynamicSalt,
    );

    expect(
      () async => await aes.decrypt(box, secretKey: keyAttacker),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
