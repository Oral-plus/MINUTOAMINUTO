package com.minutoaminuto.minuto_a_minuto

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Servicio en primer plano que monitorea el estado de las llamadas usando
 * TelephonyCallback (API 31+) o PhoneStateListener (API < 31).
 *
 * Este servicio es la fuente de verdad para detectar inicio/fin de llamadas
 * cuando la app está en segundo plano o el proceso fue reiniciado.
 *
 * Al detectar OFFHOOK → inicia CallRecorderService
 * Al detectar IDLE desde OFFHOOK → detiene CallRecorderService y escribe señal
 */
class PhoneStateMonitorService : Service() {

    companion object {
        private const val TAG = "PhoneStateMonitor"
        private const val CHANNEL_ID = "phone_state_monitor_channel"
        private const val NOTIF_ID = 9003
        private const val SHARED_PREFS = "FlutterSharedPreferences"
        private const val KEY_SIGNAL = "flutter.native_call_state_signal"
        private const val KEY_SIGNAL_TS = "flutter.native_call_state_ts"
        private const val KEY_SIGNAL_NUMBER = "flutter.native_call_state_number"
        private const val KEY_LAST_NUMBER = "native_last_call_number"
        // Clave que indica que hay una llamada terminada pendiente de guardar en Flutter
        private const val KEY_PENDING_SAVE = "flutter.native_pending_call_save"

        @Volatile
        var isRunning = false
            private set
    }

    private var telephonyManager: TelephonyManager? = null
    private var telephonyCallback: TelephonyCallback? = null
    private var telephonyExecutor: ExecutorService? = null

    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null

    private var lastState: Int = TelephonyManager.CALL_STATE_IDLE
    private var lastIncomingNumber: String = ""
    private var isIncoming: Boolean = false
    private var serviceStartTime: Long = 0L

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        try {
            isRunning = true
            serviceStartTime = System.currentTimeMillis()
            
            // V19: Inicializar estado real antes de registrar listener
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            lastState = tm?.callState ?: TelephonyManager.CALL_STATE_IDLE
            
            createNotificationChannel()
            startForegroundNotification()
            unregisterTelephonyListener() 
            registerTelephonyListener()
            
            scheduleKeepAlive()
            Log.d(TAG, "Servicio iniciado - Estado inicial: $lastState")
        } catch (e: Exception) {
            Log.e(TAG, "onCreate error: ${e.message}")
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Siempre llamar startForeground en onStartCommand para cubrir reinicios por START_STICKY
        // (cuando el sistema reinicia el servicio, onCreate no siempre se llama antes)
        startForegroundNotification()
        scheduleKeepAlive()
        return START_STICKY
    }

