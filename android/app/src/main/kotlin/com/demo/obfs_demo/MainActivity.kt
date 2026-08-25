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
                        result.success(hexString) // Returns dynamic SHA-256 fingerprint
                    } else {
                        result.success("default_debug_keystore_hash_fallback")
                    }
                } catch (e: Exception) {
                    result.error("ERR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
