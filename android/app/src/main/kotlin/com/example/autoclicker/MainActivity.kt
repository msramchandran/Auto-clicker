package com.example.autoclicker

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.autoclicker/accessibility"
        private const val PREFS_NAME = "AutoClickerPrefs"
    }

    private var upiResult: io.flutter.plugin.common.MethodChannel.Result? = null

    private val UPI_REQUEST_CODE = 123


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {

        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == UPI_REQUEST_CODE) {

            if (data != null) {

                val response = data.getStringExtra("response") ?: ""

                upiResult?.success(response)

            } else {

                upiResult?.success("FAILURE")

            }

            upiResult = null

        }

    }


    private val prefs by lazy { getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Service status ──────────────────────────────────
                    "isServiceEnabled" ->
                        result.success(isAccessibilityServiceEnabled())

                    "launchUPI" -> {
                        val uriStr = call.argument<String>("url") ?: ""
                        val intent = Intent(Intent.ACTION_VIEW)
                        intent.data = android.net.Uri.parse(uriStr)
                        val chooser = Intent.createChooser(intent, "Pay with")
                        upiResult = result
                        try {
                            startActivityForResult(chooser, UPI_REQUEST_CODE)
                        } catch (e: Exception) {
                            result.error("NO_UPI_APP", "No UPI app found", null)
                            upiResult = null
                        }
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "disableAccessibility" -> {
                        RapidoAutoClickService.instance?.disableForBanking(this)
                        result.success(true)
                    }

                    "showCropBox" -> {
                        val appName = call.argument<String>("appName") ?: ""
                        RapidoAutoClickService.instance?.showCropBoxSetup(appName)
                        result.success(null)
                    }

                    // ── HUD Toggle ──────────────────────────────────────
                    "setHUDEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        prefs.edit().putBoolean("isHUDEnabled", enabled).apply()
                        RapidoAutoClickService.instance?.setHUDVisibility(enabled)
                        result.success(null)
                    }

                    // ── Location Profiles ───────────────────────────────
                    "setLocationProfiles" -> {
                        val profilesJson = call.argument<String>("profilesJson") ?: "[]"
                        val activeLocations = call.argument<String>("activeLocations") ?: ""
                        prefs.edit()
                            .putString("locationProfiles", profilesJson)
                            .putString("global_active_locations", activeLocations)
                            .remove("location_rapido")
                            .remove("location_uber")
                            .remove("location_ola")
                            .remove("location_azhai")
                            .apply()
                        result.success(null)
                    }

                    // ── Per-App: Set Enabled ────────────────────────────
                    // args: { "appId": "rapido", "enabled": true }
                    "setAppEnabled" -> {
                        val appId = call.argument<String>("appId") ?: ""
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val config = RapidoAutoClickService.APP_CONFIGS.find {
                            it.prefKeyEnabled == "enabled_$appId"
                        }
                        if (config != null) {
                            prefs.edit().putBoolean(config.prefKeyEnabled, enabled).apply()
                            val loc = prefs.getString(config.prefKeyLocation, "Not set") ?: "Not set"
                            RapidoAutoClickService.instance?.updateNotification(
                                buildActiveAppsText()
                            )
                            result.success(null)
                        } else {
                            result.error("NOT_FOUND", "App config not found: $appId", null)
                        }
                    }

                    // ── Per-App: Set Filters ────────────────────────────
                    // args: { "appId": "rapido", "pickupMin": 0.0, ... "priceMin": 0.0, "priceMax": 1000.0 }
                    "setAppFilters" -> {
                        val appId = call.argument<String>("appId") ?: ""
                        val pickupMin = call.argument<Double>("pickupMin")?.toFloat() ?: 0.0f
                        val pickupMax = call.argument<Double>("pickupMax")?.toFloat() ?: 5.0f
                        val dropMin = call.argument<Double>("dropMin")?.toFloat() ?: 0.0f
                        val dropMax = call.argument<Double>("dropMax")?.toFloat() ?: 50.0f
                        val priceMin = call.argument<Double>("priceMin")?.toFloat() ?: 0.0f
                        val priceMax = call.argument<Double>("priceMax")?.toFloat() ?: 1500.0f
                        
                        prefs.edit()
                            .putFloat("pickup_min_$appId", pickupMin)
                            .putFloat("pickup_max_$appId", pickupMax)
                            .putFloat("drop_min_$appId", dropMin)
                            .putFloat("drop_max_$appId", dropMax)
                            .putFloat("price_min_$appId", priceMin)
                            .putFloat("price_max_$appId", priceMax)
                            .apply()
                        result.success(null)
                    }

                    "syncAcceptedTrips" -> {

                        val accepted = call.argument<Int>("accepted") ?: 0

                        prefs.edit().putInt("totalAccepted", accepted).apply()

                        result.success(null)

                    }


                    "setAppPurchased" -> {

                        val purchased = call.argument<Boolean>("purchased") ?: true

                        prefs.edit().putBoolean("isAppPurchased", purchased).apply()

                        result.success(null)

                    }


                    "setSmartFareMode" -> {
                        val appId = call.argument<String>("appId") ?: ""
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        prefs.edit().putBoolean("${appId}_smartFareMode", enabled).apply()
                        result.success(null)
                    }

                    "setOlaBlocker" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        prefs.edit().putBoolean("ola_blocker_enabled", enabled).apply()
                        result.success(null)
                    }

                    // ── Get all app states ──────────────────────────────
                    "getAllAppStates" -> {
                        val statesMap = mutableMapOf<String, Any>()
                        RapidoAutoClickService.APP_CONFIGS.forEach { config ->
                            val appId = config.prefKeyEnabled.removePrefix("enabled_")
                            statesMap["${appId}_enabled"] = prefs.getBoolean(config.prefKeyEnabled, false)
                            statesMap["${appId}_pickup_min"] = prefs.getFloat("pickup_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_pickup_max"] = prefs.getFloat("pickup_max_$appId", 5.0f).toDouble()
                            statesMap["${appId}_drop_min"] = prefs.getFloat("drop_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_drop_max"] = prefs.getFloat("drop_max_$appId", 50.0f).toDouble()
                            statesMap["${appId}_price_min"] = prefs.getFloat("price_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_price_max"] = prefs.getFloat("price_max_$appId", 1500.0f).toDouble()
                            statesMap["${appId}_smartFareMode"] = prefs.getBoolean("${appId}_smartFareMode", false)
                        }
                        statesMap["ola_blocker_enabled"] = prefs.getBoolean("ola_blocker_enabled", true)
                        statesMap["isAppPurchased"] = prefs.getBoolean("isAppPurchased", false)
                        statesMap["totalAccepted"] = prefs.getInt("totalAccepted", 0)
                        statesMap["totalSkipped"] = prefs.getInt("totalSkipped", 0)
                        statesMap["totalEarnings"] = prefs.getFloat("totalEarnings", 0.0f).toDouble()
                        statesMap["isHUDEnabled"] = prefs.getBoolean("isHUDEnabled", true)
                        statesMap["locationProfiles"] = prefs.getString("locationProfiles", "[]") ?: "[]"
                        result.success(statesMap)
                    }

                    // ── Get ride history ──────────────────────────────
                    "getRideHistory" -> {
                        val historyStr = prefs.getString("ride_history", "[]") ?: "[]"
                        result.success(historyStr)
                    }

                    // ── Clear ride history ────────────────────────────
                    "clearRideHistory" -> {
                        prefs.edit()
                            .remove("ride_history")
                            .apply()
                        RapidoAutoClickService.instance?.clearHistory()
                        result.success(null)
                    }

                                        // ── Status Bar Notification ─────────────────────────
                    "requestNotificationPermission" -> {
                        requestNotificationPermissionIfNeeded()
                        result.success(true)
                    }

                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: "Auto Clicker"
                        val message = call.argument<String>("message") ?: ""
                        val notifId = call.argument<Int>("id") ?: 1002
                        showAppNotification(title, message, notifId)
                        result.success(true)
                    }

                    "scheduleBlockEndNotification" -> {
                        val triggerAt = (call.argument<Number>("triggerAtMillis")?.toLong()) ?: 0L
                        val title = call.argument<String>("title") ?: "Auto Clicker - 12hr Block Ended"
                        val message = call.argument<String>("message") ?: "Your block is removed and you can use the app now!"
                        scheduleBlockEndNotification(triggerAt, title, message)
                        result.success(true)
                    }

                    "cancelBlockEndNotification" -> {
                        cancelBlockEndNotification()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        RapidoAutoClickService.onRideAccepted = { appName, location, fare ->
            runOnUiThread {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onRideAccepted", mapOf("appName" to appName, "location" to location, "fare" to fare))
            }
        }
        RapidoAutoClickService.onRideSkipped = { appName, location ->
            runOnUiThread {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onRideSkipped", mapOf("appName" to appName, "location" to location))
            }
        }
        RapidoAutoClickService.onRideDetected = { appName, info ->
            runOnUiThread {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onRideDetected", mapOf("appName" to appName, "info" to info))
            }
        }

        requestNotificationPermissionIfNeeded()
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)



            }
        }
    }

    private fun buildActiveAppsText(): String {
        val active = RapidoAutoClickService.APP_CONFIGS.filter {
            prefs.getBoolean(it.prefKeyEnabled, false)
        }.map { it.displayName }
        return if (active.isEmpty()) "No apps enabled"
        else "Watching: ${active.joinToString(" • ")}"
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains("RapidoAutoClickService", ignoreCase = true)
    }

    private fun showAppNotification(title: String, message: String, notifId: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = BlockNotificationReceiver.CHANNEL_ID
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                BlockNotificationReceiver.CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts for block removal and rewards"
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            notifId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            nm.notify(notifId, notification)
            Log.d("MainActivity", "[Notification] Successfully posted notification id=$notifId title=$title")
        } catch (e: Exception) {
            Log.e("MainActivity", "[Notification] Failed to post notification id=$notifId", e)
        }
    }

    private fun scheduleBlockEndNotification(triggerAtMillis: Long, title: String, message: String) {
        if (triggerAtMillis <= System.currentTimeMillis()) return
        val intent = Intent(this, BlockNotificationReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("message", message)
            putExtra("id", BlockNotificationReceiver.NOTIFICATION_ID)
        }
        val pi = PendingIntent.getBroadcast(
            this,
            BlockNotificationReceiver.NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    private fun cancelBlockEndNotification() {
        val intent = Intent(this, BlockNotificationReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            this,
            BlockNotificationReceiver.NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
    }
}
