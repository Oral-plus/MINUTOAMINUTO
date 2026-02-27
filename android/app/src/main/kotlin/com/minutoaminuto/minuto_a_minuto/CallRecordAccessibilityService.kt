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
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = true
            } catch (_: Exception) {}
        }

        fun restoreSpeaker(context: Context) {
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.isSpeakerphoneOn = false
                audioManager.mode = AudioManager.MODE_NORMAL
            } catch (_: Exception) {}
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: solo necesitamos el servicio activo para permisos de audio
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
