package com.minutoaminuto.minuto_a_minuto

import android.app.Application
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class MinutoApplication : Application() {

    private var defaultHandler: Thread.UncaughtExceptionHandler? = null

    override fun onCreate() {
        super.onCreate()
        
        // 1. Guardar el handler original del sistema
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        
        // 2. Configurar nuestro manejador — NO mata la app, solo intenta salvar el monitor
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            handleCrash(thread, throwable)
        }
        
        // 3. Inicializar WorkManager (Capa 4 de Persistencia)
        setupWorkManagerGuardian()
        
        Log.i("MinutoApp", "Aplicación iniciada con protección multinivel (WorkManager + CrashHandler)")
    }

    private fun setupWorkManagerGuardian() {
        try {
            val workRequest = PeriodicWorkRequestBuilder<MonitorWorker>(15, TimeUnit.MINUTES)
                .setInitialDelay(1, TimeUnit.MINUTES)
                .addTag("monitor_guardian")
                .build()

            WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                "MonitorGuardianWork",
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            Log.d("MinutoApp", "Guardian de WorkManager programado (15 min)")
        } catch (e: Exception) {
            Log.e("MinutoApp", "Error al programar WorkManager: ${e.message}")
        }
    }

    private fun handleCrash(thread: Thread, throwable: Throwable) {
        Log.e("MinutoApp", "CRASH DETECTADO en hilo ${thread.name}: ${throwable.message}")
        throwable.printStackTrace()

        // NO llamar startForegroundService() aquí: si el crash es ForegroundServiceDidNotStartInTimeException,
        // llamar de nuevo a startForegroundService() crea un bucle infinito de crashes.
        // El AlarmManager y WorkManager se encargan de reiniciar el monitor cuando sea seguro.

        // Delegar al handler original del sistema
        defaultHandler?.uncaughtException(thread, throwable)
    }
}
