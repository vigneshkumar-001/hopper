package com.hopper.hopper

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.Intent
import android.net.Uri

class MainActivity: FlutterFragmentActivity() {
    private val channelName = "hopper/navigation_intents"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openGoogleMapsNavigation" -> {
                        val lat = call.argument<Double>("lat")
                        val lng = call.argument<Double>("lng")
                        if (lat == null || lng == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")

                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            // Prefer Google Maps app.
                            setPackage("com.google.android.apps.maps")

                            // Try to avoid deep Maps back-stack so a single back
                            // returns to our app more often.
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                            // Hint Maps to show "Return to <app>" bar on some devices.
                            try {
                                putExtra(
                                    "com.google.android.apps.maps.EXTRA_SOURCE_APPLICATION",
                                    packageName
                                )
                                putExtra(
                                    Intent.EXTRA_REFERRER,
                                    Uri.parse("android-app://$packageName")
                                )
                            } catch (_: Exception) {
                            }
                        }

                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            // Fallback: try without forcing package name.
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
