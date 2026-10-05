// Launch action from widget buttons (oneayat/launch channel).
import 'package:flutter/services.dart';

class LaunchAction {
  static const _ch = MethodChannel('oneayat/launch');

  /// Returns pending action ('mark') once, then clears it.
  static Future<String?> consume() async {
    try {
      final v = await _ch.invokeMethod<String>('getLaunchAction');
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }
}
