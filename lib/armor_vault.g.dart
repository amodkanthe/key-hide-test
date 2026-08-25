// GENERATED CODE - DO NOT MODIFY BY HAND
// native_armor_vault v2.0.3
// Security: DISABLED (Development mode)
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// ArmorVault v2.0.3 - Production Ready Secret Storage
class ArmorVault {
  static final DynamicLibrary _lib = _loadLibrary();

  static DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libnative_armor_vault.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }

  /// ARMOR_API_KEY
  static String get armor_api_key {
    final func = _lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('_Z7_mjp36e79b6v');
    final pointer = func.asFunction<Pointer<Utf8> Function()>()();
    final secret = pointer.toDartString();
    
    return secret;
  }

}
