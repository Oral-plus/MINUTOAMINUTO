package com.minutoaminuto.minuto_a_minuto

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val REQ_MEDIA_PROJECTION = 1001
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_MEDIA_PROJ_GRANTED = "flutter.media_projection_granted"
    }

    private val callStateChannelName  = "minutoaminuto/call_state"
    private val audioRouteChannelName = "minutoaminuto/audio_route"

    private var eventSink: EventChannel.EventSink? = null
    private var telephonyManager: TelephonyManager? = null

    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null
    private var telephonyCallback: TelephonyCallback? = null

    private var lastState: Int = TelephonyManager.CALL_STATE_IDLE
    private var isIncoming: Boolean = false
    private var lastIncomingNumber: String = ""
    private var wasSpeakerOn: Boolean = false
    private var previousAudioMode: Int = AudioManager.MODE_NORMAL
    private var registeredDuringActiveCall: Boolean = false

    // MediaProjection: guardamos el resultado del diálogo del sistema
    private var mediaProjResultCode: Int = Activity.RESULT_CANCELED
    private var mediaProjResultData: Intent? = null
    private var mediaProjPendingNumber: String? = null
    private var mediaProjResultChannel: MethodChannel.Result? = null

    // ─── Flutter engine ───────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, callStateChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startPhoneStateListener()
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopPhoneStateListener()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioRouteChannelName)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "enableSpeaker" -> {
                        previousAudioMode = audioManager.mode
                        wasSpeakerOn = audioManager.isSpeakerphoneOn
                        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        audioManager.isSpeakerphoneOn = true
                        result.success(true)
                    }
                    "disableSpeaker" -> {
                        audioManager.isSpeakerphoneOn = wasSpeakerOn
                        audioManager.mode = previousAudioMode
                        result.success(true)
                    }
                    "isSpeakerOn" -> result.success(audioManager.isSpeakerphoneOn)
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
                        // Para el CallRecorderService si el teléfono está en IDLE
                        // Evita el micrófono fantasma al reiniciar la app después de una llamada
                        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                        val callState = tm?.callState ?: TelephonyManager.CALL_STATE_IDLE
                        if (callState == TelephonyManager.CALL_STATE_IDLE) {
                            Log.d(TAG, "stopStaleRecording: teléfono IDLE → deteniendo grabadores")
                            stopRecorderService()
                            stopMediaProjectionRecorderService()
                        } else {
                            Log.d(TAG, "stopStaleRecording: teléfono en llamada ($callState) → no detener")
                        }
                        result.success(true)
                    }
                    // ── MediaProjection ──────────────────────────────────────
                    "requestMediaProjectionPermission" -> {
                        // Muestra el diálogo del sistema al usuario
                        mediaProjResultChannel = result
                        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        val permIntent = mgr.createScreenCaptureIntent()
                        startActivityForResult(permIntent, REQ_MEDIA_PROJECTION)
                        // result se responde en onActivityResult
                    }
                    "hasMediaProjectionPermission" -> {
                        // Verificar en memoria primero, luego en prefs persistidas
                        val inMemory = mediaProjResultCode == Activity.RESULT_OK && mediaProjResultData != null
                        val inPrefs  = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                            .getBoolean(KEY_MEDIA_PROJ_GRANTED, false)
                        result.success(inMemory || inPrefs)
                    }
                    "startMediaProjectionRecorder" -> {
                        val number = call.argument<String>("number") ?: ""
                        startMediaProjectionRecorderService(number)
                        result.success(true)
                    }
                    "stopMediaProjectionRecorder" -> {
                        stopMediaProjectionRecorderService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── MediaProjection result ───────────────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_MEDIA_PROJECTION) {
            mediaProjResultCode = resultCode
            mediaProjResultData = if (resultCode == Activity.RESULT_OK) data else null

            val granted = resultCode == Activity.RESULT_OK
            Log.d(TAG, "MediaProjection permission: granted=$granted")

            // Persistir el estado del permiso para no volver a pedirlo
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_MEDIA_PROJ_GRANTED, granted).commit()

            // Responder a Flutter
            mediaProjResultChannel?.success(granted)
            mediaProjResultChannel = null

            // Si había una llamada esperando el permiso, iniciar grabación ahora
            val pendingNumber = mediaProjPendingNumber
            if (granted && pendingNumber != null) {
                mediaProjPendingNumber = null
                startMediaProjectionRecorderService(pendingNumber)
            }
        }
    }

    // ─── Iniciar/detener MediaProjectionRecorderService ───────────────────────

    fun startMediaProjectionRecorderService(number: String) {
        val intent = Intent(this, MediaProjectionRecorderService::class.java).apply {
            action = MediaProjectionRecorderService.ACTION_START
            putExtra(MediaProjectionRecorderService.EXTRA_RESULT_CODE, mediaProjResultCode)
            putExtra(MediaProjectionRecorderService.EXTRA_RESULT_DATA, mediaProjResultData)
            putExtra(MediaProjectionRecorderService.EXTRA_CALL_NUMBER, number)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "MediaProjectionRecorderService iniciado para número=$number")
        } catch (e: Exception) {
            Log.e(TAG, "Error iniciando MediaProjectionRecorderService: ${e.message}")
        }
    }

    private fun stopMediaProjectionRecorderService() {
        try {
            val intent = Intent(this, MediaProjectionRecorderService::class.java).apply {
                action = MediaProjectionRecorderService.ACTION_STOP
            }
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error deteniendo MediaProjectionRecorderService: ${e.message}")
        }
    }

    // ─── PhoneStateMonitorService ─────────────────────────────────────────────

    override fun onResume() {
        super.onResume()
        // NO iniciar PhoneStateMonitorService aquí: Flutter lo inicia cuando el usuario activa el monitor.
        // Iniciar en onResume puede causar crash en Android 12+ si la app aún no está lista.
        // Si el teléfono está en IDLE al volver al frente, detener cualquier grabación activa
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            if (tm?.callState == TelephonyManager.CALL_STATE_IDLE) {
                stopRecorderService()
                stopMediaProjectionRecorderService()
                Log.d(TAG, "onResume: teléfono IDLE → grabadores detenidos")
            }
        } catch (e: Exception) {
            Log.w(TAG, "onResume: ${e.message}")
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

    // ─── TelephonyCallback / PhoneStateListener ───────────────────────────────

    private fun startPhoneStateListener() {
        val hasPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) { Log.w(TAG, "Sin permiso READ_PHONE_STATE"); return }

        telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager

        val currentCallState = telephonyManager?.callState ?: TelephonyManager.CALL_STATE_IDLE
        if (currentCallState != TelephonyManager.CALL_STATE_IDLE) {
            lastState = currentCallState
            registeredDuringActiveCall = true
        } else {
            registeredDuringActiveCall = false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val executor = Executors.newSingleThreadExecutor()
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    val prefs = getSharedPreferences(CallRecorderService.SHARED_PREFS, Context.MODE_PRIVATE)
                    val number = prefs.getString("native_last_call_number", "").orEmpty()
                    handleCallStateChanged(state, number)
                }
            }
            telephonyCallback = cb
            telephonyManager?.registerTelephonyCallback(executor, cb)
        } else {
            @Suppress("DEPRECATION")
            val listener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, incomingNumber: String?) {
                    super.onCallStateChanged(state, incomingNumber ?: "")
                    handleCallStateChanged(state, incomingNumber ?: "")
                }
            }
            phoneStateListener = listener
            @Suppress("DEPRECATION")
            telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    @Suppress("DEPRECATION")
    private fun stopPhoneStateListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
            telephonyCallback = null
        } else {
            phoneStateListener?.let { telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE) }
            phoneStateListener = null
        }
    }

    private fun handleCallStateChanged(state: Int, incomingNumber: String) {
        if (lastState == state) return
        Log.d(TAG, "CallState: $lastState → $state  number=$incomingNumber  regDuringActive=$registeredDuringActiveCall")

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                if (incomingNumber.isNotBlank()) lastIncomingNumber = incomingNumber
                registeredDuringActiveCall = false
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (lastState != TelephonyManager.CALL_STATE_OFFHOOK) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    isIncoming = lastState == TelephonyManager.CALL_STATE_RINGING
                    if (!registeredDuringActiveCall) {
                        sendEvent("start", if (isIncoming) "incoming" else "outgoing", number)
                        // Iniciar grabación: MediaProjection si está disponible, sino CallRecorderService
                        if (mediaProjResultCode == Activity.RESULT_OK && mediaProjResultData != null) {
                            startMediaProjectionRecorderService(number)
                        } else {
                            startRecorderService(number)
                        }
                    }
                    registeredDuringActiveCall = false
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                    lastState == TelephonyManager.CALL_STATE_RINGING
                ) {
                    val number = incomingNumber.ifBlank { lastIncomingNumber }
                    sendEvent("end", if (isIncoming) "incoming" else "outgoing", number)
                    // Detener ambos servicios de grabación
                    stopMediaProjectionRecorderService()
                    stopRecorderService()
                }
                isIncoming = false
                lastIncomingNumber = ""
                registeredDuringActiveCall = false
            }
        }
        lastState = state
    }

    private fun startRecorderService(number: String) {
        try {
            val intent = Intent(this, CallRecorderService::class.java).apply {
                action = CallRecorderService.ACTION_START
                putExtra(CallRecorderService.EXTRA_CALL_NUMBER, number)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error iniciando CallRecorderService: ${e.message}")
        }
    }

    private fun stopRecorderService() {
        try {
            val intent = Intent(this, CallRecorderService::class.java).apply {
                action = CallRecorderService.ACTION_STOP
            }
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error deteniendo CallRecorderService: ${e.message}")
        }
    }

    private fun sendEvent(state: String, direction: String, number: String) {
        runOnUiThread {
            eventSink?.success(mapOf("state" to state, "direction" to direction, "number" to number))
        }
    }

    override fun onDestroy() {
        stopPhoneStateListener()
        super.onDestroy()
    }
}
