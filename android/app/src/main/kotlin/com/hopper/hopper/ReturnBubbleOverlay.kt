package com.hopper.hopper

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.ImageView
import kotlin.math.abs

/**
 * Floating "return to Hoppr" bubble shown on top of Google Maps while the driver
 * navigates (Uber / Ola style). Rendered natively via [WindowManager] so it
 * survives the activity being backgrounded; the foreground location service keeps
 * the process alive. The bubble is a semi-transparent app icon the driver can
 * drag anywhere; a tap brings Hoppr back to the front.
 *
 * Guarded by the "Display over other apps" permission ([Settings.canDrawOverlays]);
 * if that is not granted, [show] is a safe no-op so navigation is never blocked.
 */
object ReturnBubbleOverlay {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bubbleView: View? = null

    fun hasPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            // Pre-23: SYSTEM_ALERT_WINDOW is granted at install time.
            true
        }
    }

    /** Add the bubble if permitted and not already shown. Idempotent. */
    fun show(context: Context) {
        mainHandler.post { showInternal(context.applicationContext) }
    }

    /** Remove the bubble if present. Idempotent. */
    fun hide(context: Context) {
        mainHandler.post { hideInternal(context.applicationContext) }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showInternal(context: Context) {
        if (!hasPermission(context)) return
        if (bubbleView != null) return

        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        val density = context.resources.displayMetrics.density
        val sizePx = (56 * density).toInt() // ~56dp diameter chip

        val icon = ImageView(context).apply {
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            // "Lite opacity" look requested: a translucent floating icon.
            alpha = 0.6f
            // Subtle round backdrop so the icon reads against busy map tiles.
            setBackgroundResource(R.drawable.return_bubble_bg)
            val pad = (6 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }

        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (12 * density).toInt()
            y = (120 * density).toInt()
        }

        attachDragAndTap(wm, icon, params, context)

        try {
            wm.addView(icon, params)
            bubbleView = icon
        } catch (_: Exception) {
            bubbleView = null
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachDragAndTap(
        wm: WindowManager,
        view: View,
        params: WindowManager.LayoutParams,
        context: Context,
    ) {
        val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX)
                    val dy = (event.rawY - downY)
                    if (!dragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        dragging = true
                    }
                    if (dragging) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        try {
                            wm.updateViewLayout(view, params)
                        } catch (_: Exception) {
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragging) bringAppToFront(context)
                    true
                }
                else -> false
            }
        }
    }

    private fun bringAppToFront(context: Context) {
        try {
            val launch = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
                context.startActivity(launch)
            }
        } catch (_: Exception) {
        }
    }

    private fun hideInternal(context: Context) {
        val view = bubbleView ?: return
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        try {
            wm?.removeView(view)
        } catch (_: Exception) {
        }
        bubbleView = null
    }
}
