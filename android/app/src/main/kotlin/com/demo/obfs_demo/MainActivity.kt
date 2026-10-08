package com.demo.obfs_demo

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.io.ByteArrayInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.security/signature"
    private val TAG = "SignatureVault"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                "getCertFingerprint" -> {
                    try {
                        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        Log.d(TAG, "  SignatureVault: getCertFingerprint called")
                        Log.d(TAG, "  Android SDK: ${Build.VERSION.SDK_INT} (P=${Build.VERSION_CODES.P})")
                        Log.d(TAG, "  Package: $packageName")

                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                        }

                        val signingInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.signingInfo
                        } else {
                            null
                        }

                        val signatures: Array<Signature>?
                        val signingScheme: String

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && signingInfo != null) {
                            if (signingInfo.hasMultipleSigners()) {
                                signatures = signingInfo.apkContentsSigners
                                signingScheme = "Multi-signer (apkContentsSigners)"
                            } else {
                                signatures = signingInfo.signingCertificateHistory
                                signingScheme = "Single-signer (signingCertificateHistory)"
                            }
                        } else {
                            @Suppress("DEPRECATION")
                            signatures = packageInfo.signatures
                            signingScheme = "Legacy (pre-API28 packageInfo.signatures)"
                        }

                        Log.d(TAG, "  Signing scheme used: $signingScheme")
                        Log.d(TAG, "  Number of signatures found: ${signatures?.size ?: 0}")

                        if (signatures != null && signatures.isNotEmpty()) {
                            val cert = signatures[0]

                            // Compute SHA-256 of raw certificate bytes
                            val md256 = MessageDigest.getInstance("SHA-256")
                            val sha256Bytes = md256.digest(cert.toByteArray())
                            val sha256Hex = sha256Bytes.joinToString("") { "%02x".format(it) }
                            val sha256Formatted = sha256Bytes.joinToString(":") { "%02X".format(it) }

                            // Compute SHA-1 for cross-reference
                            val md1 = MessageDigest.getInstance("SHA-1")
                            val sha1Hex = md1.digest(cert.toByteArray()).joinToString("") { "%02x".format(it) }

                            // Extract X.509 Subject DN for readability
                            val subjectDN: String = try {
                                val cf = CertificateFactory.getInstance("X.509")
                                val x509 = cf.generateCertificate(ByteArrayInputStream(cert.toByteArray())) as X509Certificate
                                x509.subjectX500Principal.name
                            } catch (e: Exception) {
                                "Unable to parse: ${e.message}"
                            }

                            Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                            Log.d(TAG, "  ✅ CERTIFICATE DETAILS:")
                            Log.d(TAG, "  Subject DN : $subjectDN")
                            Log.d(TAG, "  SHA-256    : $sha256Formatted")
                            Log.d(TAG, "  SHA-256 hex: $sha256Hex")
                            Log.d(TAG, "  SHA-1      : $sha1Hex")
                            Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                            Log.d(TAG, "  ▶ COMPARE SHA-256 hex with Play Console:")
                            Log.d(TAG, "    Play Console → App → Release → Setup")
                            Log.d(TAG, "    → App integrity → App signing key certificate → SHA-256")
                            Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                            // Return hex SHA-256 to Dart layer
                            result.success(sha256Hex)
                        } else {
                            Log.e(TAG, "  ❌ No signatures found in packageInfo")
                            result.error("ERR_NO_SIG", "No signing certificates found", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "  ❌ Exception in getCertFingerprint: ${e.message}", e)
                        result.error("ERR", e.message, null)
                    }
                }

                "getDiagnostics" -> {
                    // Returns full JSON-style diagnostic string for on-screen display
                    try {
                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                        }

                        val signingInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) packageInfo.signingInfo else null

                        val signatures: Array<Signature>?
                        val signingScheme: String

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && signingInfo != null) {
                            if (signingInfo.hasMultipleSigners()) {
                                signatures = signingInfo.apkContentsSigners
                                signingScheme = "Multi-signer"
                            } else {
                                signatures = signingInfo.signingCertificateHistory
                                signingScheme = "Single-signer"
                            }
                        } else {
                            @Suppress("DEPRECATION")
                            signatures = packageInfo.signatures
                            signingScheme = "Legacy"
                        }

                        if (signatures != null && signatures.isNotEmpty()) {
                            val cert = signatures[0]

                            val sha256 = MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())
                                .joinToString(":") { "%02X".format(it) }
                            val sha256hex = MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())
                                .joinToString("") { "%02x".format(it) }
                            val sha1 = MessageDigest.getInstance("SHA-1").digest(cert.toByteArray())
                                .joinToString(":") { "%02X".format(it) }

                            val subjectDN: String = try {
                                val cf = CertificateFactory.getInstance("X.509")
                                val x509 = cf.generateCertificate(ByteArrayInputStream(cert.toByteArray())) as X509Certificate
                                x509.subjectX500Principal.name
                            } catch (e: Exception) { "parse error" }

                            val diag = """
SDK: ${Build.VERSION.SDK_INT}
Package: $packageName
Scheme: $signingScheme
Subject: $subjectDN
SHA-256: $sha256
SHA-256 hex: $sha256hex
SHA-1: $sha1

▶ Use SHA-256 hex in .env:
RELEASE_CERT_SHA256=$sha256hex
""".trimIndent()

                            Log.d(TAG, "getDiagnostics:\n$diag")
                            result.success(diag)
                        } else {
                            result.error("ERR_NO_SIG", "No signatures found", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}

