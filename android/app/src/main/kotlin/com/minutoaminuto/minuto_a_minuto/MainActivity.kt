package com.minutoaminuto.minuto_a_minuto

import android.Manifest
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.telephony.TelephonyCallback
import android.telephony.PhoneStateListener
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val PERM_REQUEST_CODE = 7777
        private const val SETUP_PREFS = "setup_prefs"
        private const val KEY_SETUP_DONE = "all_permissions_setup_done"
        
        private val ALL_PERMISSIONS = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_PHONE_NUMBERS,
            Manifest.permission.MODIFY_AUDIO_SETTINGS,
        )
    }

    private val callStateChannelName  = "minutoaminuto/call_state"
    private val audioRouteChannelName = "minutoaminuto/audio_route"

    private var eventSink: EventChannel.EventSink? = null
    private var telephonyCallback: Any? = null
    private var lastPhoneState: Int = TelephonyManager.CALL_STATE_IDLE

    // ─── Flutter engine ───────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, callStateChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerTelephonyListener()
                }
                override fun onCancel(arguments: Any?) {
                    unregisterTelephonyListener()
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioRouteChannelName)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "enableSpeaker" -> {
                        // Speakerphone logic is now handled internally by CallRecorderService if needed,
                        // or not used at all for a cleaner experience as requested.
                        result.success(true)
                    }
                    "disableSpeaker" -> {
                        result.success(true)
                    }
                    "isSpeakerOn" -> result.success(false)
                    "isAccessibilityEnabled" ->
                        result.success(CallRecordAccessibilityService.isAccessibilityEnabled(this))
                    "openAccessibilitySettings" -> {
                        CallRecordAccessibilityService.openAccessibilitySettings(this)
                        result.success(true)
                    }
                    "isAccessibilityServiceRunning" ->
                        result.success(CallRecordAccessibilityService.isRunning)
                    "startPhoneStateMonitor" -> {
                        startPhoneStateMonitorService()
                        result.success(true)
                    }
                    "stopStaleRecording" -> {
                        // All recording service stops are handled by the services themselves or the monitor
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val i = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.w(TAG, "openBatteryOptimizationSettings: ${e.message}")
                            result.success(false)
                        }
                    }
                    "canDrawOverlays" -> {
                        result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                // Fallback si el URI falla
                                try {
                                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    result.success(true)
                                } catch (e2: Exception) {
                                    result.success(false)
                                }
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "stopOptimizingBatteryUsage" -> {
                        requestBatteryExemption()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Auto-Setup: Configuración completa al abrir la app ───────────────────

    override fun onResume() {
        super.onResume()
        // V25: Solo hacer auto-reparación silenciosa al reanudar. 
        // NO re-pedir permisos/settings en cada onResume para evitar cierres.
        silentAutoRepair()
    }

    private fun silentAutoRepair() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.call_monitor_enabled", false)
            
            if (enabled && !PhoneStateMonitorService.isRunning) {
                Log.i(TAG, "Auto-repair: Monitor habilitado pero no corriendo. Reiniciando...")
                startPhoneStateMonitorService()
            }
        } catch (e: Exception) {
            Log.w(TAG, "silentAutoRepair error: ${e.message}")
        }
    }

    /**
     * V25: Solicita permisos de runtime SOLO si hay alguno faltante.
     * NO abre settings de accesibilidad ni batería automáticamente.
     * Esos se manejan desde Flutter (Setup Screen) para no interrumpir al usuario.
     */
    private fun setupAllPermissions() {
        try {
            val missing = ALL_PERMISSIONS.filter { 
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
            }
            if (Build.VERSION.SDK_INT >= 33) {
                if (ContextCompat.checkSelfPermission(this, "android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(this, arrayOf("android.permission.POST_NOTIFICATIONS"), PERM_REQUEST_CODE + 1)
                }
            }
            if (missing.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERM_REQUEST_CODE)
            }
        } catch (e: Exception) {
            Log.w(TAG, "setupAllPermissions error: ${e.message}")
        }
    }

    private fun requestBatteryExemption() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "requestBatteryExemption: ${e.message}")
        }
    }


    private fun requestAccessibilityService() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            Toast.makeText(this, "Busca 'Minuto a Minuto' y actívalo", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Log.w(TAG, "requestAccessibilityService: ${e.message}")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERM_REQUEST_CODE) {
            Log.d(TAG, "Permisos otorgados: ${grantResults.count { it == PackageManager.PERMISSION_GRANTED }}/${grantResults.size}")
            // V25: NO re-llamar setupAllPermissions para evitar bucle recursivo
        }
    }

    fun startPhoneStateMonitorService() {
        try {
            val intent = Intent(this, PhoneStateMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo iniciar PhoneStateMonitorService: ${e.message}")
        }
    }

    private fun registerTelephonyListener() {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    processCallState(state)
                }
            }
            tm.registerTelephonyCallback(mainExecutor, callback)
            telephonyCallback = callback
        } else {
            val listener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    processCallState(state)
                }
            }
            tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
            telephonyCallback = listener
        }
    }

    private fun unregisterTelephonyListener() {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyCallback?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                tm.unregisterTelephonyCallback(it as TelephonyCallback)
            } else {
                tm.listen(it as PhoneStateListener, PhoneStateListener.LISTEN_NONE)
            }
        }
        telephonyCallback = null
    }

    private fun processCallState(state: Int) {
        if (lastPhoneState == state) return
        
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> sendEvent("start", "incoming", "")
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (lastPhoneState == TelephonyManager.CALL_STATE_IDLE) {
                    sendEvent("start", "outgoing", "")
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastPhoneState != TelephonyManager.CALL_STATE_IDLE) {
                    sendEvent("end", "", "")
                }
            }
        }
        lastPhoneState = state
    }

    private fun sendEvent(state: String, direction: String, number: String) {
        runOnUiThread {
            Log.d(TAG, "Sending Event: $state $direction")
            eventSink?.success(mapOf("state" to state, "direction" to direction, "number" to number))
        }
    }

    override fun onDestroy() {
        unregisterTelephonyListener()
        super.onDestroy()
    }
}
