package com.example.autoclicker



import android.accessibilityservice.AccessibilityService

import android.accessibilityservice.AccessibilityServiceInfo

import android.app.Notification

import android.app.NotificationChannel

import android.app.NotificationManager

import android.app.PendingIntent

import android.content.Context

import android.content.Intent

import android.os.Build

import android.os.VibrationEffect

import android.os.Vibrator

import android.os.VibratorManager

import android.util.Log

import android.view.Gravity

import android.view.WindowManager

import android.widget.TextView

import android.widget.Toast

import android.widget.LinearLayout

import android.view.View

import android.view.MotionEvent

import android.graphics.Typeface

import android.graphics.drawable.GradientDrawable

import android.graphics.Color

import android.os.Handler

import android.os.Looper

import android.view.accessibility.AccessibilityEvent

import android.view.accessibility.AccessibilityNodeInfo

import androidx.core.app.NotificationCompat
import android.graphics.Bitmap
import android.graphics.ColorSpace
import android.view.Display
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.Executors
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions



// ─── App Config ───────────────────────────────────────────────────────────────

data class AppConfig(

    val packageName: String,

    val displayName: String,

    val acceptButtonKeywords: List<String>, // keywords to find accept button

    val prefKeyEnabled: String,

    val prefKeyLocation: String

)



class RapidoAutoClickService : AccessibilityService() {



    companion object {

        private const val TAG = "AutoClicker"

        const val PREFS_NAME = "AutoClickerPrefs"

        const val KEY_TOTAL_ACCEPTED = "totalAccepted"

        private const val COOLDOWN_MS = 4000L

        private const val NOTIFICATION_ID = 1001

        private const val CHANNEL_ID = "auto_clicker_channel"



        // ── All 4 App Configurations ──────────────────────────────────────────

        val APP_CONFIGS = listOf(

            AppConfig(

                packageName = "com.rapido.rider",

                displayName = "Rapido",

                // Yellow "Accept" button

                acceptButtonKeywords = listOf("accept", "ஏற்றுக்கொள்"),

                prefKeyEnabled = "enabled_rapido",

                prefKeyLocation = "location_rapido"

            ),

            AppConfig(

                packageName = "com.ubercab.driver",

                displayName = "Uber",

                // Black "Match" button (as seen in screenshot)

                acceptButtonKeywords = listOf("match"),

                prefKeyEnabled = "enabled_uber",

                prefKeyLocation = "location_uber"

            ),

            AppConfig(

                packageName = "com.azhai.partner",

                displayName = "Azhai Partner",

                // Golden "ACCEPT ORDER" button (as seen in screenshot)

                acceptButtonKeywords = listOf("accept order", "accept"),

                prefKeyEnabled = "enabled_azhai",

                prefKeyLocation = "location_azhai"

            ),

            AppConfig(

                packageName = "com.olacabs.oladriver",

                displayName = "OLA",

                // Dark grey "Accept in 5" countdown button - number changes so use "accept in"

                acceptButtonKeywords = listOf("accept in", "accept", "ஏற்றுக்கொள்"),

                prefKeyEnabled = "enabled_ola",

                prefKeyLocation = "location_ola"

            ),

            AppConfig(

                packageName = "com.zomato.delivery",

                displayName = "Zomato",

                // "Swipe to accept" slider button

                acceptButtonKeywords = listOf("swipe to accept", "swipe", "accept"),

                prefKeyEnabled = "enabled_zomato",

                prefKeyLocation = "location_zomato"

            )

        )



        var instance: RapidoAutoClickService? = null

        var onRideAccepted: ((String, String, Double) -> Unit)? = null

        var onRideSkipped: ((String, String) -> Unit)? = null

        var onRideDetected: ((String, String) -> Unit)? = null
        var onRideEvent: ((Map<String, Any>) -> Unit)? = null

    }



    fun clearHistory() {

        lastSavedRides.clear()

    }



    // Per-app cooldown tracker
    private val cooldowns = mutableMapOf<String, Long>()
    private val lastDetectTimes = mutableMapOf<String, Long>()

    // Reusable Handler for humanized delayed clicks (avoids blocking onAccessibilityEvent thread)
    private val rapidoClickHandler = Handler(android.os.Looper.getMainLooper())

