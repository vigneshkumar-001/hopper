package com.hopper.hopper

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.net.Uri
import android.provider.Settings

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
                    // ---- Floating "return to Hoppr" bubble over Google Maps ----
                    "hasOverlayPermission" -> {
                        result.success(ReturnBubbleOverlay.hasPermission(this))
                    }
                    "requestOverlayPermission" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                                !Settings.canDrawOverlays(this)
                            ) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "showReturnBubble" -> {
                        ReturnBubbleOverlay.show(applicationContext)
                        result.success(ReturnBubbleOverlay.hasPermission(this))
                    }
                    "hideReturnBubble" -> {
                        ReturnBubbleOverlay.hide(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        // Safety net: the moment Hoppr is back in front, the return-bubble is
        // redundant — remove it even if the Dart resume path is delayed.
        ReturnBubbleOverlay.hide(applicationContext)
    }
}
