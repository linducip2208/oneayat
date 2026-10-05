package com.oneayat.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * ONE AYAT home widget. Tap the card opens the app; the check button opens
 * the app and auto-marks today's ayat as read (via launch action).
 * Text comes from "HomeWidgetPreferences" written by Flutter (WidgetService).
 */
class OneAyatWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_MARK = "com.oneayat.app.WIDGET_MARK"
        const val EXTRA_ACTION = "oneayat_action"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, OneAyatWidgetProvider::class.java),
            )
            onUpdate(context, mgr, ids)
        }
    }

    private fun updateWidget(
        context: Context,
        mgr: AppWidgetManager,
        widgetId: Int,
    ) {
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE,
        )
        val arabic = prefs.getString("ayat_arabic", "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
            ?: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
        val ref = prefs.getString("ayat_ref", "ONE AYAT") ?: "ONE AYAT"

        val views = RemoteViews(context.packageName, R.layout.oneayat_widget)
        views.setTextViewText(R.id.ayat_arabic, arabic)
        views.setTextViewText(R.id.ayat_ref, ref)

        val open = Intent(context, MainActivity::class.java).let {
            PendingIntent.getActivity(
                context, 100, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        views.setOnClickPendingIntent(R.id.widget_root, open)

        val mark = Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_ACTION, "mark")
        }.let {
            PendingIntent.getActivity(
                context, 101, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        views.setOnClickPendingIntent(R.id.widget_mark, mark)

        mgr.updateAppWidget(widgetId, views)
    }
}
