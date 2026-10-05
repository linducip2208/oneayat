// Device IANA timezone via MainActivity MethodChannel (no extra plugin).
import 'package:flutter/services.dart';

class DeviceTimezone {
  static const _ch = MethodChannel('oneayat/timezone');

  /// Returns e.g. 'Asia/Jakarta'. Falls back to WIB on failure
  /// (majority of users; scheduling still refreshes every app start).
  static Future<String> getName() async {
    try {
      final v = await _ch.invokeMethod<String>('getTimeZone');
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return 'Asia/Jakarta';
  }
}
