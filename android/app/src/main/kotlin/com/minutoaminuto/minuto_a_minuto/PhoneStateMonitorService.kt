package com.minutoaminuto.minuto_a_minuto

import android.Manifest
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
        // Clave para verificar si MediaProjection esta autorizado
        private const val KEY_MEDIA_PROJ_GRANTED = "flutter.media_projection_granted"

        @Volatile
        var isRunning = false
            private set
    }

    private var telephonyManager: TelephonyManager? = null
    private var telephonyCallback: TelephonyCallback? = null

    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null

    private var lastState: Int = TelephonyManager.CALL_STATE_IDLE
    private var lastIncomingNumber: String = ""
    private var isIncoming: Boolean = false

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        try {
            isRunning = true
            createNotificationChannel()
            startForegroundNotification()
            registerTelephonyListener()
            Log.d(TAG, "Servicio iniciado")
        } catch (e: Exception) {
            Log.e(TAG, "onCreate error: ${e.message}")
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Si el servicio ya estaba corriendo, solo refrescar
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        unregisterTelephonyListener()
        Log.d(TAG, "Servicio detenido")
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

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val executor = Executors.newSingleThreadExecutor()
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    // En API 31+ el número no viene en el callback
                    val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                    val number = prefs.getString(KEY_LAST_NUMBER, "").orEmpty()
                    handleStateChange(state, number)
                }
            }
            telephonyCallback = cb
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
    }

    @Suppress("DEPRECATION")
    private fun unregisterTelephonyListener() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
                telephonyCallback = null
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
        Log.d(TAG, "Estado: $lastState → $state  número=$incomingNumber")

        val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                if (incomingNumber.isNotBlank()) {
                    lastIncomingNumber = incomingNumber
                    prefs.edit().putString(KEY_LAST_NUMBER, incomingNumber).apply()
                }
                Log.d(TAG, "RINGING — número=$lastIncomingNumber")
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (lastState != TelephonyManager.CALL_STATE_OFFHOOK) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    isIncoming = lastState == TelephonyManager.CALL_STATE_RINGING
                    Log.d(TAG, "OFFHOOK — iniciando grabación número=$number")

                    val tsNow = (System.currentTimeMillis() / 1000).toInt()
                    prefs.edit()
                        .putString(KEY_SIGNAL, "start")
                        .putInt(KEY_SIGNAL_TS, tsNow)
                        .putString(KEY_SIGNAL_NUMBER, number)
                        .putBoolean(KEY_PENDING_SAVE, false)
                        .commit()

                    // Iniciar servicio de grabación
                    startCallRecorder(number)
                }
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                    lastState == TelephonyManager.CALL_STATE_RINGING
                ) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    Log.d(TAG, "IDLE — deteniendo grabación número=$number")

                    val tsNow = (System.currentTimeMillis() / 1000).toInt()
                    // commit() síncrono: garantiza que Flutter lo lea aunque el proceso se reinicie
                    prefs.edit()
                        .putString(KEY_SIGNAL, "end")
                        .putInt(KEY_SIGNAL_TS, tsNow)
                        .putString(KEY_SIGNAL_NUMBER, number)
                        // Marcar que hay una llamada pendiente de guardar en Flutter
                        .putBoolean(KEY_PENDING_SAVE, true)
                        .commit()

                    // Detener servicio de grabación
                    stopCallRecorder()
                }
                // Limpiar número guardado
                prefs.edit().putString(KEY_LAST_NUMBER, "").commit()
                lastIncomingNumber = ""
                isIncoming = false
            }
        }

        lastState = state
    }

    private fun startCallRecorder(number: String) {
        try {
            // Verificar si MediaProjection esta autorizado
            val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
            val hasMediaProjection = prefs.getBoolean(KEY_MEDIA_PROJ_GRANTED, false)
            
            if (hasMediaProjection && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Usar MediaProjection si esta disponible (mejor calidad de audio)
                Log.d(TAG, "Iniciando MediaProjectionRecorderService para número=$number")
                val intent = Intent(this, MediaProjectionRecorderService::class.java).apply {
                    action = MediaProjectionRecorderService.ACTION_START
                    putExtra(MediaProjectionRecorderService.EXTRA_CALL_NUMBER, number)
                    // No pasamos result code/data aquí porque el servicio usará MIC-only como fallback
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            } else {
                // Usar CallRecorderService como fallback
                Log.d(TAG, "Iniciando CallRecorderService para número=$number")
                val intent = Intent(this, CallRecorderService::class.java).apply {
                    action = CallRecorderService.ACTION_START
                    putExtra(CallRecorderService.EXTRA_CALL_NUMBER, number)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "startCallRecorder error: ${e.message}")
        }
    }

    private fun stopCallRecorder() {
        try {
            // Detener ambos servicios para asegurar que la grabación termine
            Log.d(TAG, "Deteniendo servicios de grabación")
            
            val mediaProjIntent = Intent(this, MediaProjectionRecorderService::class.java).apply {
                action = MediaProjectionRecorderService.ACTION_STOP
            }
            startService(mediaProjIntent)
            
            val callRecIntent = Intent(this, CallRecorderService::class.java).apply {
                action = CallRecorderService.ACTION_STOP
            }
            startService(callRecIntent)
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
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Detecta inicio y fin de llamadas para registrarlas"
                setSound(null, null)
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification() {
        try {
            val notif = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Minuto a Minuto")
                .setContentText("Monitoreando llamadas...")
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true)
                .setSilent(true)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForegroundNotification error: ${e.message}")
            throw e
        }
    }
}
