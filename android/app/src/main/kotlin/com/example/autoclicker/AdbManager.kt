package com.example.autoclicker

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.github.muntashirakon.adb.AbsAdbConnectionManager
import io.github.muntashirakon.adb.AdbStream
import kotlinx.coroutines.*
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.conscrypt.Conscrypt
import java.io.*
import java.math.BigInteger
import java.security.*
import java.security.cert.Certificate
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date
import java.util.concurrent.TimeUnit

object AdbManager {
    private const val TAG = "AdbManager"
    private const val PREFS_NAME = "AutoClickerPrefs"

    var isConnected: Boolean = false
        private set

    var connectPort: Int = -1
        private set

    private var appContext: Context? = null
    private var managerInstance: MyAdbConnectionManager? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    class MyAdbConnectionManager(private val context: Context) : AbsAdbConnectionManager() {
        private val mPrivateKey: PrivateKey
        private val mCertificate: Certificate

        init {
            setHostAddress("127.0.0.1")
            setApi(Build.VERSION.SDK_INT)
            setTimeout(5000, TimeUnit.MILLISECONDS)

            val keys = loadOrGenerateKeys(context)
            mPrivateKey = keys.first
            mCertificate = keys.second
        }

        override fun getPrivateKey(): PrivateKey = mPrivateKey
        override fun getCertificate(): Certificate = mCertificate
        override fun getDeviceName(): String = "AutoClicker"
    }

