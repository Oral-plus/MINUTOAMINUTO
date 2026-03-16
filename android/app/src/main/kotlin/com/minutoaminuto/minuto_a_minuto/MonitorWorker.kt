package com.minutoaminuto.minuto_a_minuto

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class MonitorWorker(context: Context, workerParams: WorkerParameters) : Worker(context, workerParams) {

    override fun doWork(): Result {
        Log.d("MonitorWorker", "Ejecutando chequeo de persistencia WorkManager")
        
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.call_monitor_enabled", false)
            
            if (enabled && !PhoneStateMonitorService.isRunning) {
                Log.w("MonitorWorker", "Monitor detectado como NO corriendo. Reiniciando desde WorkManager...")
                val intent = Intent(applicationContext, PhoneStateMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }
            }
        } catch (e: Exception) {
            Log.e("MonitorWorker", "Error en doWork: ${e.message}")
        }
        
        return Result.success()
    }
}
