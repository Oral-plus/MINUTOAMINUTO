package com.minutoaminuto.minuto_a_minuto

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

class CallRecordAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        fun isAccessibilityEnabled(context: Context): Boolean {
            val serviceName = "${context.packageName}/${CallRecordAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            return enabledServices.contains(serviceName)
        }

        fun openAccessibilitySettings(context: Context) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        fun forceEnableSpeaker(context: Context) {
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.mode = AudioManager.MODE_IN_CALL
                audioManager.isSpeakerphoneOn = true
                android.util.Log.i("AccessibilityGuardian", "Altavoz forzado a ENCENDIDO")
            } catch (e: Exception) {
                android.util.Log.e("AccessibilityGuardian", "Error forzando altavoz: ${e.message}")
            }
        }

        fun restoreSpeaker(context: Context) {
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.isSpeakerphoneOn = false
                audioManager.mode = AudioManager.MODE_NORMAL
                android.util.Log.i("AccessibilityGuardian", "Altavoz forzado a APAGADO")
            } catch (e: Exception) {
                android.util.Log.e("AccessibilityGuardian", "Error restaurando altavoz: ${e.message}")
            }
        }
    }

    private val guardianHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var lastRestartTime: Long = 0L
    private var restartCount: Int = 0

    private val guardianRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                checkAndRestartMonitor()
            }
            guardianHandler.postDelayed(this, 5000) // Revisar cada 5 segundos
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        guardianHandler.post(guardianRunnable)
        android.util.Log.i("AccessibilityGuardian", "Servicio Guardián Conectado")
    }

    private fun checkAndRestartMonitor() {
        try {
            // Verificar si el monitoreo está habilitado en preferencias
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.call_monitor_enabled", false)
            
            if (enabled && !PhoneStateMonitorService.isRunning) {
                val now = System.currentTimeMillis()
                if (now - lastRestartTime < 30_000) {
                    android.util.Log.d("AccessibilityGuardian", "Monitor detenido pero en cooldown de reinicio...")
                    return
                }
                
                android.util.Log.w("AccessibilityGuardian", "Monitor detenido. REVIVIENDO...")
                lastRestartTime = now
                val intent = Intent(this, PhoneStateMonitorService::class.java)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityGuardian", "Error en guardián: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: solo necesitamos el servicio activo para permisos y como guardián
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        isRunning = false
        guardianHandler.removeCallbacks(guardianRunnable)
        super.onDestroy()
    }
}