    fun init(context: Context) {
        try {
            appContext = context.applicationContext
            try {
                Security.insertProviderAt(Conscrypt.newProvider(), 1)
            } catch (t: Throwable) {
                Log.w(TAG, "Conscrypt init notice: ${t.message}")
            }

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            isConnected = prefs.getBoolean("adb_is_connected", false)
            connectPort = prefs.getInt("adb_connect_port", -1)

            if (isConnected && connectPort > 0) {
                scope.launch {
                    try {
                        getOrConnectManager(context, connectPort)
                    } catch (t: Throwable) {
                        Log.w(TAG, "Background ADB reconnect notice: ${t.message}")
                    }
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AdbManager init notice: ${t.message}")
        }
    }

    private fun getOrConnectManager(context: Context, port: Int): MyAdbConnectionManager {
        var mgr = managerInstance
        if (mgr == null) {
            mgr = MyAdbConnectionManager(context)
            managerInstance = mgr
        }
        if (!mgr.isConnected) {
            Log.d(TAG, "Connecting to 127.0.0.1:$port...")
            mgr.connect("127.0.0.1", port)
        }
        return mgr
    }

    private fun loadOrGenerateKeys(context: Context): Pair<PrivateKey, Certificate> {
        val keyFile = File(context.filesDir, "adb_private.key")
        val certFile = File(context.filesDir, "adb_cert.crt")

        if (keyFile.exists() && certFile.exists()) {
            try {
                val kf = KeyFactory.getInstance("RSA")
                val keyBytes = keyFile.readBytes()
                val privateKey = kf.generatePrivate(PKCS8EncodedKeySpec(keyBytes))

                val cf = CertificateFactory.getInstance("X.509")
                val cert = certFile.inputStream().use { cf.generateCertificate(it) }
                return Pair(privateKey, cert)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load existing keys, generating new: ${e.message}")
            }
        }

        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048)
        val kp = kpg.generateKeyPair()

        val notBefore = Date(System.currentTimeMillis() - 24 * 60 * 60 * 1000L)
        val notAfter = Date(System.currentTimeMillis() + 30L * 365 * 24 * 60 * 60 * 1000L)
        val serial = BigInteger.valueOf(System.currentTimeMillis())
        val name = X500Name("CN=AutoClicker")

        val certBuilder = JcaX509v3CertificateBuilder(
            name,
            serial,
            notBefore,
            notAfter,
            name,
            kp.public
        )

        val signer = JcaContentSignerBuilder("SHA256withRSA").build(kp.private)
        val certHolder = certBuilder.build(signer)
        val cert = JcaX509CertificateConverter().getCertificate(certHolder)

        try {
            keyFile.writeBytes(kp.private.encoded)
            certFile.writeBytes(cert.encoded)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save ADB key pair: ${e.message}")
        }

        return Pair(kp.private, cert)
    }

    fun pairAndConnect(
        context: Context,
        pairingPort: Int,
        pairingCode: String,
        connPort: Int,
        callback: (Boolean, String) -> Unit
    ) {
        scope.launch {
            try {
                Log.d(TAG, "Starting ADB Pairing on 127.0.0.1:$pairingPort with code: $pairingCode...")
                val mgr = MyAdbConnectionManager(context)
                managerInstance = mgr

                // Step 1: Real SPAKE2 Pairing over TLS
                val paired = mgr.pair("127.0.0.1", pairingPort, pairingCode.trim())
                if (!paired) {
                    withContext(Dispatchers.Main) {
                        callback(false, "Pairing failed. Please check the 6-digit code.")
                    }
                    return@launch
                }

                Log.d(TAG, "Pairing successful!")

                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putBoolean("adb_is_paired", true)
                    .putInt("adb_pairing_port", pairingPort)
                    .putString("adb_pairing_code", pairingCode)
                    .apply()

                // Step 2: Connect to adbd via TLS if a distinct connectPort was provided
                var connected = false
                if (connPort > 0 && connPort != pairingPort) {
                    Log.d(TAG, "Connecting to connect port $connPort...")
                    try {
                        connected = mgr.connect("127.0.0.1", connPort)
                    } catch (e: Exception) {
                        Log.w(TAG, "Direct connect to $connPort failed: ${e.message}")
                    }
                }

                // If user entered same port or connect failed, try auto-discovery via mDNS
                if (!connected) {
                    Log.d(TAG, "Trying auto-discovery via connectTls...")
                    try {
                        connected = mgr.connectTls(context, 3000)
                    } catch (_: Exception) {}
                }

                if (connected || mgr.isConnected) {
                    val finalPort = if (connPort > 0 && connPort != pairingPort) connPort else 5555
                    prefs.edit()
                        .putBoolean("adb_is_connected", true)
                        .putInt("adb_connect_port", finalPort)
                        .apply()

                    isConnected = true
                    connectPort = finalPort

                    // Auto-grant WRITE_SECURE_SETTINGS & apply Ola bypass if enabled
                    autoConfigureOlaBypass(context, prefs)

                    withContext(Dispatchers.Main) {
                        callback(true, "✅ WiFi ADB Paired & Connected (Port: $finalPort)")
                    }
                } else {
                    // Pairing succeeded! But user needs to input the Main Connect Port
                    withContext(Dispatchers.Main) {
                        callback(true, "✅ Device Paired! Now enter Main Port from settings and tap Connect.")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Pairing error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    val msg = e.localizedMessage ?: e.message ?: "Pairing failed"
                    callback(false, "Error: $msg")
                }
            }
        }
    }

    fun connectOnly(
        context: Context,
        connPort: Int,
        callback: (Boolean, String) -> Unit
    ) {
        scope.launch {
            try {
                Log.d(TAG, "Connecting to ADB on port: $connPort...")
                try {
                    managerInstance?.disconnect()
                } catch (_: Exception) {}
                managerInstance = null

                val mgr = MyAdbConnectionManager(context)
                managerInstance = mgr

                var connected = false
                if (connPort > 0) {
                    try {
                        connected = mgr.connect("127.0.0.1", connPort)
                    } catch (e: Exception) {
                        Log.w(TAG, "Direct connect to $connPort failed: ${e.message}")
                    }
                }

                if (!connected) {
                    Log.d(TAG, "Direct connect failed, attempting mDNS connectTls...")
                    try {
                        connected = mgr.connectTls(context, 3000)
                    } catch (e: Exception) {
                        Log.w(TAG, "connectTls mDNS notice: ${e.message}")
                    }
                }

                if (connected || mgr.isConnected) {
                    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("adb_is_connected", true)
                        .putInt("adb_connect_port", connPort)
                        .apply()

                    isConnected = true
                    connectPort = connPort

                    // Auto-grant WRITE_SECURE_SETTINGS & apply Ola bypass if enabled
                    autoConfigureOlaBypass(context, prefs)

                    withContext(Dispatchers.Main) {
                        callback(true, "✅ Connected to Wireless ADB (Port: $connPort)")
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        callback(false, "Could not connect to port $connPort. Make sure Wireless Debugging is ON.")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Connect error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    val msg = e.localizedMessage ?: e.message ?: "Connection failed"
                    callback(false, "Error: $msg")
                }
            }
        }
    }

    private fun autoConfigureOlaBypass(context: Context, prefs: android.content.SharedPreferences) {
        scope.launch {
            try {
                executeShell("pm grant ${context.packageName} android.permission.WRITE_SECURE_SETTINGS")
                val bypassActive = prefs.getBoolean("ola_dev_bypass_enabled", true)
                if (bypassActive) {
                    executeShell("settings put global development_settings_enabled 0")
                    Log.d(TAG, "Auto-applied Ola Developer Options bypass on connect")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Auto configure bypass notice: ${e.message}")
            }
        }
    }

    fun isWriteSecureSettingsGranted(context: Context): Boolean {
        return context.checkCallingOrSelfPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS) ==
                PackageManager.PERMISSION_GRANTED
    }

    fun isDeveloperOptionsEnabled(context: Context): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) == 1
        } catch (e: Exception) {
            false
        }
    }

