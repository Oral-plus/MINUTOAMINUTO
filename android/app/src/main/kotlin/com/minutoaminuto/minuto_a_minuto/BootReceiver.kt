package com.minutoaminuto.minuto_a_minuto

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.os.Build
import android.util.Log

/**
 * Al reiniciar el dispositivo, inicia el PhoneStateMonitorService para que
 * el monitoreo de llamadas funcione incluso sin abrir la app.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_USER_PRESENT &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) return

        Log.d(TAG, "Persistence Trigger ($action) — iniciando PhoneStateMonitorService")

        // Verificar que el monitor esté habilitado en SharedPreferences
        val prefs = context.getSharedPreferences(
            CallRecorderService.SHARED_PREFS, Context.MODE_PRIVATE
        )
        val enabled = prefs.getBoolean("flutter.call_monitor_enabled", false)
        if (!enabled) {
            Log.d(TAG, "Monitor deshabilitado — no se inicia tras boot")
            return
        }

        try {
            val serviceIntent = Intent(context, PhoneStateMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "PhoneStateMonitorService iniciado tras boot")
        } catch (e: Exception) {
            Log.e(TAG, "Error iniciando PhoneStateMonitorService: ${e.message}")
        }

        // También habilitar el BroadcastReceiver como fallback
        try {
            context.packageManager.setComponentEnabledSetting(
                ComponentName(context, CallStateBroadcastReceiver::class.java),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo habilitar CallStateBroadcastReceiver: ${e.message}")
        }
    }
}
