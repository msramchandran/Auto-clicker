package com.example.autoclicker

import android.content.Context
import android.content.Intent
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

                    // ── Per-App: Set Target Location ────────────────────
                    // args: { "appId": "rapido", "location": "Kovur" }
                    "setAppLocation" -> {
                        val appId = call.argument<String>("appId") ?: ""
                        val location = call.argument<String>("location") ?: ""
                        val config = RapidoAutoClickService.APP_CONFIGS.find {
                            it.prefKeyLocation == "location_$appId"
                        }
                        if (config != null) {
                            prefs.edit().putString(config.prefKeyLocation, location).apply()
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
                            statesMap["${appId}_location"] = prefs.getString(config.prefKeyLocation, "") ?: ""
                            statesMap["${appId}_pickup_min"] = prefs.getFloat("pickup_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_pickup_max"] = prefs.getFloat("pickup_max_$appId", 5.0f).toDouble()
                            statesMap["${appId}_drop_min"] = prefs.getFloat("drop_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_drop_max"] = prefs.getFloat("drop_max_$appId", 50.0f).toDouble()
                            statesMap["${appId}_price_min"] = prefs.getFloat("price_min_$appId", 0.0f).toDouble()
                            statesMap["${appId}_price_max"] = prefs.getFloat("price_max_$appId", 1500.0f).toDouble()
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

                    else -> result.notImplemented()
                }
            }

        RapidoAutoClickService.onRideAccepted = { appName, location ->
            runOnUiThread {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onRideAccepted", mapOf("appName" to appName, "location" to location))
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
}





