#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// v2.0.3 - Production Ready
#include "security_checks.h"
#include "crypto_utils.h"

#ifdef __cplusplus
extern "C" {
#endif

// Ephemeral Session Key (Split for anti-optimization)
static const uint8_t sk_p1[] = { 0x24, 0x61, 0x25, 0x48, 0x69, 0x75, 0x69, 0x4d, 0x33, 0x34, 0x53, 0x6b, 0x54, 0x45, 0x48, 0x59 };
static const uint8_t sk_p2[] = { 0x4c, 0x34, 0x38, 0x64, 0x36, 0x64, 0x26, 0x74, 0x6f, 0x35, 0x78, 0x5e, 0x4f, 0x23, 0x43, 0x43 };
static const uint8_t sk_p3[] = { 0x47, 0x57, 0x59, 0x58, 0x57, 0x55, 0x21, 0x4f, 0x41, 0x30, 0x35, 0x79, 0x23, 0x6c, 0x4a, 0x4a };
static const uint8_t sk_p4[] = { 0x50, 0x21, 0x47, 0x6c, 0x70, 0x55, 0x38, 0x4d, 0x65, 0x66, 0x6f, 0x46, 0x35, 0x39, 0x6c, 0x45 };
static const int session_key_len = 64;

__attribute__((noinline))
static void reconstruct_session_key(uint8_t* out) {
    volatile int idx = 0;
    for (volatile int i = 0; i < 16; i++) out[idx++] = sk_p1[i];
    for (volatile int i = 0; i < 16; i++) out[idx++] = sk_p2[i];
    for (volatile int i = 0; i < 16; i++) out[idx++] = sk_p3[i];
    for (volatile int i = 0; i < 16; i++) out[idx++] = sk_p4[i];
}

// Secret: ARMOR_API_KEY (obfuscated)
__attribute__((visibility("default"))) __attribute__((noinline))
const char* _Z7_mjp36e79b6v() {
    // Security checks disabled (development mode)
    
    // Encrypted data (multi-layer)
    static const uint8_t encrypted_data[] = {0xa1, 0xb3, 0x68, 0x92, 0x4f, 0x9b, 0x4b, 0xd7, 0xe2, 0x20, 0x30, 0x9b, 0xf4, 0x3d, 0xae, 0xc0, 0xf5, 0x7c, 0x0e, 0x32, 0xfd, 0xc2, 0x10, 0xb7, 0x3d, 0xac, 0x2c, 0xac, 0xb5, 0x0f, 0x28, 0xb5, 0x36};
    static const int data_length = 33;
    
    // Thread-local buffer for thread safety
    thread_local static char result[34];
    
    // Reconstruct session key at runtime (anti-optimization)
    uint8_t runtime_key[session_key_len];
    reconstruct_session_key(runtime_key);
    
    // Multi-layer decryption
    uint8_t temp[34];
    decrypt_multilayer(encrypted_data, temp, data_length, runtime_key, session_key_len);
    
    // Copy to result and null-terminate
    memcpy(result, temp, data_length);
    result[data_length] = '\0';
    
    return result;
}

#ifdef __cplusplus
}
#endif
