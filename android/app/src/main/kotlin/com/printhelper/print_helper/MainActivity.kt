package com.printhelper.print_helper

import android.content.pm.ActivityInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)

		// Lock tablets to landscape to protect tablet-only layouts.
		if (resources.configuration.smallestScreenWidthDp >= 600) {
			requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
		} else {
			requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.printhelper.print_helper/media_scanner").setMethodCallHandler { call, result ->
			if (call.method == "scanFile") {
				val path = call.argument<String>("path")
				if (path != null) {
					MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ -> }
					result.success(true)
				} else {
					result.error("INVALID_PATH", "Path is null", null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
