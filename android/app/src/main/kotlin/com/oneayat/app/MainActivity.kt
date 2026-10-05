package com.oneayat.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var launchAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchAction = intent?.getStringExtra(OneAyatWidgetProvider.EXTRA_ACTION)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oneayat/timezone",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getTimeZone") {
                result.success(TimeZone.getDefault().id)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oneayat/launch",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getLaunchAction") {
                result.success(launchAction)
                launchAction = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchAction = intent.getStringExtra(OneAyatWidgetProvider.EXTRA_ACTION)
    }
}