    private fun scheduleKeepAlive() {
        try {
            val alarm = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, PhoneStateMonitorService::class.java).apply {
                action = "RESTART_MONITOR"
            }
            val pi = android.app.PendingIntent.getService(
                this, 1, intent, // RequestCode 1 para diferenciar
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                else android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )
            
            // Intervalo de 15 minutos — suficiente para reanimar sin drenar batería
            val triggerAt = System.currentTimeMillis() + 15 * 60 * 1000 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                alarm.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Keep-Alive error: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        unregisterTelephonyListener()
        Log.d(TAG, "Servicio detenido")
        
        // Si el monitor debe estar activo, intentar reiniciarlo
        val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean("flutter.call_monitor_enabled", false)) {
            Log.w(TAG, "Servicio destruido pero debería estar activo — rearmando alarma")
            scheduleKeepAlive()
        }
        super.onDestroy()
    }

    // ─── Registro del listener ────────────────────────────────────────────────

    private fun registerTelephonyListener() {
        val hasPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            Log.w(TAG, "Sin permiso READ_PHONE_STATE — no se puede monitorear llamadas")
            stopSelf()
            return
        }

        try {
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                        val number = prefs.getString(KEY_LAST_NUMBER, "").orEmpty()
                        handleStateChange(state, number)
                    }
                }
                telephonyCallback = cb
                val executor = Executors.newSingleThreadExecutor()
                telephonyExecutor = executor
                telephonyManager?.registerTelephonyCallback(executor, cb)
                Log.d(TAG, "TelephonyCallback registrado (API 31+)")
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    override fun onCallStateChanged(state: Int, incomingNumber: String?) {
                        super.onCallStateChanged(state, incomingNumber ?: "")
                        handleStateChange(state, incomingNumber ?: "")
                    }
                }
                phoneStateListener = listener
                @Suppress("DEPRECATION")
                telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                Log.d(TAG, "PhoneStateListener registrado (API < 31)")
            }
        } catch (se: SecurityException) {
            Log.e(TAG, "Error de seguridad (permisos) al registrar: ${se.message}")
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "Error fatal al registrar listener: ${e.message}")
            stopSelf()
        }
    }

    @Suppress("DEPRECATION")
    private fun unregisterTelephonyListener() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
                telephonyExecutor?.shutdownNow()
                telephonyCallback = null
                telephonyExecutor = null
            } else {
                phoneStateListener?.let {
                    telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
                }
                phoneStateListener = null
            }
        } catch (e: Exception) {
            Log.w(TAG, "unregisterTelephonyListener: ${e.message}")
        }
    }

    // ─── Lógica de estado ─────────────────────────────────────────────────────

    private fun handleStateChange(state: Int, incomingNumber: String) {
        if (lastState == state) return
        Log.d(TAG, "HSC: $lastState -> $state (verified)")

        val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                if (incomingNumber.isNotBlank()) {
                    lastIncomingNumber = incomingNumber
                    prefs.edit().putString(KEY_LAST_NUMBER, incomingNumber).apply()
                }
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                // VERIFICACIÓN HARDWARE V19: Asegurar que el teléfono realmente reporta OFFHOOK
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                val actualState = tm?.callState ?: TelephonyManager.CALL_STATE_IDLE
                
                if (actualState == TelephonyManager.CALL_STATE_OFFHOOK) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    isIncoming = lastState == TelephonyManager.CALL_STATE_RINGING
                    
                    // GHOST FILTER: Si el servicio acaba de iniciar (<2s) y no hubo RINGING, 
                    // podría ser un callback de estado inicial falso/pestañeo.
                    val timeSinceStart = System.currentTimeMillis() - serviceStartTime
                    if (timeSinceStart < 2000 && !isIncoming && lastState == TelephonyManager.CALL_STATE_IDLE) {
                        Log.w(TAG, "Ghost Call Detectada: Ignorando OFFHOOK al arranque ($timeSinceStart ms)")
                        lastState = state
                        return
                    }

                    Log.d(TAG, "OFFHOOK CONFIRMADO -> Iniciando grabador")
                    val tsNow = (System.currentTimeMillis() / 1000).toInt()
                    prefs.edit()
                        .putString(KEY_SIGNAL, "start")
                        .putInt(KEY_SIGNAL_TS, tsNow)
                        .putString(KEY_SIGNAL_NUMBER, number)
                        .putBoolean(KEY_PENDING_SAVE, false)
                        .commit()

                    startCallRecorder(number)
                } else {
                    Log.w(TAG, "Ghost Offhook: Callback dice OFFHOOK pero Hardware dice $actualState")
                    return // No cambiar lastState para permitir re-disparo si el hardware cambia
                }
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                val wasActive = lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                               lastState == TelephonyManager.CALL_STATE_RINGING ||
                               CallRecorderService.isRecording.get()

                if (wasActive) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    Log.d(TAG, "IDLE CONFIRMADO -> Deteniendo grabador")

                    val tsNow = (System.currentTimeMillis() / 1000).toInt()
                    prefs.edit()
                        .putString(KEY_SIGNAL, "end")
                        .putInt(KEY_SIGNAL_TS, tsNow)
                        .putString(KEY_SIGNAL_NUMBER, number)
                        .putBoolean(KEY_PENDING_SAVE, true)
                        .commit()

                    stopCallRecorder()
                }
                prefs.edit().putString(KEY_LAST_NUMBER, "").commit()
                lastIncomingNumber = ""
                isIncoming = false
            }
        }

        lastState = state
    }

    private fun startCallRecorder(number: String) {
        if (!CallRecorderService.isRecording.get()) {
            val intent = Intent(this, CallRecorderService::class.java).apply {
                action = CallRecorderService.ACTION_START
                putExtra(CallRecorderService.EXTRA_CALL_NUMBER, number)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    startForegroundService(intent)
                } catch (e: Exception) {
                    Log.w(TAG, "No se pudo iniciar CallRecorder en foreground: ${e.message}")
                    startService(intent)
                }
            } else {
                startService(intent)
            }
        }
    }

    private fun stopCallRecorder() {
        try {
            val intent = Intent(this, CallRecorderService::class.java).apply {
                action = CallRecorderService.ACTION_STOP
            }
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "stopCallRecorder error: ${e.message}")
        }
    }

    // ─── Notificación foreground ──────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Monitor de llamadas",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Detecta inicio y fin de llamadas para registrarlas"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification() {
        val notif = try {
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Minuto a Minuto")
                .setContentText("Monitoreando llamadas...")
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .setSilent(true)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Error creando notificación: ${e.message}")
            return
        }

        // Intentar tipos en orden de preferencia — se necesita al menos uno exitoso
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // 1. specialUse (API 34+)
            if (Build.VERSION.SDK_INT >= 34) {
                try {
                    startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                    Log.d(TAG, "FGS iniciado con SPECIAL_USE")
                    return
                } catch (t: Throwable) {
                    Log.w(TAG, "FGS SPECIAL_USE falló (${t.javaClass.simpleName}): ${t.message}")
                }
            }
            // 2. dataSync — tipo menos restrictivo, siempre disponible en API 29+
            try {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                Log.d(TAG, "FGS iniciado con DATA_SYNC")
                return
            } catch (t: Throwable) {
                Log.w(TAG, "FGS DATA_SYNC falló (${t.javaClass.simpleName}): ${t.message}")
            }
            // 3. phoneCall como intento adicional
            try {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
                Log.d(TAG, "FGS iniciado con PHONE_CALL")
                return
            } catch (t: Throwable) {
                Log.w(TAG, "FGS PHONE_CALL falló (${t.javaClass.simpleName}): ${t.message}")
            }
        }
        // Fallback final sin tipo (API < 29, o último recurso)
        try {
            startForeground(NOTIF_ID, notif)
            Log.d(TAG, "FGS iniciado sin tipo (fallback)")
        } catch (t: Throwable) {
            // NUNCA llamar stopSelf() aquí: causa ForegroundServiceDidNotStartInTimeException
            Log.e(TAG, "startForeground falló completamente (${t.javaClass.simpleName}): ${t.message}")
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // NO usar startForegroundService() aquí: el proceso se está matando y
        // startForeground() no se puede llamar a tiempo → ForegroundServiceDidNotStartInTimeException
        // El AlarmManager (scheduleKeepAlive) se encarga de reiniciar el monitor.
        Log.w(TAG, "App eliminada de recientes — el AlarmManager reiniciará el monitor")
        scheduleKeepAlive()
        super.onTaskRemoved(rootIntent)
    }
}
