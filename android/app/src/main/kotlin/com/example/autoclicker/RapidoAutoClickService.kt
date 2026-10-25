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

            )

        )



        var instance: RapidoAutoClickService? = null

        var onRideAccepted: ((String, String, Double) -> Unit)? = null

        var onRideSkipped: ((String, String) -> Unit)? = null

        var onRideDetected: ((String, String) -> Unit)? = null

    }



    fun clearHistory() {

        lastSavedRides.clear()

    }



    // Per-app cooldown tracker

    private val cooldowns = mutableMapOf<String, Long>()



    // ─────────────────────────────────────────────────────────────────────────

    // Service Lifecycle

    // ─────────────────────────────────────────────────────────────────────────

    

    private var windowManager: WindowManager? = null

    private var hudContainer: LinearLayout? = null

    private var hudStatusText: TextView? = null

    private var hudOffButton: TextView? = null

    private var cropBoxOverlayLayout: android.widget.FrameLayout? = null



    override fun onServiceConnected() {

        super.onServiceConnected()

        instance = this

        Log.d(TAG, "✅ AutoClickService Connected — monitoring ${APP_CONFIGS.size} apps")



        val info = AccessibilityServiceInfo().apply {

            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or

                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED

            packageNames = APP_CONFIGS.map { it.packageName }.toTypedArray()

            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC

            notificationTimeout = 100

            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or

                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS

        }

        serviceInfo = info



        createNotificationChannel()

        updateNotification("Monitoring Rapido • Uber • OLA • Azhai")

        

        initHUD()

    }



    override fun onDestroy() {

        super.onDestroy()

        instance = null

        try {

            hudContainer?.let { windowManager?.removeView(it) }

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

            text = "🤖 AutoClicker"

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

                val screenW = resources.displayMetrics.widthPixels

                val hudW = hudContainer?.width ?: 0

                if (hudW > 0) {

                    params.x = ((screenW - hudW) / 2).coerceAtLeast(12)

                    windowManager?.updateViewLayout(hudContainer, params)

                }

            } catch (e: Exception) {}

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

                            "🤖 AutoClicker இயங்குகிறது. அணைக்க '⏻ OFF accessibility' தட்டவும்.",

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

        } catch (e: Exception) {

            Log.e(TAG, "HUD init error: ${e.message}")

        }

    }



    private fun updateHUD(statusText: String, bgColorHex: String = "#88000000", isVisible: Boolean = true) {

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

                } catch (e: Exception) {}

            }

        }

    }



    fun setHUDVisibility(enabled: Boolean) {

        Handler(Looper.getMainLooper()).post {

            hudContainer?.visibility = if (enabled) View.VISIBLE else View.GONE

        }

    }



    // ─────────────────────────────────────────────────────────────────────────

    // Main Event Handler

    // ─────────────────────────────────────────────────────────────────────────



    override fun onAccessibilityEvent(event: AccessibilityEvent) {

        val pkg = event.packageName?.toString() ?: return



        // Find which app this event belongs to

        val appConfig = APP_CONFIGS.find { it.packageName == pkg }

        if (appConfig == null) {

            updateHUD("", isVisible = false) // Hide if we switch to non-target app

            updateBlocker(null, false)

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



        // Read Crop Box if exists

        val savedLeft = prefs.getFloat("${appConfig.packageName}_crop_left", -1f)

        val cropRect = if (savedLeft != -1f) {

            android.graphics.Rect(

                savedLeft.toInt(),

                prefs.getFloat("${appConfig.packageName}_crop_top", -1f).toInt(),

                prefs.getFloat("${appConfig.packageName}_crop_right", -1f).toInt(),

                prefs.getFloat("${appConfig.packageName}_crop_bottom", -1f).toInt()

            )

        } else null



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



            val isOlaBlockerEnabled = prefs.getBoolean("ola_blocker_enabled", true)

            if (pkg == "com.olacabs.oladriver" && isOlaBlockerEnabled) {

                val left = prefs.getInt("ola_accept_left", -1)

                val top = prefs.getInt("ola_accept_top", -1)

                if (left != -1) {

                    val bounds = android.graphics.Rect(left, top, prefs.getInt("ola_accept_right", -1), prefs.getInt("ola_accept_bottom", -1))

                    updateBlocker(bounds, true)

                } else {

                    updateBlocker(null, false)

                }

            } else {

                updateBlocker(null, false)

            }

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



        // If there's no Accept button on screen → no ride card → return false

        if (acceptButton == null) {

            return false

        }





        // Step 2: Build a dynamic crop rect — only read text ABOVE the Accept button

        // This prevents "View Rate Card", ads, earnings, etc. from being read as locations

        val acceptBounds = android.graphics.Rect()

        acceptButton.getBoundsInScreen(acceptBounds)

        val dynamicCropRect = if (acceptBounds.top > 0) {

            android.graphics.Rect(0, 0, 9999, acceptBounds.top)

        } else {

            cropRect // fallback to saved crop box if bounds invalid

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



        // Step 4: Match check (Location vs Smart Fare)
        val appId = appConfig.prefKeyEnabled.removePrefix("enabled_")
        val isSmartFareMode = prefs.getBoolean("${appId}_smartFareMode", false)

        val isLocationMatch: Boolean
        val matchedLocation: String?
        if (isSmartFareMode) {
            isLocationMatch = true
            matchedLocation = "Smart Fare"
        } else {
            if (dropText.isEmpty()) {
                // Drop text was not found! DO NOT fallback to allText. Do NOT click accept!
                Log.d(TAG, "[${appConfig.displayName}] Drop text not found in Location Profile mode. Skipping accept.")
                updateHUD("⚠️ Drop Text Not Found", "#88FF9800", true)
                return true
            }
            matchedLocation = targetLocations.firstOrNull { loc ->
                dropText.contains(loc, ignoreCase = true)
            }
            isLocationMatch = (matchedLocation != null)
        }
        Log.d(TAG, "[${appConfig.displayName}] isSmartFareMode=$isSmartFareMode isLocationMatch=$isLocationMatch matched='$matchedLocation'")

        // Step 5: Distance & Price Validation
        val pickupMin = prefs.getFloat("pickup_min_$appId", 0.0f)
        val pickupMax = prefs.getFloat("pickup_max_$appId", 5.0f)
        val dropMin = prefs.getFloat("drop_min_$appId", 0.0f)
        val dropMax = prefs.getFloat("drop_max_$appId", 50.0f)
        val priceMin = prefs.getFloat("price_min_$appId", 0.0f)
        val priceMax = prefs.getFloat("price_max_$appId", 1500.0f)

        val isPickupInRange = pickupKm == -1f || (pickupKm in pickupMin..pickupMax)
        val isDropInRange = dropKm == -1f || (dropKm in dropMin..dropMax)
        val isPriceInRange = baseFare == -1f || (baseFare in priceMin..priceMax)

        val isMatch = isLocationMatch && isPickupInRange && isDropInRange && isPriceInRange

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
            if (appConfig.packageName == "com.olacabs.oladriver") {
                updateBlocker(bounds, true)
            }
            if (isSmartFareMode) {
                updateHUD("❌ Fare Out of Range", "#88D32F2F", true)
                val skipLoc = if (dropText.isNotEmpty()) dropText else "Smart Fare"
                saveRideHistory(appConfig.displayName, skipLoc + distStr, "SKIPPED", pickupKm, dropKm, baseFare, tipAmt, pickupText, dropText)
            } else if (dropText.isNotEmpty()) {
                updateHUD("❌ Skip: $dropText", "#88D32F2F", true)
                saveRideHistory(appConfig.displayName, dropText + distStr, "SKIPPED", pickupKm, dropKm, baseFare, tipAmt, pickupText, dropText)
            } else {
                updateHUD("⚠️ Drop Text Not Found", "#88FF9800", true)
            }
            return true
        }

        if (isSmartFareMode) {
            Log.d(TAG, "[${appConfig.displayName}] Smart Fare Match Found! Drop: '$dropText'")
            updateHUD("🎯 Fare Match!", "#882979FF", true)
        } else {
            Log.d(TAG, "[${appConfig.displayName}] Target Match Found! Drop: '$dropText'")
            updateHUD("🎯 Match: $matchedLocation", "#88FF9800", true)
        }



        if (appConfig.packageName == "com.olacabs.oladriver") {

            updateBlocker(null, false)

            val btnText = acceptButton.text?.toString()?.lowercase() ?: acceptButton.contentDescription?.toString()?.lowercase() ?: ""

            if (btnText.contains("accept in")) {

                Log.d(TAG, "[OLA] Waiting for countdown... Button text: $btnText")

                updateHUD("⏳ Waiting...", "#FF9800", true)

                return true

            }

        }



        // Step 6: ✅ MATCH — Click!

        Log.d(TAG, "[${appConfig.displayName}] ✅ MATCH! Clicking...")

        updateHUD("✅ ACCEPTED!", "#FF00C853", true)



        showClickEffect(bounds)



        val clicked = if (forceGesture) {

            performGestureClick(bounds)

            true

        } else {

            if (appConfig.packageName == "com.olacabs.oladriver") {

                Log.d(TAG, "[OLA] User will physically tap. No auto-click generated.")

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

            val finalLocation = (if (dropText.isNotEmpty()) dropText else (matchedLocation ?: if (isSmartFareMode) "Smart Fare Match" else "")) + distStr

            saveRideHistory(appConfig.displayName, finalLocation, "ACCEPTED", pickupKm, dropKm, baseFare, tipAmt, pickupText, dropText)

            val earnedFare = (if (baseFare > 0f) baseFare.toDouble() else 0.0) + (if (tipAmt > 0f) tipAmt.toDouble() else 0.0)

            onRideAccepted?.invoke(appConfig.displayName, finalLocation, earnedFare)

            updateNotification("✅ [${appConfig.displayName}] Trip #$total Accepted → $finalLocation")

            Log.d(TAG, "🎉 [${appConfig.displayName}] Accepted! Total: $total")

        }

        

        return true

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

            // OLA — red dot location (second location with red bullet)

            "com.olacabs.oladriver" -> extractGenericAddresses(root, cropRect)

            // Rapido — second address block

            else -> extractGenericAddresses(root, cropRect)

        }

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

        val text = node.text?.toString()?.trim() ?: ""



        // Skip non-address texts based on patterns

        val skipKeywords = listOf(

            "accept", "match", "auto", "cash", "payment", "pickup", "drop",

            "trip radar", "on duty", "earnings", "orders", "hours","add on","Add on", "rating",

            "home", "dashboard", "booked", "compact", "traffic", "fare",

            "1 ride", "1 order", "old to new", "km away", "distance",

            // Rapido UI elements

            "rate card", "view rate", "know all", "searching", "refresh",

            "services", "go to", "on trip", "contact customer", "cancel my",

            "skip", "0 order", "scanning", "no order",

            // Ad / notification garbage

            "google", "installed", "open", "play store", "advertisement",

            "new feature", "update available", "notification", "allow",

            "ok got it", "dismiss", "close", "later"

        )

        val isAddress = text.length > 8 &&

                !text.startsWith("₹") && !text.startsWith("$") &&

                !text.matches(Regex(".*\\d+\\s*(km|mins|min).*", RegexOption.IGNORE_CASE)) &&

                !text.matches(Regex("\\d+s")) && // "7s" countdown

                !skipKeywords.any { text.contains(it, ignoreCase = true) }



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



    private fun performGestureClick(bounds: android.graphics.Rect) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

            val path = android.graphics.Path()

            path.moveTo(bounds.exactCenterX(), bounds.exactCenterY())

            val gestureBuilder = android.accessibilityservice.GestureDescription.Builder()

            gestureBuilder.addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, 50))

            dispatchGesture(gestureBuilder.build(), null, null)

        }

    }



    private fun performGestureSwipe(bounds: android.graphics.Rect) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

            val path = android.graphics.Path()

            val startX = bounds.left.toFloat() + (bounds.width() * 0.1f)

            val centerY = bounds.exactCenterY()

            val endX = bounds.right.toFloat() - (bounds.width() * 0.1f)

            

            path.moveTo(startX, centerY)

            path.lineTo(endX, centerY)

            

            val gestureBuilder = android.accessibilityservice.GestureDescription.Builder()

            gestureBuilder.addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, 400))

            dispatchGesture(gestureBuilder.build(), null, null)

        }

    }



    private var blockerOverlay: android.view.View? = null



    private fun updateBlocker(bounds: android.graphics.Rect?, show: Boolean) {

        val wm = getSystemService(Context.WINDOW_SERVICE) as? android.view.WindowManager ?: return

        

        if (bounds == null) {

            blockerOverlay?.let { 

                try { wm.removeView(it) } catch (e: Exception) {}

                blockerOverlay = null

            }

            return

        }



        // Add HUGE padding to ensure it covers the entire bottom area even before rendering

        val pad = 200

        val targetX = bounds.left - pad

        val targetY = bounds.top - pad

        val targetW = bounds.width() + (pad * 2)

        val targetH = bounds.height() + (pad * 2)



        val flagsActive = android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or

                android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or

                android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN

                

        val flagsHidden = flagsActive or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE



        val currentFlags = if (show) flagsActive else flagsHidden

        val currentColor = if (show) android.graphics.Color.parseColor("#44FF0000") else android.graphics.Color.TRANSPARENT



        if (blockerOverlay != null) {

            val params = blockerOverlay?.layoutParams as? android.view.WindowManager.LayoutParams

            if (params != null) {

                params.x = targetX

                params.y = targetY

                params.width = targetW

                params.height = targetH

                params.flags = currentFlags

                blockerOverlay?.setBackgroundColor(currentColor)

                try { wm.updateViewLayout(blockerOverlay, params) } catch (e: Exception) {}

            }

            return

        }



        if (!show) return // Don't create initially if false



        val params = android.view.WindowManager.LayoutParams(

            targetW,

            targetH,

            android.view.WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,

            currentFlags,

            android.graphics.PixelFormat.TRANSLUCENT

        )

        params.gravity = android.view.Gravity.TOP or android.view.Gravity.START

        params.x = targetX

        params.y = targetY



        val view = android.widget.FrameLayout(this)

        view.setBackgroundColor(currentColor) 

        view.setOnTouchListener { _, _ -> true }



        try {

            wm.addView(view, params)

            blockerOverlay = view

        } catch (e: Exception) {

            e.printStackTrace()

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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val ch = NotificationChannel(

                CHANNEL_ID, "Auto Clicker", NotificationManager.IMPORTANCE_LOW

            ).apply { setShowBadge(false) }

            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)

                .createNotificationChannel(ch)

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

            .setContentTitle("🚖 Auto Clicker Active")

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

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)

            .notify(NOTIFICATION_ID, buildNotification(text))

    }

}