    fun setDeveloperOptionsBypass(
        context: Context,
        hideDevOptions: Boolean,
        callback: ((Boolean, String) -> Unit)? = null
    ) {
        val value = if (hideDevOptions) 0 else 1
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("ola_dev_bypass_enabled", hideDevOptions).apply()

        // 1. Direct native modification if permission already granted
        if (isWriteSecureSettingsGranted(context)) {
            try {
                Settings.Global.putInt(
                    context.contentResolver,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    value
                )
                Log.d(TAG, "development_settings_enabled set to $value via Settings.Global")
                val msg = if (hideDevOptions) "Developer Options hidden (Ola bypass active)" else "Developer Options restored"
                callback?.invoke(true, msg)
                return
            } catch (e: Exception) {
                Log.w(TAG, "Direct putInt failed: ${e.message}")
            }
        }

        // 2. Fallback: Grant permission & apply setting via ADB shell
        scope.launch {
            try {
                executeShell("pm grant ${context.packageName} android.permission.WRITE_SECURE_SETTINGS")
                val ok = executeShell("settings put global development_settings_enabled $value")
                withContext(Dispatchers.Main) {
                    if (ok) {
                        val msg = if (hideDevOptions) "Developer Options hidden (Ola bypass active)" else "Developer Options restored"
                        callback?.invoke(true, msg)
                    } else {
                        callback?.invoke(false, "Could not update settings. Please connect WiFi ADB first.")
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback?.invoke(false, "Error: ${e.message}")
                }
            }
        }
    }

    fun tap(x: Float, y: Float): Boolean {
        tapAsync(x, y, null)
        return true
    }

    fun swipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Int = 300): Boolean {
        swipeAsync(startX, startY, endX, endY, durationMs, null)
        return true
    }

    fun tapAsync(x: Float, y: Float, callback: ((Boolean) -> Unit)? = null) {
        scope.launch {
            val ok = executeShell("input tap ${x.toInt()} ${y.toInt()}")
            withContext(Dispatchers.Main) {
                callback?.invoke(ok)
            }
        }
    }

    fun swipeAsync(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Int = 300,
        callback: ((Boolean) -> Unit)? = null
    ) {
        scope.launch {
            val ok = executeShell(
                "input swipe ${startX.toInt()} ${startY.toInt()} ${endX.toInt()} ${endY.toInt()} $durationMs"
            )
            withContext(Dispatchers.Main) {
                callback?.invoke(ok)
            }
        }
    }

    fun executeShell(command: String): Boolean {
        val ctx = appContext ?: return false
        val port = connectPort
        if (port <= 0) return false

        try {
            val mgr = getOrConnectManager(ctx, port)
            val stream: AdbStream = mgr.openStream("shell:$command\n")
            try {
                stream.openInputStream().use { it.readBytes() }
            } catch (_: Exception) {}
            try {
                stream.close()
            } catch (_: Exception) {}
            Log.d(TAG, "ADB Shell executed: $command")
            return true
        } catch (e: Exception) {
            Log.w(TAG, "ADB Shell error: ${e.message}. Reconnecting...")
            try {
                managerInstance?.disconnect()
            } catch (_: Exception) {}
            managerInstance = null

            return try {
                val mgr = getOrConnectManager(ctx, port)
                val stream: AdbStream = mgr.openStream("shell:$command\n")
                try {
                    stream.openInputStream().use { it.readBytes() }
                } catch (_: Exception) {}
                try {
                    stream.close()
                } catch (_: Exception) {}
                true
            } catch (e2: Exception) {
                Log.e(TAG, "ADB retry failed: ${e2.message}", e2)
                false
            }
        }
    }

    fun disconnect(context: Context) {
        isConnected = false
        connectPort = -1
        try {
            managerInstance?.disconnect()
        } catch (_: Exception) {}
        managerInstance = null

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("adb_is_connected", false)
            .remove("adb_connect_port")
            .apply()
    }
}