    // Uber On-Device ML Kit OCR
    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }
    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private val isUberOcrRunning = AtomicBoolean(false)



    // ─────────────────────────────────────────────────────────────────────────

    // Service Lifecycle

    // ─────────────────────────────────────────────────────────────────────────

    

    private var windowManager: WindowManager? = null

    private var hudContainer: LinearLayout? = null

    private var hudStatusText: TextView? = null

    private var hudOffButton: TextView? = null

    private var isHudAttached = false

    private var cropBoxOverlayLayout: android.widget.FrameLayout? = null



    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            instance = this
            Log.d(TAG, "✅ AutoClickService Connected — monitoring ${APP_CONFIGS.size} apps")

            // 1. Safely update existing serviceInfo WITHOUT wiping XML capabilities
            try {
                val existingInfo = this.serviceInfo
                if (existingInfo != null) {
                    existingInfo.packageNames = null // Monitor all target apps
                    this.serviceInfo = existingInfo
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Failed updating serviceInfo: ${t.message}")
            }

            // 2. Safe notification channel & notification
            try {
                createNotificationChannel()
                updateNotification("Monitoring Rapido • Uber • OLA • Azhai • Zomato")
            } catch (t: Throwable) {
                Log.w(TAG, "Initial notification notice: ${t.message}")
            }

            // 3. Safe AdbManager init
            try {
                AdbManager.init(this)
            } catch (t: Throwable) {
                Log.w(TAG, "AdbManager init notice: ${t.message}")
            }

            // 4. Safe HUD init with post-delay to ensure window token is valid
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    initHUD()
                } catch (t: Throwable) {
                    Log.e(TAG, "HUD init error: ${t.message}")
                }
            }, 500L)

        } catch (t: Throwable) {
            Log.e(TAG, "FATAL error prevented in onServiceConnected: ${t.message}", t)
        }
    }



    override fun onDestroy() {
        super.onDestroy()
        instance = null

        try {
            ocrExecutor.shutdown()
        } catch (e: Exception) {}

        try {
            textRecognizer.close()
        } catch (e: Exception) {}

        try {
            if (isHudAttached) {
                hudContainer?.let { windowManager?.removeView(it) }
                isHudAttached = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Remove HUD error: ${e.message}")
        }
    }



    override fun onInterrupt() {}



    // ─────────────────────────────────────────────────────────────────────────

    // Floating HUD (Overlay with Live Status & OFF Accessibility Button)

    // ─────────────────────────────────────────────────────────────────────────



    private fun initHUD() {

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager



        // Outer Container Pill

        hudContainer = LinearLayout(this).apply {

            orientation = LinearLayout.HORIZONTAL

            gravity = Gravity.CENTER_VERTICAL

            val bg = GradientDrawable().apply {

                shape = GradientDrawable.RECTANGLE

                cornerRadius = 32f

                setColor(Color.parseColor("#E6141414")) // Sleek translucent dark

                setStroke(2, Color.parseColor("#44FFFFFF"))

            }

            background = bg

            setPadding(8, 6, 8, 6)

        }



        // 1. Live Status Text View (Left side)

        hudStatusText = TextView(this).apply {

            text = "🧭 Way 2 Right path"

            setTextColor(Color.WHITE)

            textSize = 12f

            typeface = Typeface.DEFAULT_BOLD

            gravity = Gravity.CENTER

            setPadding(18, 10, 18, 10)

            val stBg = GradientDrawable().apply {

                shape = GradientDrawable.RECTANGLE

                cornerRadius = 24f

                setColor(Color.parseColor("#88000000"))

            }

            background = stBg

        }



        // Spacer between status and button

        val spacer = View(this).apply {

            layoutParams = LinearLayout.LayoutParams(10, 1)

        }



        // 2. OFF Accessibility Button (Right side)

        hudOffButton = TextView(this).apply {

            text = "⏻ OFF accessibility"

            setTextColor(Color.WHITE)

            textSize = 11f

            typeface = Typeface.DEFAULT_BOLD

            gravity = Gravity.CENTER

            setPadding(18, 10, 18, 10)

            val btnBg = GradientDrawable().apply {

                shape = GradientDrawable.RECTANGLE

                cornerRadius = 24f

                setColor(Color.parseColor("#C62828")) // Distinct Red Button

                setStroke(1, Color.parseColor("#FF5252"))

            }

            background = btnBg

            setOnClickListener {

                disableForBanking(this@RapidoAutoClickService)

            }

        }



        hudContainer?.addView(hudStatusText)

        hudContainer?.addView(spacer)

        hudContainer?.addView(hudOffButton)



        val params = WindowManager.LayoutParams(

            WindowManager.LayoutParams.WRAP_CONTENT,

            WindowManager.LayoutParams.WRAP_CONTENT,

            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,

            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or

                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or

                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,

            android.graphics.PixelFormat.TRANSLUCENT

        ).apply {

            gravity = Gravity.TOP or Gravity.START

            val screenW = resources.displayMetrics.widthPixels

            x = (screenW / 2) - 180

            y = 60

        }



        // Center HUD horizontally once measured

        hudContainer?.post {

            try {
                if (!isHudAttached) return@post

                val screenW = resources.displayMetrics.widthPixels

                val hudW = hudContainer?.width ?: 0

                if (hudW > 0) {

                    params.x = ((screenW - hudW) / 2).coerceAtLeast(12)

                    windowManager?.updateViewLayout(hudContainer, params)

                }

            } catch (t: Throwable) {}

        }



        // Touch & Drag on Status Text with strict screen boundary clamping

        var initialX = 0

        var initialY = 0

        var initialTouchX = 0f

        var initialTouchY = 0f

        var isDragging = false



        hudStatusText?.setOnTouchListener { view, event ->

            when (event.action) {

                MotionEvent.ACTION_DOWN -> {

                    initialX = params.x

                    initialY = params.y

                    initialTouchX = event.rawX

                    initialTouchY = event.rawY

                    isDragging = false

                    true

                }

                MotionEvent.ACTION_MOVE -> {

                    val dx = (event.rawX - initialTouchX).toInt()

                    val dy = (event.rawY - initialTouchY).toInt()

                    if (Math.abs(dx) > 6 || Math.abs(dy) > 6) {

                        isDragging = true



                        val dm = resources.displayMetrics

                        val screenW = dm.widthPixels

                        val screenH = dm.heightPixels

                        val hudW = hudContainer?.width ?: 0

                        val hudH = hudContainer?.height ?: 0



                        val minX = 12

                        val maxX = (screenW - hudW - 12).coerceAtLeast(minX)



                        val minY = 50 // Safe margin below status bar / camera notch

                        val maxY = (screenH - hudH - 120).coerceAtLeast(minY) // Safe margin above navigation bar



                        params.x = (initialX + dx).coerceIn(minX, maxX)

                        params.y = (initialY + dy).coerceIn(minY, maxY)



                        try {

                            windowManager?.updateViewLayout(hudContainer, params)

                        } catch (e: Exception) {}

                    }

                    true

                }

                MotionEvent.ACTION_UP -> {

                    if (!isDragging) {

                        Toast.makeText(

                            this@RapidoAutoClickService,

                            "🧭 Way 2 Right path இயங்குகிறது. அணைக்க '⏻ OFF accessibility' தட்டவும்.",

                            Toast.LENGTH_SHORT

                        ).show()

                    }

                    true

                }

                else -> false

            }

        }



        try {

            windowManager?.addView(hudContainer, params)

            hudContainer?.visibility = View.GONE

            isHudAttached = true

        } catch (t: Throwable) {

            isHudAttached = false

            Log.e(TAG, "HUD init error: ${t.message}")

        }

    }



    private var hudLockedUntil = 0L

    private fun updateHUD(
        statusText: String,
        bgColorHex: String = "#88000000",
        isVisible: Boolean = true,
        lockDurationMs: Long = 0L
    ) {
        if (!isHudAttached) return
        val now = System.currentTimeMillis()
        if (lockDurationMs > 0L) {
            hudLockedUntil = now + lockDurationMs
        } else if (now < hudLockedUntil) {
            // A priority alert (Skip / Accepted) is currently on screen — do not overwrite it!
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isHUDEnabled = prefs.getBoolean("isHUDEnabled", true)
        val finalVisibility = if (isHUDEnabled) isVisible else false

        Handler(Looper.getMainLooper()).post {
            hudStatusText?.apply {
                text = statusText
                try {
                    val stBg = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 24f
                        setColor(Color.parseColor(bgColorHex))
                    }
                    background = stBg
                } catch (e: Exception) {}
            }
            hudContainer?.visibility = if (finalVisibility) View.VISIBLE else View.GONE

            // If HUD text expanded, clamp so it doesn't push past right screen edge
            hudContainer?.post {
                try {
                    if (!isHudAttached) return@post
                    val lp = hudContainer?.layoutParams as? WindowManager.LayoutParams
                    if (lp != null && hudContainer?.visibility == View.VISIBLE) {
                        val screenW = resources.displayMetrics.widthPixels
                        val hudW = hudContainer?.width ?: 0
                        val maxX = (screenW - hudW - 12).coerceAtLeast(12)
                        if (lp.x > maxX) {
                            lp.x = maxX
                            windowManager?.updateViewLayout(hudContainer, lp)
                        }
                    }
                } catch (t: Throwable) {}
            }
        }
    }

    fun setHUDVisibility(enabled: Boolean) {
        if (!isHudAttached) return
        if (enabled) {
            showInitialActiveHUD()
        } else {
            Handler(Looper.getMainLooper()).post {
                hudContainer?.visibility = View.GONE
            }
        }
    }

    fun showInitialActiveHUD() {
        if (!isHudAttached) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isHUDEnabled = prefs.getBoolean("isHUDEnabled", true)
        if (!isHUDEnabled) {
            Handler(Looper.getMainLooper()).post {
                hudContainer?.visibility = View.GONE
            }
            return
        }

        val activeConfigs = APP_CONFIGS.filter { prefs.getBoolean(it.prefKeyEnabled, false) }
        if (activeConfigs.isNotEmpty()) {
            val names = activeConfigs.joinToString(", ") { it.displayName }
            val isSmartFare = activeConfigs.any { prefs.getBoolean("${it.prefKeyEnabled.removePrefix("enabled_")}_smartFareMode", false) }
            val status = if (isSmartFare) "⚡ $names Smart Fare" else "🟢 $names Monitoring"
            val color = if (isSmartFare) "#882979FF" else "#8800C853"
            updateHUD(status, color, isVisible = true)
        } else {
            Handler(Looper.getMainLooper()).post {
                hudContainer?.visibility = View.GONE
            }
        }
    }



    // ─────────────────────────────────────────────────────────────────────────

    // Main Event Handler

    // ─────────────────────────────────────────────────────────────────────────



    private var lastOlaBypassCheckTime = 0L

    private fun checkAndApplyOlaDevBypass() {
        val now = System.currentTimeMillis()
        if (now - lastOlaBypassCheckTime < 2500L) return
        lastOlaBypassCheckTime = now

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val bypassActive = prefs.getBoolean("ola_dev_bypass_enabled", true)
        if (bypassActive && AdbManager.isDeveloperOptionsEnabled(this)) {
            Log.d(TAG, "Ola active with Developer Options enabled -> Auto-hiding for bypass")
            AdbManager.setDeveloperOptionsBypass(this, hideDevOptions = true)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        try {
            val pkg = event.packageName?.toString() ?: return

        // Auto-silence Developer Options check if Ola is open
        if (pkg == "com.olacabs.oladriver") {
            checkAndApplyOlaDevBypass()
        }



        // Find which app this event belongs to

        val appConfig = APP_CONFIGS.find { it.packageName == pkg }

        if (appConfig == null) {

            // Keep HUD steady on screen — do NOT hide on non-target system events

            
            return

        }



        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)



        // Check if this specific app's auto-click is enabled by user

        if (!prefs.getBoolean(appConfig.prefKeyEnabled, false)) {

            updateHUD("⏸ Disabled", "#88000000", true)

            return

        }



        // Get active location profiles (ONLY active saved profiles from global_active_locations)
        val globalLocationsStr = prefs.getString("global_active_locations", "") ?: ""
        val targetLocations = globalLocationsStr.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }



        val appId = appConfig.prefKeyEnabled.removePrefix("enabled_")
        val isSmartFareMode = prefs.getBoolean("${appId}_smartFareMode", false)

        if (!isSmartFareMode && targetLocations.isEmpty()) {
            updateHUD("⚠️ No Location Set", "#88FF9800", true)
            return
        }

        // Show default scanning state
        if (isSmartFareMode) {
            updateHUD("🟢 Smart Fare Active", "#882979FF", true)
        } else {
            updateHUD("🟢 Location Profile Active", "#8800C853", true)
        }



        // Autonomous Dynamic Crop: manual crop boxes are deprecated in favor of automatic bounds detection
        val cropRect: android.graphics.Rect? = null



        // Per-app cooldown check

        val now = System.currentTimeMillis()

        val lastClick = cooldowns[pkg] ?: 0L

        if (now - lastClick < COOLDOWN_MS) return



        // ── Scan ALL visible windows (not just the active one) ──────────────────

        // When user is on Earnings/Home page and a ride popup appears, that popup

        // is a SEPARATE window. rootInActiveWindow only sees the current page.

        // By scanning all windows we catch ride card popups from any page.

        val allRoots: List<AccessibilityNodeInfo> = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {

            windows

                ?.filter { w -> w.root != null }

                ?.mapNotNull { w ->

                    try { w.root } catch (e: Exception) { null }

                }

                ?.ifEmpty { listOfNotNull(rootInActiveWindow) }

                ?: listOfNotNull(rootInActiveWindow)

        } else {

            listOfNotNull(rootInActiveWindow)

        }



        var rideCardFoundInAnyWindow = false



        for (root in allRoots) {

            try {

                val hadRideCard = processRideRequest(root, appConfig, targetLocations, now, prefs, cropRect)

                if (hadRideCard) rideCardFoundInAnyWindow = true

                // If cooldown was updated inside, a click happened — stop scanning other windows

                if ((cooldowns[pkg] ?: 0L) == now) break

            } catch (e: Exception) {

                Log.e(TAG, "Error processing window: ${e.message}")

            } finally {

                try { root.recycle() } catch (e: Exception) {}

            }

        }



        // Only show Scanning if NO window had a visible ride card
        if (!rideCardFoundInAnyWindow) {
            val isSmartFare = prefs.getBoolean("${appId}_smartFareMode", false)
            if (isSmartFare) {
                updateHUD("🟢 Smart Fare Active", "#882979FF", true)
            } else {
                updateHUD("🟢 Location Profile Active", "#8800C853", true)
            }
        }
        } catch (t: Throwable) {
            Log.e(TAG, "Safe catch onAccessibilityEvent: ${t.message}", t)
        }
    }



    // ─────────────────────────────────────────────────────────────────────────

    // Core: Process Ride Request

    // ─────────────────────────────────────────────────────────────────────────



    private fun extractDistances(root: AccessibilityNodeInfo, cropRect: android.graphics.Rect?): Pair<Float, Float> {

        val texts = mutableListOf<String>()

        collectTextList(root, texts, cropRect)

        

        val distances = mutableListOf<Float>()

        val regex = Regex("([0-9.]+)\\s*(km|m)\\b", RegexOption.IGNORE_CASE)

        

        for (text in texts) {

            val matches = regex.findAll(text)

            for (match in matches) {

                val valueStr = match.groupValues[1]

                val unit = match.groupValues[2].lowercase()

                try {

                    var value = valueStr.toFloat()

                    if (unit == "m") value /= 1000f // convert to km

                    distances.add(value)

                } catch (e: Exception) {}

            }

        }

        

        val pickup = if (distances.isNotEmpty()) distances[0] else -1f

        val drop = if (distances.size > 1) distances[1] else -1f

        return Pair(pickup, drop)

    }



    private fun collectLeafTexts(node: AccessibilityNodeInfo, result: MutableList<String>, cropRect: android.graphics.Rect?) {

        val initialSize = result.size

        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            try { collectLeafTexts(child, result, cropRect) } finally { child.recycle() }

        }

        

        // If no text was found in children (or it has no children), check this node itself

        if (result.size == initialSize) {

            val t = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim()

            if (!t.isNullOrEmpty() && isNodeInCropRect(node, cropRect)) {

                result.add(t)

            }

        } else {

            // Also collect parent contentDescription if it contains fare or distance info (crucial for Uber)

            val desc = node.contentDescription?.toString()?.trim()

            if (!desc.isNullOrEmpty() && (desc.contains("₹") || desc.contains("rs", ignoreCase = true) || desc.matches(Regex(".*\\d+\\s*(km|m)\\b.*", RegexOption.IGNORE_CASE))) && isNodeInCropRect(node, cropRect)) {

                result.add(desc)

            }

        }

    }



    private fun extractPriceAndTip(root: AccessibilityNodeInfo, cropRect: android.graphics.Rect?): Pair<Float, Float> {

        val texts = mutableListOf<String>()

        collectLeafTexts(root, texts, cropRect)



        var maxFare = -1f

        var maxTip = -1f



        val currencyRegex = Regex("(?:₹|rs\\.?)\\s*([0-9]+\\.?[0-9]*)|([0-9]+\\.?[0-9]*)\\s*(?:₹|rs\\.?)", RegexOption.IGNORE_CASE)

        // Matches explicitly "+ 20 tip", "Tip: ₹20", "+ ₹20", "includes 20 tip", etc.

        val tipRegex = Regex("(?:\\+|tip|bonus|extra)[^0-9]*?([0-9]+\\.?[0-9]*)|([0-9]+\\.?[0-9]*)[^0-9]*?(?:tip|bonus|extra)", RegexOption.IGNORE_CASE)



        for (text in texts) {

            val tipMatch = tipRegex.find(text)

            if (tipMatch != null) {

                // We found a tip in this text node

                val tipValStr = tipMatch.groupValues[1].ifEmpty { tipMatch.groupValues[2] }

                try { 

                    val t = tipValStr.toFloat()

                    if (t > maxTip) maxTip = t 

                } catch (e: Exception) {}

                

                // Remove the tip portion and check if there's also a base fare in the same text

                val remainingText = text.replace(tipMatch.value, "")

                val fareMatches = currencyRegex.findAll(remainingText)

                for (m in fareMatches) {

                    val fStr = m.groupValues[1].ifEmpty { m.groupValues[2] }

                    try { 

                        val f = fStr.toFloat()

                        if (f > maxFare) maxFare = f 

                    } catch (e: Exception) {}

                }

            } else {

                // No tip, just look for regular fare

                val fareMatches = currencyRegex.findAll(text)

                for (m in fareMatches) {

                    val fStr = m.groupValues[1].ifEmpty { m.groupValues[2] }

                    try { 

                        val f = fStr.toFloat()

                        if (f > maxFare) maxFare = f 

                    } catch (e: Exception) {}

                }

            }

        }



        return Pair(maxFare, maxTip)

    }



    private fun processRideRequest(

        root: AccessibilityNodeInfo,

        appConfig: AppConfig,

        targetLocations: List<String>,

        now: Long,

        prefs: android.content.SharedPreferences,

        cropRect: android.graphics.Rect?

    ): Boolean {

        // Step 1: Find the Accept button FIRST to determine the safe reading boundary

        var acceptButton = findAcceptButton(root, appConfig.acceptButtonKeywords, cropRect)

        var forceGesture = false



        // ── FALLBACK FOR UBER ──

        if (acceptButton == null && appConfig.packageName == "com.ubercab.driver") {

            acceptButton = findTextNodeWithKeyword(root, appConfig.acceptButtonKeywords, cropRect)

            if (acceptButton != null) {

                forceGesture = true

                Log.d(TAG, "[${appConfig.displayName}] Found text node for Uber, forcing gesture click")

            }

        }



        // If there's no Accept button on screen or it is not visible/dismissing → return false
        if (acceptButton == null || !acceptButton.isVisibleToUser) {
            return false
        }





        // Step 2: Build a dynamic crop rect — only read text ABOVE the Accept button

        // This prevents "View Rate Card", ads, earnings, etc. from being read as locations

        val acceptBounds = android.graphics.Rect()

        acceptButton.getBoundsInScreen(acceptBounds)

        val dynamicCropRect = if (appConfig.packageName == "com.ubercab.driver" || appConfig.packageName == "com.zomato.delivery") {
            null // Uber uses OCR dynamic card crop; Zomato swipes accept button directly
        } else if (acceptBounds.top > 0) {
            android.graphics.Rect(0, 0, 9999, acceptBounds.top)
        } else {
            null
        }

        Log.d(TAG, "[${appConfig.displayName}] Accept button top: ${acceptBounds.top} → reading text above Y=${acceptBounds.top}")



        // Step 3: Extract data using the dynamic crop rect (only ride card area)

        val (pickupText, dropText) = extractLocations(root, appConfig, dynamicCropRect)

        val allText = StringBuilder().also { collectAllText(root, it, dynamicCropRect) }.toString()

        val (pickupKm, dropKm) = extractDistances(root, dynamicCropRect)

        val (baseFare, tipAmt) = extractPriceAndTip(root, dynamicCropRect)



        // ── DEBUG LOGS — remove after testing ──

        Log.d(TAG, "[${appConfig.displayName}] pickup='$pickupText'")

        Log.d(TAG, "[${appConfig.displayName}] drop='$dropText'")

        Log.d(TAG, "[${appConfig.displayName}] allText='${allText.take(200)}'")

        Log.d(TAG, "[${appConfig.displayName}] pickupKm=$pickupKm dropKm=$dropKm fare=$baseFare")

        Log.d(TAG, "[${appConfig.displayName}] targetLocations=$targetLocations")



        // Broadcast DETECTED event to UI for live incoming ride display
        val detectKey = "${appConfig.displayName}|$dropText|$baseFare"
        val lastDetect = lastDetectTimes[detectKey] ?: 0L
        if (now - lastDetect > 3000L) {
            lastDetectTimes[detectKey] = now
            val detectedMap = mapOf<String, Any>(
                "timestamp" to now,
                "appName" to appConfig.displayName,
                "location" to (if (dropText.isNotEmpty()) dropText else "Incoming Ride"),
                "status" to "DETECTED",
                "pickupKm" to pickupKm.toDouble(),
                "dropKm" to dropKm.toDouble(),
                "fare" to baseFare.toDouble(),
                "tip" to tipAmt.toDouble(),
                "pickupLocation" to pickupText,
                "dropLocation" to dropText
            )
            onRideEvent?.invoke(detectedMap)
            onRideDetected?.invoke(appConfig.displayName, "Incoming: $dropText")
        }

        // Step 4: Match check (Location vs Smart Fare)
        val appId = appConfig.prefKeyEnabled.removePrefix("enabled_")
        val isSmartFareMode = prefs.getBoolean("${appId}_smartFareMode", false)

        // ── ALWAYS ROUTE UBER TO OCR FALLBACK ──
        // In Uber, accessibility nodes NEVER expose pickupKm, dropKm, or fare (they return -1.0).
        // Routing directly to OCR ensures real pickup and drop distances are accurately validated
        // against user thresholds, preventing unwanted far-away pickups from being accepted.
        if (appConfig.packageName == "com.ubercab.driver") {
            Log.d(TAG, "[UBER] Accept button detected. Always routing to OCR fallback for real distance & fare validation...")
            runUberOcrFallback(acceptBounds, targetLocations, prefs, now)
            return true
        }

        var effectiveDropText = dropText

        val isLocationMatch: Boolean
        val matchedLocation: String?
        if (appConfig.packageName == "com.zomato.delivery") {
            // Zomato food delivery: No location check required
            isLocationMatch = true
            matchedLocation = "Zomato Order"
        } else if (isSmartFareMode) {
            // STRICT VALIDATION FOR SMART FARE MODE:
            // 1. Must have a real fare > 0 (prevents false click when card is dismissing / text is gone)
            if (baseFare <= 0f) {
                Log.d(TAG, "[${appConfig.displayName}] Smart Fare active but baseFare <= 0 (not a valid ride card). Ignoring.")
                return false
            }
            // 2. Must have at least dropKm, pickupKm, or drop location text
            if (dropKm <= 0f && pickupKm <= 0f && effectiveDropText.isEmpty()) {
                Log.d(TAG, "[${appConfig.displayName}] Smart Fare active but no distance or drop info found. Likely closing card. Ignoring.")
                return false
            }
            isLocationMatch = true
            matchedLocation = "Smart Fare"
        } else {
            if (effectiveDropText.isEmpty()) {
                // Drop text was not found! DO NOT fallback to allText. Do NOT click accept!
                Log.d(TAG, "[${appConfig.displayName}] Drop text not found in Location Profile mode. Skipping accept.")
                updateHUD("⚠️ Drop Text Not Found", "#88FF9800", true, lockDurationMs = 3000L)
                return true
            }
            matchedLocation = targetLocations.firstOrNull { loc ->
                effectiveDropText.contains(loc, ignoreCase = true)
            }
            isLocationMatch = (matchedLocation != null)
        }
        Log.d(TAG, "[${appConfig.displayName}] isSmartFareMode=$isSmartFareMode isLocationMatch=$isLocationMatch matched='$matchedLocation'")

        // Step 5: Distance & Price Validation (reads Global Filters, falls back to per-app settings)
        val pickupMin = prefs.getFloat("global_pickup_min", prefs.getFloat("pickup_min_$appId", 0.0f))
        val pickupMax = prefs.getFloat("global_pickup_max", prefs.getFloat("pickup_max_$appId", 5.0f))
        val dropMin = prefs.getFloat("global_drop_min", prefs.getFloat("drop_min_$appId", 0.0f))
        val dropMax = prefs.getFloat("global_drop_max", prefs.getFloat("drop_max_$appId", 50.0f))
        val priceMin = prefs.getFloat("global_price_min", prefs.getFloat("price_min_$appId", 0.0f))
        val priceMax = prefs.getFloat("global_price_max", prefs.getFloat("price_max_$appId", 1500.0f))

        val isPickupInRange = pickupKm == -1f || (pickupKm in pickupMin..pickupMax)
        val isDropInRange = dropKm == -1f || (dropKm in dropMin..dropMax)
        val isPriceInRange = if (isSmartFareMode) {
            baseFare > 0f && (baseFare in priceMin..priceMax)
        } else {
            baseFare == -1f || (baseFare in priceMin..priceMax)
        }

        val isMatch = if (appConfig.packageName == "com.zomato.delivery") {
            true // Zomato accepts immediately when "Swipe to accept" is present
        } else {
            isLocationMatch && isPickupInRange && isDropInRange && isPriceInRange
        }

        Log.d(TAG, "[${appConfig.displayName}] Global Filters -> Ride(P: ${pickupKm}km, D: ${dropKm}km, Fare: ₹$baseFare) vs Limits(P: $pickupMin..$pickupMax, D: $dropMin..$dropMax, Price: ₹$priceMin..₹$priceMax) => pickupInRange=$isPickupInRange, dropInRange=$isDropInRange, priceInRange=$isPriceInRange, isMatch=$isMatch")

        val pStr = if (pickupKm >= 0) pickupKm else "?"
        val dStr = if (dropKm >= 0) dropKm else "?"
        val prStr = if (baseFare >= 0) "₹$baseFare" else "?"
        val tpStr = if (tipAmt >= 0) ", Tip: ₹$tipAmt" else ""
        val distStr = " (P: ${pStr}km, D: ${dStr}km, $prStr$tpStr)"

        // Ensure we get the bounds for blocker
        val bounds = android.graphics.Rect()
        acceptButton.getBoundsInScreen(bounds)

        if (appConfig.packageName == "com.olacabs.oladriver") {
            prefs.edit()
                .putInt("ola_accept_left", bounds.left)
                .putInt("ola_accept_top", bounds.top)
                .putInt("ola_accept_right", bounds.right)
                .putInt("ola_accept_bottom", bounds.bottom)
                .apply()
        }

        if (!isMatch) {

            if (isSmartFareMode) {
                updateHUD("❌ Fare Out of Range", "#88D32F2F", true, lockDurationMs = 3500L)
                val skipLoc = if (effectiveDropText.isNotEmpty()) effectiveDropText else "Smart Fare"
                saveRideHistory(appConfig.displayName, skipLoc + distStr, "SKIPPED", pickupKm, dropKm, baseFare, tipAmt, pickupText, effectiveDropText)
            } else if (effectiveDropText.isNotEmpty()) {
                updateHUD("❌ Skip: $effectiveDropText", "#88D32F2F", true, lockDurationMs = 3500L)
                saveRideHistory(appConfig.displayName, effectiveDropText + distStr, "SKIPPED", pickupKm, dropKm, baseFare, tipAmt, pickupText, effectiveDropText)
            } else {
                updateHUD("⚠️ Drop Text Not Found", "#88FF9800", true, lockDurationMs = 3000L)
            }
            return true
        }

        if (appConfig.packageName == "com.zomato.delivery") {
            Log.d(TAG, "[ZOMATO] Zomato Order Found! Swipe to accept triggered.")
            updateHUD("🎯 Zomato Order!", "#88E23744", true, lockDurationMs = 2500L)
        } else if (isSmartFareMode) {
            Log.d(TAG, "[${appConfig.displayName}] Smart Fare Match Found! Drop: '$effectiveDropText'")
            updateHUD("🎯 Fare Match!", "#882979FF", true, lockDurationMs = 2500L)
        } else {
            Log.d(TAG, "[${appConfig.displayName}] Target Match Found! Drop: '$effectiveDropText'")
            updateHUD("🎯 Match: $matchedLocation", "#88FF9800", true, lockDurationMs = 2500L)
        }



        if (appConfig.packageName == "com.olacabs.oladriver") {

            
            val btnText = acceptButton.text?.toString()?.lowercase() ?: acceptButton.contentDescription?.toString()?.lowercase() ?: ""

            if (btnText.contains("accept in")) {

                Log.d(TAG, "[OLA] Waiting for countdown... Button text: $btnText")

                updateHUD("⏳ Waiting...", "#FF9800", true)

                return true

            }

        }



        // Step 6: ✅ MATCH — Click!

        Log.d(TAG, "[${appConfig.displayName}] ✅ MATCH! Clicking...")

        updateHUD("✅ ACCEPTED!", "#FF00C853", true, lockDurationMs = 4000L)



        showClickEffect(bounds)



        val clicked = if (forceGesture) {

            performGestureClick(bounds)

            true

        } else {

            if (appConfig.packageName == "com.olacabs.oladriver") {

                Log.d(TAG, "[OLA] Auto-accepting OLA ride...")

                if (AdbManager.isConnected) {
                    Log.d(TAG, "[OLA] Executing ADB hardware tap & swipe...")
                    AdbManager.tap(bounds.exactCenterX(), bounds.exactCenterY())
                    AdbManager.swipe(bounds.left.toFloat(), bounds.exactCenterY(), bounds.right.toFloat(), bounds.exactCenterY())
                }

                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)

                performGestureClick(bounds)

                performGestureSwipe(bounds)

                true

            } else if (appConfig.packageName == "com.ubercab.driver") {

                Log.d(TAG, "[UBER] Auto-accepting Uber ride via Match button...")

                if (AdbManager.isConnected) {
                    Log.d(TAG, "[UBER] Executing ADB hardware tap at (${bounds.exactCenterX()}, ${bounds.exactCenterY()})...")
                    AdbManager.tap(bounds.exactCenterX(), bounds.exactCenterY())
                }

                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)

                performGestureClick(bounds)

                true

            } else if (appConfig.packageName == "com.rapido.rider") {

                Log.d(TAG, "[RAPIDO] Auto-accepting Rapido ride (100ms ultra-fast accept)...")

                // Capture bounds coordinates now (before node is recycled by Android)
                // Then fire the actual click after a 100ms ultra-fast delay using Handler (non-blocking)
                val clickX = bounds.exactCenterX()
                val clickY = bounds.exactCenterY()
                val delayMs = 100L

                // Mark cooldown immediately so duplicate events in the delay window don't trigger another click
                cooldowns[appConfig.packageName] = now

                rapidoClickHandler.postDelayed({
                    Log.d(TAG, "[RAPIDO] Ultra-fast click firing at (${clickX}, ${clickY}) after ${delayMs}ms")

                    // 1. Accessibility Node ACTION_CLICK on the current window
                    try {
                        val activeRoot = rootInActiveWindow
                        if (activeRoot != null) {
                            val btn = findAcceptButton(activeRoot, appConfig.acceptButtonKeywords, null)
                            btn?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            btn?.recycle()
                            activeRoot.recycle()
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "[RAPIDO] Node click fallback error: ${e.message}")
                    }

                    // 2. Hardware ADB Tap if connected
                    if (AdbManager.isConnected) {
                        AdbManager.tap(clickX, clickY)
                    }

                    // 3. Real Touch Gesture Click (using enabled canPerformGestures)
                    val delayedBounds = android.graphics.Rect(
                        (clickX - 10).toInt(), (clickY - 10).toInt(),
                        (clickX + 10).toInt(), (clickY + 10).toInt()
                    )
                    performGestureClick(delayedBounds)

                    vibrateDevice()
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val total = prefs.getInt(KEY_TOTAL_ACCEPTED, 0) + 1
                    prefs.edit().putInt(KEY_TOTAL_ACCEPTED, total).apply()
                    val computedLocation = (if (dropText.isNotEmpty()) dropText else (matchedLocation ?: if (isSmartFareMode) "Smart Fare Match" else "")) + distStr
                    saveRideHistory(appConfig.displayName, computedLocation, "ACCEPTED", pickupKm, dropKm, baseFare, tipAmt, pickupText, dropText)
                    val earnedFare = (if (baseFare > 0f) baseFare.toDouble() else 0.0) + (if (tipAmt > 0f) tipAmt.toDouble() else 0.0)
                    onRideAccepted?.invoke(appConfig.displayName, computedLocation, earnedFare)
                    updateNotification("✅ [${appConfig.displayName}] Trip #$total Accepted → $computedLocation")
                    updateHUD("✅ ACCEPTED!", "#FF00C853", true, lockDurationMs = 4000L)
                    Log.d(TAG, "🎉 [RAPIDO] Accepted after ${delayMs}ms delay! Total: $total")
                }, delayMs)

                // Return true here so the main flow knows a click was scheduled
                // (cooldown already set above to prevent duplicate triggers)
                return true

            } else if (appConfig.packageName == "com.zomato.delivery") {
                Log.d(TAG, "[ZOMATO] Auto-swiping Zomato order via 'Swipe to accept' slider at bounds: $bounds")
                if (AdbManager.isConnected) {
                    val startX = bounds.left.toFloat() + (bounds.width() * 0.1f)
                    val centerY = bounds.exactCenterY()
                    val endX = bounds.right.toFloat() - (bounds.width() * 0.1f)
                    AdbManager.swipe(startX, centerY, endX, centerY)
                }
                performGestureSwipe(bounds)
                true
            } else {
                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }

        }



        if (clicked) {

            cooldowns[appConfig.packageName] = now

            val total = prefs.getInt(KEY_TOTAL_ACCEPTED, 0) + 1

            prefs.edit().putInt(KEY_TOTAL_ACCEPTED, total).apply()

            vibrateDevice()

            val finalLocation = (if (effectiveDropText.isNotEmpty()) effectiveDropText else (matchedLocation ?: if (isSmartFareMode) "Smart Fare Match" else "")) + distStr

            saveRideHistory(appConfig.displayName, finalLocation, "ACCEPTED", pickupKm, dropKm, baseFare, tipAmt, pickupText, effectiveDropText)

            val earnedFare = (if (baseFare > 0f) baseFare.toDouble() else 0.0) + (if (tipAmt > 0f) tipAmt.toDouble() else 0.0)

            onRideAccepted?.invoke(appConfig.displayName, finalLocation, earnedFare)

            updateNotification("✅ [${appConfig.displayName}] Trip #$total Accepted → $finalLocation")

            Log.d(TAG, "🎉 [${appConfig.displayName}] Accepted! Total: $total")

        }

        

        return true

    }

    // ─────────────────────────────────────────────────────────────────────────
    // Uber On-Device Screen Text Recognition (ML Kit OCR Fallback)
    // ─────────────────────────────────────────────────────────────────────────

    private fun runUberOcrFallback(
        acceptBounds: android.graphics.Rect,
        targetLocations: List<String>,
        prefs: android.content.SharedPreferences,
        timestamp: Long
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            Log.d(TAG, "[UBER OCR] Android version < 30 (R), takeScreenshot not supported via AccessibilityService.")
            updateHUD("⚠️ Uber OCR requires Android 11+", "#88FF9800", true, lockDurationMs = 3000L)
            return
        }

        if (!isUberOcrRunning.compareAndSet(false, true)) {
            Log.d(TAG, "[UBER OCR] OCR is already in progress, skipping duplicate call.")
            return
        }

        val lastClick = cooldowns["com.ubercab.driver"] ?: 0L
        if (System.currentTimeMillis() - lastClick < COOLDOWN_MS) {
            Log.d(TAG, "[UBER OCR] In cooldown, ignoring OCR.")
            isUberOcrRunning.set(false)
            return
        }

        Log.d(TAG, "[UBER OCR] Taking silent screenshot for Uber text recognition...")

        takeScreenshot(Display.DEFAULT_DISPLAY, ocrExecutor, object : TakeScreenshotCallback {
            override fun onSuccess(screenshotResult: ScreenshotResult) {
                try {
                    val hardwareBuffer = screenshotResult.hardwareBuffer
                    if (hardwareBuffer == null) {
                        Log.e(TAG, "[UBER OCR] hardwareBuffer is null!")
                        isUberOcrRunning.set(false)
                        return
                    }

                    val colorSpace = screenshotResult.colorSpace ?: ColorSpace.get(ColorSpace.Named.SRGB)
                    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                    } else null

                    hardwareBuffer.close()

                    if (bitmap == null) {
                        Log.e(TAG, "[UBER OCR] Failed to wrap HardwareBuffer.")
                        isUberOcrRunning.set(false)
                        return
                    }

                    val softBitmap = try {
                        val sb = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                        val canvas = android.graphics.Canvas(sb)
                        canvas.drawBitmap(bitmap, 0f, 0f, null)
                        sb
                    } catch (e: Throwable) {
                        bitmap.copy(Bitmap.Config.ARGB_8888, false)
                    } finally {
                        bitmap.recycle()
                    }

                    if (softBitmap == null) {
                        Log.e(TAG, "[UBER OCR] Failed to convert HardwareBuffer to software Bitmap.")
                        isUberOcrRunning.set(false)
                        return
                    }

                    // Dynamically crop to the Uber Ride Card area at the bottom based on the Match button bounds
                    val croppedCardBitmap = try {
                        if (acceptBounds.width() > 50 && acceptBounds.height() > 20 && acceptBounds.top > 100) {
                            val cardLeft = (acceptBounds.left - 30).coerceIn(0, softBitmap.width - 1)
                            val cardRight = (acceptBounds.right + 30).coerceIn(cardLeft + 1, softBitmap.width)
                            val cardBottom = (acceptBounds.bottom + 30).coerceIn(0, softBitmap.height)
                            val estimatedCardHeight = (acceptBounds.width() * 1.35f).toInt()
                            val cardTop = (acceptBounds.bottom - estimatedCardHeight).coerceIn((softBitmap.height * 0.30f).toInt(), (acceptBounds.top - 100).coerceAtLeast(0))
                            val cardWidth = cardRight - cardLeft
                            val cardHeight = cardBottom - cardTop
                            Log.d(TAG, "[UBER OCR] Cropping to Ride Card: ($cardLeft, $cardTop, $cardRight, $cardBottom) [${cardWidth}x${cardHeight}]")
                            Bitmap.createBitmap(softBitmap, cardLeft, cardTop, cardWidth, cardHeight)
                        } else {
                            val cardTop = (softBitmap.height * 0.40f).toInt()
                            val cardHeight = softBitmap.height - cardTop
                            Log.d(TAG, "[UBER OCR] Fallback crop to bottom 60%: (0, $cardTop, ${softBitmap.width}, ${softBitmap.height})")
                            Bitmap.createBitmap(softBitmap, 0, cardTop, softBitmap.width, cardHeight)
                        }
                    } catch (e: Throwable) {
                        Log.w(TAG, "[UBER OCR] Card crop failed (${e.message}), using full screen bitmap.")
                        softBitmap
                    }

                    val image = InputImage.fromBitmap(croppedCardBitmap, 0)
                    textRecognizer.process(image)
                        .addOnSuccessListener(ocrExecutor) { visionText ->
                            try {
                                if (croppedCardBitmap != softBitmap) {
                                    croppedCardBitmap.recycle()
                                }
                                softBitmap.recycle()
                            } catch (e: Exception) {}
                            isUberOcrRunning.set(false)
                            parseAndExecuteUberOcr(visionText, acceptBounds, targetLocations, prefs, timestamp)
                        }
                        .addOnFailureListener(ocrExecutor) { e ->
                            try {
                                if (croppedCardBitmap != softBitmap) {
                                    croppedCardBitmap.recycle()
                                }
                                softBitmap.recycle()
                            } catch (e: Exception) {}
                            isUberOcrRunning.set(false)
                            Log.e(TAG, "[UBER OCR] Text recognition failed: ${e.message}", e)
                        }
                } catch (e: Throwable) {
                    isUberOcrRunning.set(false)
                    Log.e(TAG, "[UBER OCR] Error processing screenshot: ${e.message}", e)
                }
            }

            override fun onFailure(errorCode: Int) {
                isUberOcrRunning.set(false)
                Log.e(TAG, "[UBER OCR] takeScreenshot failed with error code: $errorCode")
            }
        })
    }

    private fun parseAndExecuteUberOcr(
        visionText: com.google.mlkit.vision.text.Text,
        acceptBounds: android.graphics.Rect,
        targetLocations: List<String>,
        prefs: android.content.SharedPreferences,
        timestamp: Long
    ) {
        val sortedLines = visionText.textBlocks
            .flatMap { it.lines }
            .sortedBy { it.boundingBox?.top ?: 0 }
            .map { it.text.trim() }
            .filter { it.isNotEmpty() }

        val rawText = sortedLines.joinToString("\n")
        Log.d(TAG, "[UBER OCR] Cropped Card Sorted OCR Lines (${sortedLines.size}):\n$rawText")

        fun isNoiseLine(t: String): Boolean {
            val lower = t.lowercase()
            if (lower.length <= 1) return true
            if (lower.matches(Regex("""^\d+$"""))) return true
            val blacklist = listOf(
                "accessibility", "profile active", "dist out of", "fare out of", "auto clicker",
                "cash payment", "payment", "smart fare", "match", "airport", "alrport",
                "hospital", "cantonment", "pallavare"
            )
            if (blacklist.any { lower.contains(it) }) return true
            if (lower == "auto" || lower == "uber" || lower == "trip radar") return true
            return false
        }

        // 1. Distance Extraction (Locate Pickup KM and Drop KM anchors)
        val kmRegex = Regex("""([0-9]+(?:\.[0-9]+)?)\s*(?:km[a-z]?|m)\b""", RegexOption.IGNORE_CASE)
        var pickupDistIdx = -1
        var dropDistIdx = -1
        var pickupKm = -1f
        var dropKm = -1f

        for ((index, line) in sortedLines.withIndex()) {
            val cleaned = line.replace(Regex("""(\d+)\.,(\d+)"""), "$1.$2").replace(Regex("""(\d+),(\d+)"""), "$1.$2")
            val match = kmRegex.find(cleaned)
            if (match != null) {
                val num = match.groupValues[1].toFloatOrNull() ?: continue
                val unit = match.value.lowercase()
                val dist = if (unit.endsWith("m") && !unit.contains("km")) num / 1000f else num
                if (pickupDistIdx == -1) {
                    pickupDistIdx = index
                    pickupKm = dist
                } else if (dropDistIdx == -1) {
                    dropDistIdx = index
                    dropKm = dist
                    break
                }
            }
        }

        // 2. Fare Extraction
        val standardFareRegex = Regex("""(?:₹|rs\.?)\s*([0-9]+(?:\.[0-9]+)?)""", RegexOption.IGNORE_CASE)
        var ocrFare = standardFareRegex.find(rawText)?.groupValues?.get(1)?.toFloatOrNull() ?: -1f

        if (ocrFare <= 0f) {
            val paymentIdx = sortedLines.indexOfFirst {
                it.contains("payment", ignoreCase = true) || it.contains("cash", ignoreCase = true)
            }
            if (paymentIdx > 0) {
                val candidate = sortedLines[paymentIdx - 1].trim()
                val numStr = candidate.replace(Regex("""^[^\d]*"""), "")
                val num = numStr.toFloatOrNull()
                if (num != null && num > 0f) {
                    if (candidate.startsWith("7") && num in 720f..799f && (dropKm in 0f..15f || rawText.contains("Auto", ignoreCase = true))) {
                        ocrFare = (num - 700f).coerceAtLeast(30f)
                    } else {
                        ocrFare = num
                    }
                }
            }
        }

        if (ocrFare <= 0f) {
            val fareLineRegex = Regex("""^[₹FfTt7]?\s*([1-9][0-9]{1,4}(?:\.[0-9]+)?)$""")
            for (line in sortedLines) {
                val m = fareLineRegex.find(line.trim())
                if (m != null) {
                    val valNum = m.groupValues[1].toFloatOrNull() ?: continue
                    if (valNum in 30f..3000f) {
                        if (line.startsWith("7") && valNum in 720f..799f && (dropKm in 0f..15f || rawText.contains("Auto", ignoreCase = true))) {
                            ocrFare = valNum - 700f
                        } else {
                            ocrFare = valNum
                        }
                        break
                    }
                }
            }
        }

        // 3. Extract Pickup & Drop Addresses
        val pickupLines = mutableListOf<String>()
        if (pickupDistIdx != -1 && dropDistIdx != -1 && dropDistIdx > pickupDistIdx) {
            for (i in (pickupDistIdx + 1) until dropDistIdx) {
                val l = sortedLines[i]
                if (!isNoiseLine(l) && !l.startsWith("Includes", ignoreCase = true)) {
                    pickupLines.add(l)
                }
            }
        }
        val extractedPickup = pickupLines.joinToString(", ").replace(Regex(""",\s*,"""), ",").trim()

        val dropLines = mutableListOf<String>()
        if (dropDistIdx != -1) {
            for (i in (dropDistIdx + 1) until sortedLines.size) {
                val l = sortedLines[i]
                if (l.equals("Match", ignoreCase = true)) break
                if (!isNoiseLine(l)) {
                    dropLines.add(l)
                }
            }
        }
        val extractedDrop = dropLines.joinToString(", ").replace(Regex(""",\s*,"""), ",").trim()

        // 4. Location Matching & Display
        val isSmartFareMode = prefs.getBoolean("uber_smartFareMode", false)
        var matchedLocation: String? = null
        var isLocationMatch = false
        val displayLocation = if (extractedDrop.isNotEmpty()) extractedDrop else (if (extractedPickup.isNotEmpty()) extractedPickup else "Uber Ride")

        if (isSmartFareMode) {
            if (ocrFare > 0f) {
                isLocationMatch = true
                matchedLocation = displayLocation
            }
        } else {
            matchedLocation = targetLocations.firstOrNull { loc ->
                loc.isNotBlank() && (extractedDrop.contains(loc.trim(), ignoreCase = true) || rawText.contains(loc.trim(), ignoreCase = true))
            }
            if (matchedLocation != null) {
                isLocationMatch = true
            }
        }

        // 5. Distance & Price Range Checks (reads Global Filters, falls back to uber settings)
        val pickupMin = prefs.getFloat("global_pickup_min", prefs.getFloat("pickup_min_uber", 0.0f))
        val pickupMax = prefs.getFloat("global_pickup_max", prefs.getFloat("pickup_max_uber", 5.0f))
        val dropMin = prefs.getFloat("global_drop_min", prefs.getFloat("drop_min_uber", 0.0f))
        val dropMax = prefs.getFloat("global_drop_max", prefs.getFloat("drop_max_uber", 50.0f))
        val priceMin = prefs.getFloat("global_price_min", prefs.getFloat("price_min_uber", 0.0f))
        val priceMax = prefs.getFloat("global_price_max", prefs.getFloat("price_max_uber", 1500.0f))

        val isPickupInRange = pickupKm == -1f || (pickupKm in pickupMin..pickupMax)
        val isDropInRange = dropKm == -1f || (dropKm in dropMin..dropMax)
        val isPriceInRange = if (isSmartFareMode) {
            ocrFare > 0f && (ocrFare in priceMin..priceMax)
        } else {
            ocrFare == -1f || (ocrFare in priceMin..priceMax)
        }

        val isMatch = isLocationMatch && isPickupInRange && isDropInRange && isPriceInRange

        Log.d(TAG, "[UBER OCR] Global Filters -> Ride(P: ${pickupKm}km, D: ${dropKm}km, Fare: ₹$ocrFare) vs Limits(P: $pickupMin..$pickupMax, D: $dropMin..$dropMax, Price: ₹$priceMin..₹$priceMax) => pickupInRange=$isPickupInRange, dropInRange=$isDropInRange, priceInRange=$isPriceInRange, isMatch=$isMatch")

        val pStr = if (pickupKm >= 0) "${pickupKm}km" else "?"
        val dStr = if (dropKm >= 0) "${dropKm}km" else "?"
        val prStr = if (ocrFare >= 0) "₹${ocrFare.toInt()}" else "?"
        val distStr = " (P: $pStr, D: $dStr, $prStr)"
        val finalLocation = displayLocation + distStr

        Handler(Looper.getMainLooper()).post {
            if (isMatch) {
                Log.d(TAG, "[UBER OCR] MATCH FOUND! Location: '$displayLocation', Fare: $ocrFare, KM: $dropKm")
                cooldowns["com.ubercab.driver"] = System.currentTimeMillis()

                updateHUD("🎯 Uber Match: $displayLocation", "#882979FF", true, lockDurationMs = 2500L)
                vibrateDevice()

                val total = prefs.getInt(KEY_TOTAL_ACCEPTED, 0) + 1
                prefs.edit().putInt(KEY_TOTAL_ACCEPTED, total).apply()

                saveRideHistory("Uber", finalLocation, "ACCEPTED", pickupKm, dropKm, ocrFare, -1f, extractedPickup, extractedDrop)

                val earnedFare = if (ocrFare > 0f) ocrFare.toDouble() else 0.0
                onRideAccepted?.invoke("Uber", finalLocation, earnedFare)
                updateNotification("✅ [Uber] Trip #$total Accepted → $finalLocation")

                // Click Match button
                if (AdbManager.isConnected) {
                    Log.d(TAG, "[UBER OCR] Executing ADB hardware tap at (${acceptBounds.exactCenterX()}, ${acceptBounds.exactCenterY()})")
                    AdbManager.tap(acceptBounds.exactCenterX(), acceptBounds.exactCenterY())
                }
                performGestureClick(acceptBounds)
            } else {
                Log.d(TAG, "[UBER OCR] Ride Skipped / No Match. isLocationMatch=$isLocationMatch pickupInRange=$isPickupInRange dropInRange=$isDropInRange priceInRange=$isPriceInRange fare=$ocrFare dropKm=$dropKm")

                val hudMsg = if (isSmartFareMode && ocrFare > 0f && !isPriceInRange) {
                    "❌ Fare: ₹${ocrFare.toInt()} (Range: ₹${priceMin.toInt()}-₹${priceMax.toInt()})"
                } else if (!isPickupInRange || !isDropInRange) {
                    "❌ Dist Out of Range: P:$pStr D:$dStr"
                } else if (!isLocationMatch) {
                    "❌ Location Mismatch: $displayLocation"
                } else {
                    "❌ Uber Skip"
                }

                updateHUD(hudMsg, "#88D32F2F", true, lockDurationMs = 3500L)
                // Always save to ride history so driver sees all detected/skipped rides in Ride History page!
                saveRideHistory("Uber", finalLocation, "SKIPPED", pickupKm, dropKm, ocrFare, -1f, extractedPickup, extractedDrop)
            }
        }
    }





    private val lastSavedRides = mutableMapOf<String, Long>()



    private fun saveRideHistory(

        appName: String, 

        location: String, 

        status: String,

        pickupKm: Float = -1f,

        dropKm: Float = -1f,

        fare: Float = -1f,

        tip: Float = -1f,

        pickupLocation: String = "",

        dropLocation: String = ""

    ) {

        val key = "$appName|$location|$status"

        val now = System.currentTimeMillis()

        val lastTime = lastSavedRides[key] ?: 0L

        

        // Ignore duplicate rides within 30 seconds

        if (now - lastTime < 30000) {

            return

        }

        lastSavedRides[key] = now



        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        

        if (status == "SKIPPED") {

            val ts = prefs.getInt("totalSkipped", 0) + 1

            prefs.edit().putInt("totalSkipped", ts).apply()

            onRideSkipped?.invoke(appName, location)

        } else if (status == "ACCEPTED") {

            var te = prefs.getFloat("totalEarnings", 0.0f)

            if (fare > 0) te += fare

            if (tip > 0) te += tip

            prefs.edit().putFloat("totalEarnings", te).apply()

        }



        val rideEventMap = mapOf<String, Any>(
            "timestamp" to now,
            "appName" to appName,
            "location" to location,
            "status" to status,
            "pickupKm" to pickupKm.toDouble(),
            "dropKm" to dropKm.toDouble(),
            "fare" to fare.toDouble(),
            "tip" to tip.toDouble(),
            "pickupLocation" to pickupLocation,
            "dropLocation" to dropLocation
        )
        onRideEvent?.invoke(rideEventMap)

        val historyStr = prefs.getString("ride_history", "[]") ?: "[]"

        try {

            val array = org.json.JSONArray(historyStr)

            val newObj = org.json.JSONObject().apply {

                put("timestamp", now)

                put("appName", appName)

                put("location", location)

                put("status", status)

                put("pickupKm", pickupKm.toDouble())

                put("dropKm", dropKm.toDouble())

                put("fare", fare.toDouble())

                put("tip", tip.toDouble())

                put("pickupLocation", pickupLocation)

                put("dropLocation", dropLocation)

            }

            array.put(newObj)

            val finalArray = if (array.length() > 200) {

                val temp = org.json.JSONArray()

                for (i in array.length() - 200 until array.length()) {

                    temp.put(array.get(i))

                }

                temp

            } else {

                array

            }

            prefs.edit().putString("ride_history", finalArray.toString()).apply()

        } catch (e: Exception) {

            Log.e(TAG, "Failed to save history: ${e.message}")

        }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Drop Location Extraction (Per-App Smart Logic)

    // ─────────────────────────────────────────────────────────────────────────



    private fun isNodeInCropRect(node: AccessibilityNodeInfo, cropRect: android.graphics.Rect?): Boolean {

        if (cropRect == null) return true // no crop box means read everywhere

        val nodeRect = android.graphics.Rect()

        node.getBoundsInScreen(nodeRect)

        return android.graphics.Rect.intersects(cropRect, nodeRect)

    }



    private fun extractLocations(root: AccessibilityNodeInfo, appConfig: AppConfig, cropRect: android.graphics.Rect?): Pair<String, String> {

        return when (appConfig.packageName) {

            // Azhai has explicit "Drop:" label in UI

            "com.azhai.partner" -> extractLabeledLocations(root, listOf("drop", "destination"), cropRect)

            // Uber "Trip Radar" UI — second address block is destination

            "com.ubercab.driver" -> extractGenericAddresses(root, cropRect)

            // OLA — dedicated pickup / drop label extraction

            "com.olacabs.oladriver" -> extractOlaLocations(root, cropRect)

            // Rapido — second address block

            else -> extractGenericAddresses(root, cropRect)

        }

    }



    /**
     * Dedicated OLA Location Parser:
     * OLA shows "pick up [dist] · [mins]" above the pickup address,
     * and "drop [dist] · [mins]" above the drop address.
     */
    private fun extractOlaLocations(root: AccessibilityNodeInfo, cropRect: android.graphics.Rect?): Pair<String, String> {
        val allTexts = mutableListOf<String>()
        collectTextList(root, allTexts, cropRect)

        var pickupLoc = ""
        var dropLoc = ""

        for (i in allTexts.indices) {
            val text = allTexts[i]

            // 1. Pickup address follows "pick up"
            if (pickupLoc.isEmpty() && (text.contains("pick up", ignoreCase = true) || text.contains("pickup", ignoreCase = true))) {
                for (j in i + 1 until allTexts.size) {
                    val candidate = allTexts[j].trim()
                    if (isValidAddressCandidate(candidate)) {
                        pickupLoc = candidate
                        break
                    }
                }
            }

            // 2. Drop address follows "drop"
            if (dropLoc.isEmpty() && (text.contains("drop", ignoreCase = true) || text.contains("destination", ignoreCase = true))) {
                for (j in i + 1 until allTexts.size) {
                    val candidate = allTexts[j].trim()
                    if (isValidAddressCandidate(candidate)) {
                        dropLoc = candidate
                        break
                    }
                }
            }
        }

        // Fallback to cleaned generic addresses if needed
        if (dropLoc.isEmpty() || pickupLoc.isEmpty()) {
            val fallback = extractGenericAddresses(root, cropRect)
            if (pickupLoc.isEmpty()) pickupLoc = fallback.first
            if (dropLoc.isEmpty()) dropLoc = fallback.second
        }

        return Pair(pickupLoc, dropLoc)
    }

    private fun isValidAddressCandidate(text: String): Boolean {
        if (text.length < 3) return false
        if (text.startsWith("₹") || text.startsWith("$")) return false
        if (text.matches(Regex(".*\\d+\\s*(km|mins|min).*", RegexOption.IGNORE_CASE))) return false
        if (text.matches(Regex("\\d+s", RegexOption.IGNORE_CASE))) return false

        val ignoreList = listOf(
            "todo", "old to new", "new to old", "1 ride", "accept", "accept in",
            "auto", "cash", "category icon", "icon", "category", "pickup", "pick up", "drop",
            "fare", "rating", "payment", "trip radar", "match"
        )
        if (ignoreList.any { text.equals(it, ignoreCase = true) || (text.length <= 15 && text.contains(it, ignoreCase = true)) }) {
            return false
        }
        return true
    }



    /**

     * Azhai Partner UI has "Drop:" / "Destination:" labels.

     * Find the text immediately after that label.

     */

    private fun extractLabeledLocations(root: AccessibilityNodeInfo, labels: List<String>, cropRect: android.graphics.Rect?): Pair<String, String> {

        val allTexts = mutableListOf<String>()

        collectTextList(root, allTexts, cropRect)



        var dropLoc = ""

        for (i in allTexts.indices) {

            val text = allTexts[i]

            if (labels.any { text.contains(it, ignoreCase = true) }) {

                // Return next meaningful text after label

                for (j in i + 1 until allTexts.size) {

                    val next = allTexts[j]

                    if (next.isNotBlank() && next.length > 3 &&

                        !next.matches(Regex(".*\\d+\\s*(km|mins|min).*", RegexOption.IGNORE_CASE))

                    ) {

                        dropLoc = next

                        break

                    }

                }

                break

            }

        }

        

        // Find pickup as first non-drop address

        val addresses = mutableListOf<String>()

        collectAddressTexts(root, addresses, cropRect)

        val pickupLoc = addresses.firstOrNull { it != dropLoc } ?: ""

        

        return Pair(pickupLoc, dropLoc)

    }



    /**

     * Generic: collect address-like texts, return FIRST (pickup) and SECOND (destination).

     * Works for Rapido, Uber, OLA UI patterns.

     */

    private fun extractGenericAddresses(root: AccessibilityNodeInfo, cropRect: android.graphics.Rect?): Pair<String, String> {

        val addresses = mutableListOf<String>()

        collectAddressTexts(root, addresses, cropRect)

        return when {

            addresses.size >= 2 -> Pair(addresses[0], addresses[1])

            addresses.size == 1 -> Pair("", addresses[0])

            else -> Pair("", "")

        }

    }



    private fun collectAddressTexts(node: AccessibilityNodeInfo, result: MutableList<String>, cropRect: android.graphics.Rect?) {

        val text = (node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim()) ?: ""



        // Skip non-address texts based on patterns

        val skipKeywords = listOf(

            "accept", "match", "auto", "cash", "payment", "pickup", "drop",

            "trip radar", "on duty", "earnings", "orders", "hours","add on","Add on", "rating",

            "home", "dashboard", "booked", "compact", "traffic", "fare",

            "1 ride", "1 order", "old to new", "new to old", "km away", "distance",

            // Placeholder / UI icons
            "todo", "category icon", "icon", "category", "button", "image",

            // Rapido UI elements

            "rate card", "view rate", "know all", "searching", "refresh",

            "services", "go to", "on trip", "contact customer", "cancel my",

            "skip", "0 order", "scanning", "no order",

            // Ad / notification garbage

            "google", "installed", "open", "play store", "advertisement",

            "new feature", "update available", "notification", "allow",

            "ok got it", "dismiss", "close", "later"

        )

        val isAddress = text.length >= 3 &&
                !text.startsWith("₹") && !text.startsWith("$") &&
                !text.contains("todo", ignoreCase = true) &&
                !text.matches(Regex(".*\\d+\\s*(km|mins|min).*", RegexOption.IGNORE_CASE)) &&
                !text.matches(Regex("\\d+s")) && // "7s" countdown
                !skipKeywords.any { text.equals(it, ignoreCase = true) || (text.length <= 18 && text.contains(it, ignoreCase = true)) }



        if (isAddress && isNodeInCropRect(node, cropRect)) result.add(text)



        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            try { collectAddressTexts(child, result, cropRect) } finally { child.recycle() }

        }

    }



    private fun collectTextList(node: AccessibilityNodeInfo, result: MutableList<String>, cropRect: android.graphics.Rect?) {

        val t = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim()

        if (!t.isNullOrEmpty() && isNodeInCropRect(node, cropRect)) result.add(t)

        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            try { collectTextList(child, result, cropRect) } finally { child.recycle() }

        }

    }



    private fun collectAllText(node: AccessibilityNodeInfo, sb: StringBuilder, cropRect: android.graphics.Rect?) {

        val t = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim()

        if (!t.isNullOrEmpty() && isNodeInCropRect(node, cropRect)) sb.append(t).append(" ")

        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            try { collectAllText(child, sb, cropRect) } finally { child.recycle() }

        }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Find Accept / Match Button

    // ─────────────────────────────────────────────────────────────────────────



    private fun findAcceptButton(root: AccessibilityNodeInfo, keywords: List<String>, cropRect: android.graphics.Rect?): AccessibilityNodeInfo? {

        for (keyword in keywords) {

            // Method 1: By text search

            val nodes = root.findAccessibilityNodeInfosByText(keyword)

            for (node in nodes) {

                // BUG FIX: Do NOT check cropRect here! 

                // The Accept button could be outside the crop box (at the bottom of the screen).

                val nodeText = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim() ?: ""

                if (nodeText.contains(keyword, ignoreCase = true)) {

                    var current: AccessibilityNodeInfo? = node

                    while (current != null) {

                        if (current.isClickable && current.isEnabled) return current

                        current = current.parent

                    }

                }

                node.recycle()

            }

            // Method 2: Full traversal

            // Pass null for cropRect so it searches the entire screen for the button

            val found = findClickableWithKeyword(root, keyword, null)

            if (found != null) return found

        }

        return null

    }



    private fun findTextNodeWithKeyword(root: AccessibilityNodeInfo, keywords: List<String>, cropRect: android.graphics.Rect?): AccessibilityNodeInfo? {

        for (keyword in keywords) {

            val nodes = root.findAccessibilityNodeInfosByText(keyword)

            for (node in nodes) {

                val nodeText = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim() ?: ""

                if (nodeText.contains(keyword, ignoreCase = true)) {

                    return node // Found the text, don't care if it's clickable

                }

                node.recycle()

            }

            

            // Full traversal for text if findAccessibilityNodeInfosByText fails

            val found = findNodeWithText(root, keyword, cropRect)

            if (found != null) return found

        }

        return null

    }



    private fun findNodeWithText(node: AccessibilityNodeInfo, keyword: String, cropRect: android.graphics.Rect?): AccessibilityNodeInfo? {

        val text = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim() ?: ""

        if (text.contains(keyword, ignoreCase = true)) {

            return node

        }

        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            val result = findNodeWithText(child, keyword, cropRect)

            if (result != null) return result

        }

        return null

    }



    private fun executeAdbTap(x: Float, y: Float) {
        Thread {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", "input tap ${x.toInt()} ${y.toInt()}"))
                process.waitFor()
                Log.d(TAG, "ADB tap executed: input tap ${x.toInt()} ${y.toInt()}")
            } catch (e: Exception) {
                Log.d(TAG, "Direct local shell tap fallback: ${e.message}")
            }
        }.start()
    }

    private fun executeAdbSwipe(startX: Float, startY: Float, endX: Float, endY: Float) {
        Thread {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", "input swipe ${startX.toInt()} ${startY.toInt()} ${endX.toInt()} ${endY.toInt()} 300"))
                process.waitFor()
                Log.d(TAG, "ADB swipe executed: input swipe $startX $startY $endX $endY 300")
            } catch (e: Exception) {
                Log.d(TAG, "Direct local shell swipe fallback: ${e.message}")
            }
        }.start()
    }

    private fun performGestureClick(bounds: android.graphics.Rect) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

            // Add slight random coordinate jitter (+/- 4px) to simulate natural human finger touch
            val jitterX = (-4..4).random().toFloat()
            val jitterY = (-4..4).random().toFloat()
            val x = bounds.exactCenterX() + jitterX
            val y = bounds.exactCenterY() + jitterY

            executeAdbTap(x, y)

            val path = android.graphics.Path()

            path.moveTo(x, y)

            path.lineTo(x + 1f, y + 1f) // Required for Android to generate MotionEvent ACTION_DOWN & ACTION_UP!

            val gestureBuilder = android.accessibilityservice.GestureDescription.Builder()

            // 40ms duration for crisp and snappy touch event
            gestureBuilder.addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, 40))

            val callback = object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: android.accessibilityservice.GestureDescription?) {
                    Log.d(TAG, "Gesture click completed at ($x, $y)")
                }
                override fun onCancelled(gestureDescription: android.accessibilityservice.GestureDescription?) {
                    Log.w(TAG, "Gesture click cancelled by system at ($x, $y)")
                }
            }

            dispatchGesture(gestureBuilder.build(), callback, null)

        }

    }



    private fun performGestureSwipe(bounds: android.graphics.Rect) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

            val startX = bounds.left.toFloat() + (bounds.width() * 0.1f)

            val centerY = bounds.exactCenterY()

            val endX = bounds.right.toFloat() - (bounds.width() * 0.1f)

            executeAdbSwipe(startX, centerY, endX, centerY)

            val path = android.graphics.Path()

            path.moveTo(startX, centerY)

            path.lineTo(endX, centerY)

            

            val gestureBuilder = android.accessibilityservice.GestureDescription.Builder()

            gestureBuilder.addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, 400))

            dispatchGesture(gestureBuilder.build(), null, null)

        }

    }



    



    private fun findClickableWithKeyword(node: AccessibilityNodeInfo, keyword: String, cropRect: android.graphics.Rect?): AccessibilityNodeInfo? {

        if (!isNodeInCropRect(node, cropRect)) return null

        val text = node.text?.toString()?.trim() ?: node.contentDescription?.toString()?.trim() ?: ""

        if (text.contains(keyword, ignoreCase = true)) {

            var current: AccessibilityNodeInfo? = node

            while (current != null) {

                if (current.isClickable && current.isEnabled) return current

                current = current.parent

            }

        }

        for (i in 0 until node.childCount) {

            val child = node.getChild(i) ?: continue

            val result = findClickableWithKeyword(child, keyword, cropRect)

            if (result != null) return result

        }

        return null

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Crop Box Setup UI

    // ─────────────────────────────────────────────────────────────────────────



    fun showCropBoxSetup(appName: String) {

        Handler(Looper.getMainLooper()).post {

            val appConfig = APP_CONFIGS.find { it.displayName == appName } ?: return@post

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            

            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val savedLeft = prefs.getFloat("${appConfig.packageName}_crop_left", -1f)

            val savedTop = prefs.getFloat("${appConfig.packageName}_crop_top", -1f)

            val savedRight = prefs.getFloat("${appConfig.packageName}_crop_right", -1f)

            val savedBottom = prefs.getFloat("${appConfig.packageName}_crop_bottom", -1f)



            val layout = android.widget.FrameLayout(this)

            val cropView = CropBoxView(this)

            if (savedLeft != -1f) {

                cropView.setInitialRect(android.graphics.RectF(savedLeft, savedTop, savedRight, savedBottom))

            }



            val saveBtn = android.widget.Button(this).apply {

                text = "SAVE ZONE FOR ${appConfig.displayName.uppercase()}"

                setBackgroundColor(android.graphics.Color.parseColor("#FF00C853"))

                setTextColor(android.graphics.Color.WHITE)

                textSize = 16f

                setPadding(40, 20, 40, 20)

                setOnClickListener {

                    val r = cropView.cropRect

                    prefs.edit()

                        .putFloat("${appConfig.packageName}_crop_left", r.left)

                        .putFloat("${appConfig.packageName}_crop_top", r.top)

                        .putFloat("${appConfig.packageName}_crop_right", r.right)

                        .putFloat("${appConfig.packageName}_crop_bottom", r.bottom)

                        .apply()

                    wm.removeView(layout)

                    cropBoxOverlayLayout = null

                    updateNotification("✅ Target Zone saved for ${appConfig.displayName}")

                    onRideDetected?.invoke(appConfig.displayName, "Crop Box Saved Successfully!")

                }

            }



            val cancelBtn = android.widget.Button(this).apply {

                text = "CANCEL"

                setBackgroundColor(android.graphics.Color.parseColor("#FFD32F2F"))

                setTextColor(android.graphics.Color.WHITE)

                textSize = 16f

                setPadding(40, 20, 40, 20)

                setOnClickListener {

                    wm.removeView(layout)

                    cropBoxOverlayLayout = null

                }

            }



            val btnContainer = android.widget.LinearLayout(this).apply {

                orientation = android.widget.LinearLayout.HORIZONTAL

                gravity = Gravity.CENTER

                addView(cancelBtn, android.widget.LinearLayout.LayoutParams(

                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,

                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT

                ).apply { setMargins(0, 0, 20, 0) })

                addView(saveBtn)

            }



            layout.addView(cropView)

            layout.addView(btnContainer, android.widget.FrameLayout.LayoutParams(

                android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,

                android.widget.FrameLayout.LayoutParams.WRAP_CONTENT

            ).apply {

                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL

                bottomMargin = 100

            })



            val params = WindowManager.LayoutParams(

                WindowManager.LayoutParams.MATCH_PARENT,

                WindowManager.LayoutParams.MATCH_PARENT,

                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,

                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or

                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,

                android.graphics.PixelFormat.TRANSLUCENT

            )



            try {

                cropBoxOverlayLayout?.let { wm.removeView(it) } // remove old if exists

                wm.addView(layout, params)

                cropBoxOverlayLayout = layout

                updateNotification("Open ${appConfig.displayName} app to set Crop Box")

            } catch (e: Exception) {

                Log.e(TAG, "CropBox error: ${e.message}")

            }

        }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Vibration

    // ─────────────────────────────────────────────────────────────────────────



    private fun vibrateDevice() {

        try {

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager

                vm.defaultVibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))

            } else {

                @Suppress("DEPRECATION")

                val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                    v.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))

                } else { @Suppress("DEPRECATION") v.vibrate(400) }

            }

        } catch (e: Exception) { Log.e(TAG, "Vibrate: ${e.message}") }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Visual Click Effect

    // ─────────────────────────────────────────────────────────────────────────



    private fun showClickEffect(rect: android.graphics.Rect) {

        Handler(Looper.getMainLooper()).post {

            try {

                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

                val clickView = android.view.View(this).apply {

                    background = android.graphics.drawable.GradientDrawable().apply {

                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE

                        cornerRadius = 20f

                        setColor(Color.parseColor("#66FF9800")) // Semi-transparent amber

                        setStroke(8, Color.parseColor("#FFFF9800"))

                    }

                }

                

                val params = WindowManager.LayoutParams(

                    rect.width(),

                    rect.height(),

                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,

                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or

                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or

                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or

                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,

                    android.graphics.PixelFormat.TRANSLUCENT

                ).apply {

                    gravity = Gravity.TOP or Gravity.START

                    x = rect.left

                    y = rect.top

                }



                wm.addView(clickView, params)



                clickView.animate()

                    .alpha(0f)

                    .scaleX(1.2f)

                    .scaleY(1.2f)

                    .setDuration(600)

                    .withEndAction {

                        try {

                            wm.removeView(clickView)

                        } catch (e: Exception) {}

                    }

                    .start()

            } catch (e: Exception) {

                Log.e(TAG, "Click effect error: \${e.message}")

            }

        }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Notification

    // ─────────────────────────────────────────────────────────────────────────



    private fun createNotificationChannel() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    CHANNEL_ID, "Way 2 Right path", NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
                (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                    ?.createNotificationChannel(ch)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "createNotificationChannel notice: ${t.message}")
        }
    }



    private fun buildNotification(text: String): Notification {

        val pi = PendingIntent.getActivity(

            this, 0, Intent(this, MainActivity::class.java),

            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        )



        // Banking Mode Action in Notification

        val bankingIntent = Intent(this, BankingModeReceiver::class.java).apply {

            action = BankingModeReceiver.ACTION_DISABLE_BANKING

        }

        val bankingPendingIntent = PendingIntent.getBroadcast(

            this, 101, bankingIntent,

            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        )



        return NotificationCompat.Builder(this, CHANNEL_ID)

            .setContentTitle("🚖 Way 2 Right path Active")

            .setContentText(text)

            .setSmallIcon(android.R.drawable.ic_menu_mylocation)

            .setContentIntent(pi).setOngoing(true)

            .setPriority(NotificationCompat.PRIORITY_LOW)

            .addAction(

                android.R.drawable.ic_lock_power_off,

                "🏦 Banking Mode (Turn Off)",

                bankingPendingIntent

            )

            .build()

    }



    fun disableForBanking(context: Context) {

        try {

            Handler(Looper.getMainLooper()).post {

                Toast.makeText(

                    context,

                    "🏦 Banking Mode ஆன் செய்யப்பட்டது. Accessibility தற்காலிகமாக நிறுத்தப்பட்டது.",

                    Toast.LENGTH_LONG

                ).show()

            }

            // Hide HUD

            setHUDVisibility(false)

            // Cancel notification

            (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)?.cancel(NOTIFICATION_ID)

            // Stop accessibility service via Android API

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

                disableSelf()

            }

            Log.d(TAG, "Banking mode enabled: Accessibility service disabled via disableSelf()")

        } catch (e: Exception) {

            Log.e(TAG, "Error disabling for banking: ${e.message}")

        }

    }



    fun updateNotification(text: String) {
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (t: Throwable) {
            Log.w(TAG, "Notification post failed: ${t.message}")
        }
    }

}





