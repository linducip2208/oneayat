// Home-screen widget glue (home_widget). Lightweight daily update.
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String androidProvider = 'OneAyatWidgetProvider';

  static Future<void> updateDaily({
    required String arabic,
    required String ref, // e.g. "QS. Al-Insyirah : 5"
  }) async {
    try {
      await HomeWidget.saveWidgetData('ayat_arabic', arabic);
      await HomeWidget.saveWidgetData('ayat_ref', ref);
      await HomeWidget.updateWidget(androidName: androidProvider);
    } catch (e) {
      debugPrint('Widget update skipped: $e');
    }
  }
}
