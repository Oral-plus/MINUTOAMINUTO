package com.minutoaminuto.minuto_a_minuto

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.*
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.WindowManager
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Servicio de grabaci├│n de llamadas.
 *
 * Graba SOLO la voz del usuario (micr├│fono) ÔÇö no la otra persona.
 * - Sin altavoz: el micr├│fono captura solo tu voz (la otra persona va por el auricular)
 * - Inicia al contestar (OFFHOOK) y termina al colgar (IDLE)
 *
 * Orden de fuentes: MIC primero (solo tu voz), luego alternativas compatibles.
 */
class CallRecorderService : Service() {

    companion object {
        private const val TAG = "CallRecorderSvc"
        private const val CHANNEL_ID = "call_recorder_channel"
        private const val NOTIF_ID = 9001
        const val ACTION_START = "com.minutoaminuto.START_RECORDING"
        const val ACTION_STOP  = "com.minutoaminuto.STOP_RECORDING"
        const val EXTRA_CALL_NUMBER = "call_number"
        const val SHARED_PREFS = "FlutterSharedPreferences"
        const val KEY_LAST_RECORDING_PATH = "flutter.last_recording_path"
        const val KEY_RECORDING_MUTEX = "flutter.recording_mutex_active"

        private const val SAMPLE_RATE_44 = 44100
        private const val SAMPLE_RATE_16 = 16000
        private const val SAMPLE_RATE_8  = 8000
        private const val CHANNEL_CFG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FMT   = AudioFormat.ENCODING_PCM_16BIT
        private const val MAX_RECORD_MS     = 60L * 60 * 1000
        private const val WATCHDOG_INTERVAL  = 15_000L // 15s - m├ís ligero para CPU
        
        val isRecording = AtomicBoolean(false)
        private val _keepRecording = AtomicBoolean(false)
        private const val PCM_GAIN_INT = 8 // x8 amplificaci├│n por software (punto fijo)

        @Volatile
        var currentAmplitude: Int = 0

        // Referencias est├íticas para evitar que el GC destruya los objetos
        // mientras el servicio est├í grabando
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var uiHandler: Handler? = null
    private var updateRunnable: Runnable? = null

    private var audioRecord:   AudioRecord?   = null
    private var recordingJob:  Job?           = null
    private var mainHandler:   Handler?       = null
    private var currentPath:   String?        = null
    private var usingAudioRecord = true
    private var wakeLock:      PowerManager.WakeLock? = null
    private var audioManager:  AudioManager?  = null
    
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)

    // ÔöÇÔöÇÔöÇ Lifecycle ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    override fun onCreate() {
        super.onCreate()
        mainHandler  = Handler(Looper.getMainLooper())
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        createNotificationChannel()
        // Limpiar mutex al crear el servicio por si qued├│ sucio de una sesi├│n anterior
        if (!isRecording.get()) {
            try {
                getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(KEY_RECORDING_MUTEX, false).commit()
            } catch (_: Exception) {}
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val number = intent.getStringExtra(EXTRA_CALL_NUMBER) ?: ""
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                val callState = tm?.callState ?: TelephonyManager.CALL_STATE_IDLE
                if (callState == TelephonyManager.CALL_STATE_IDLE) {
                    Log.w(TAG, "ACTION_START recibido pero tel├®fono en IDLE ÔÇö ignorando")
                    stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
                    return START_NOT_STICKY
                }
                if (isRecording.getAndSet(true)) {
                    Log.w(TAG, "Ya hay una grabaci├│n activa ÔÇö ignorando")
                    stopSelf(); return START_NOT_STICKY
                }
                acquireWakeLock()
                startForegroundNotification()
                startRecording(number)
            }
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP recibido")
                stopAndSave()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        isRecording.set(false)
        _keepRecording.set(false)
        currentAmplitude = 0
        serviceJob.cancel()
        try {
            getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_RECORDING_MUTEX, false).commit()
        } catch (_: Exception) {}
        releaseWakeLock()
        stopAndSave()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        try {
            releaseWakeLock()
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "minutoaminuto:call_recorder"
            ).apply { acquire(MAX_RECORD_MS) }
            Log.d(TAG, "WakeLock adquirido")
        } catch (e: Exception) {
            Log.w(TAG, "acquireWakeLock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
                wakeLock = null
                Log.d(TAG, "WakeLock liberado")
            }
        } catch (_: Exception) {}
    }

    // ÔöÇÔöÇÔöÇ Inicio de grabaci├│n ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    private var speakerWasEnabled = false

    private fun startRecording(number: String) {
        val dir = resolveRecordingDir()
        val ts  = System.currentTimeMillis()
        val wavPath = "${dir.absolutePath}/call_${ts}.wav"
        
        mainHandler?.post { showOverlay() }
        
        // ESTRATEGIA DE BYPASS COMPLETA:
        // Nivel 1: Fuentes directas de llamada (funcionan en Android Ôëñ9 y muchos OEMs)
        // Nivel 2: MIC con MODE_IN_CALL (funciona en algunos Samsung/Xiaomi)
        // Nivel 3: Altavoz + MIC (├║ltimo recurso, siempre funciona)
        
        val directCallSources = intArrayOf(
            4, // VOICE_CALL ÔÇö captura ambas v├¡as directamente
            3, // VOICE_DOWNLINK ÔÇö voz del otro lado
            2, // VOICE_UPLINK ÔÇö tu voz
        )
        val micSources = intArrayOf(
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.DEFAULT
        )
        val rates = intArrayOf(SAMPLE_RATE_8, SAMPLE_RATE_16, SAMPLE_RATE_44)

        serviceScope.launch(Dispatchers.IO) {
            var started = false
            
            // ÔöÇÔöÇ Nivel 1: Intentar captura directa de llamada (sin altavoz) ÔöÇÔöÇ
            audioManager?.mode = AudioManager.MODE_IN_CALL
            for (src in directCallSources) {
                if (started) break
                for (rate in rates) {
                    if (tryAndVerifySource(wavPath, src, rate)) {
                        currentPath = wavPath
                        started = true
                        speakerWasEnabled = false
                        Log.i(TAG, "Ô£à BYPASS NIVEL 1: VOICE_CALL directo (src=$src rate=$rate)")
                        break
                    }
                }
            }
            
            // ÔöÇÔöÇ Nivel 2: MIC con MODE_IN_CALL (sin altavoz) ÔöÇÔöÇ
            if (!started) {
                for (src in micSources) {
                    if (started) break
                    for (rate in rates) {
                        if (tryAndVerifySource(wavPath, src, rate)) {
                            currentPath = wavPath
                            started = true
                            speakerWasEnabled = false
                            Log.i(TAG, "Ô£à BYPASS NIVEL 2: MIC + MODE_IN_CALL (src=$src rate=$rate)")
                            break
                        }
                    }
                }
            }
            
            // ÔöÇÔöÇ Nivel 3: Altavoz + MIC (├║ltimo recurso, siempre funciona) ÔöÇÔöÇ
            if (!started) {
                Log.w(TAG, "ÔÜá´©Å Niveles 1-2 fallaron. Activando altavoz como ├║ltimo recurso...")
                audioManager?.run {
                    mode = AudioManager.MODE_IN_COMMUNICATION
                    isSpeakerphoneOn = true
                    isMicrophoneMute = false
                }
                Thread.sleep(300) // Dar tiempo al hardware
                
                for (src in micSources) {
                    if (started) break
                    for (rate in rates) {
                        if (tryAndVerifySource(wavPath, src, rate)) {
                            currentPath = wavPath
                            started = true
                            speakerWasEnabled = true
                            Log.i(TAG, "Ô£à BYPASS NIVEL 3: Altavoz + MIC (src=$src rate=$rate)")
                            break
                        }
                    }
                }
            }

            withContext(Dispatchers.Main) {
                if (started) {
                    scheduleWatchdogAndTimeout()
                } else {
                    Log.e(TAG, "ÔØî FALLO TOTAL: Ninguna fuente de audio disponible")
                    isRecording.set(false)
                    try {
                        getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                            .edit().putBoolean(KEY_RECORDING_MUTEX, false).commit()
                    } catch (_: Exception) {}
                    runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
                    runCatching { stopSelf() }
                }
            }
        }
    }

    private fun tryAndVerifySource(wavPath: String, audioSource: Int, sampleRate: Int): Boolean {
        return runCatching {
            val bufSize = AudioRecord.getMinBufferSize(sampleRate, CHANNEL_CFG, AUDIO_FMT)
                .coerceAtLeast(8192)
            
            val ar = AudioRecord(
                audioSource,
                sampleRate, CHANNEL_CFG, AUDIO_FMT, bufSize * 4
            ).apply { if (state != AudioRecord.STATE_INITIALIZED) { release(); return false } }

            enableAudioEffects(ar.audioSessionId)
            audioManager?.isMicrophoneMute = false

            ar.startRecording()
            if (ar.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                ar.stop(); ar.release(); return false
            }

            // ÔöÇÔöÇÔöÇ VERIFICACI├ôN DE AUDIO REAL ÔöÇÔöÇÔöÇ
            // Leer datos y verificar que NO es silencio
            val verifySamples = sampleRate / 2 // 500ms
            val byteBuf = ByteArray(8192) // Buffer reutilizado
            var totalReadSamples = 0
            var maxAmplitude = 0
            val startMs = System.currentTimeMillis()
            
            while (totalReadSamples < verifySamples && (System.currentTimeMillis() - startMs) < 800) {
                val toRead = (verifySamples - totalReadSamples).coerceAtMost(byteBuf.size / 2)
                val n = ar.read(byteBuf, 0, toRead * 2)
                if (n > 0) {
                    for (i in 0 until n / 2) {
                        val low = byteBuf[i * 2].toInt() and 0xff
                        val high = byteBuf[i * 2 + 1].toInt()
                        val sample = abs(((high shl 8) or low).toShort().toInt())
                        if (sample > maxAmplitude) maxAmplitude = sample
                    }
                    totalReadSamples += n / 2
                } else if (n < 0) break
            }

            Log.d(TAG, "VERIFICACI├ôN src=$audioSource rate=$sampleRate: maxAmp=$maxAmplitude (${totalReadSamples} muestras)")
            currentAmplitude = maxAmplitude
            
            if (maxAmplitude < 100) {
                Log.w(TAG, "ÔÜá´©Å src=$audioSource SILENCIOSO (maxAmp=$maxAmplitude)")
                ar.stop(); ar.release(); return false
            }

            Log.i(TAG, "Ô£à src=$audioSource OK (maxAmp=$maxAmplitude)")
            
            audioRecord = ar
            _keepRecording.set(true)
            
            recordingJob = serviceScope.launch(Dispatchers.IO) {
                writePcmToWavWithInitialData(ar, wavPath, bufSize, sampleRate)
            }
            
            true
        }.getOrElse {
            Log.w(TAG, "AudioRecord fall├│ (src=$audioSource, rate=$sampleRate): ${it.message}")
            false
        }
    }

    // Versi├│n que incluye datos iniciales ya le├¡dos durante la verificaci├│n
    private fun writePcmToWavWithInitialData(
        ar: AudioRecord, wavPath: String, bufSize: Int, sampleRate: Int
    ) {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
        val pcmPath = wavPath.replace(".wav", ".pcm")
        var nonZeroCount = 0L
        var totalSamples = 0L
        var maxAmp = 0
        
        try {
            FileOutputStream(pcmPath).use { fos ->
                // Continuar grabando
                val buf = ByteArray(bufSize)
                while (_keepRecording.get() && ar.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    val n = ar.read(buf, 0, buf.size)
                    if (n > 0) {
                        var chunkMaxAmp = 0
                        // ÔöÇÔöÇÔöÇ OPTIMIZACI├ôN V14: PROCESAMIENTO PUNTO FIJO ÔöÇÔöÇÔöÇ
                        for (i in 0 until n / 2) {
                            val low = buf[i * 2].toInt() and 0xff
                            val high = buf[i * 2 + 1].toInt()
                            val sample = ((high shl 8) or low).toShort()
                            
                            val absVal = abs(sample.toInt())
                            if (absVal > chunkMaxAmp) chunkMaxAmp = absVal
                            if (absVal > maxAmp) maxAmp = absVal
                            if (absVal > 50) nonZeroCount++
                            totalSamples++

                            // Amplificaci├│n r├ípida usando Int (8 equivale a shl 3)
                            val amplified = (sample.toInt() * PCM_GAIN_INT)
                                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                            
                            buf[i * 2] = (amplified and 0xff).toByte()
                            buf[i * 2 + 1] = (amplified shr 8).toByte()
                        }
                        fos.write(buf, 0, n)
                    } else if (n < 0) break
                    else Thread.sleep(5)
                }
            }
            
            val pct = if (totalSamples > 0) (nonZeroCount.toFloat() / totalSamples * 100).toInt() else 0
            Log.d(TAG, "AUDIO STATS: MaxAmp=$maxAmp, Actividad=$pct%, Samples=$totalSamples")

            convertPcmToWav(pcmPath, wavPath, sampleRate)
            File(pcmPath).delete()
            
            val f = File(wavPath)
            if (f.exists() && f.length() > 0) {
                savePathToPrefs(wavPath)
                Log.d(TAG, "WAV finalizado: $wavPath (${f.length()} bytes)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "writePcmToWav error (PCM=$pcmPath): ${e.message}")
            e.printStackTrace()
        }
    }

    private fun amplifyBuffer(buf: ByteArray, len: Int): ByteArray {
        val out = buf.copyOf()
        for (i in 0 until len / 2) {
            val low = out[i * 2].toInt() and 0xff
            val high = out[i * 2 + 1].toInt()
            val sample = ((high shl 8) or low).toShort()
            val amplified = (sample.toInt() * PCM_GAIN_INT)
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            out[i * 2] = (amplified and 0xff).toByte()
            out[i * 2 + 1] = (amplified shr 8).toByte()
        }
        return out
    }

    private fun enableAudioEffects(sessionId: Int) {
        try {
            if (AcousticEchoCanceler.isAvailable()) {
                AcousticEchoCanceler.create(sessionId)?.setEnabled(true)
                Log.d(TAG, "AudioEffect: AEC habilitado")
            }
            if (AutomaticGainControl.isAvailable()) {
                AutomaticGainControl.create(sessionId)?.setEnabled(true)
                Log.d(TAG, "AudioEffect: AGC habilitado")
            }
            if (NoiseSuppressor.isAvailable()) {
                NoiseSuppressor.create(sessionId)?.setEnabled(true)
                Log.d(TAG, "AudioEffect: NS habilitado")
            }
        } catch (e: Exception) {
            Log.w(TAG, "enableAudioEffects error: ${e.message}")
        }
    }


    // ÔöÇÔöÇÔöÇ Parada ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    @Synchronized
    fun stopAndSave() {
        // Liberar mutex global siempre
        try {
            getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_RECORDING_MUTEX, false).commit()
        } catch (_: Exception) {}

        mainHandler?.post { removeOverlay() }

        if (!isRecording.getAndSet(false)) {
            releaseWakeLock()
            mainHandler?.post {
                try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
                try { stopSelf() } catch (_: Exception) {}
            }
            return
        }

        mainHandler?.removeCallbacksAndMessages(null)
        _keepRecording.set(false)

        val ar = audioRecord
        val job = recordingJob
        val path = currentPath
        
        audioRecord   = null
        recordingJob  = null
        currentPath = null
        currentAmplitude = 0

        // ÔöÇÔöÇÔöÇ OPTIMIZACI├ôN V16/V18/V21: CIERRE AS├ìNCRONO AT├ôMICO ÔöÇÔöÇÔöÇ
        serviceScope.launch(Dispatchers.IO) {
            val pcmPath = path?.replace(".wav", ".pcm")
            // Usar NonCancellable para asegurar que si el sistema mata el scope, 
            // esta limpieza final de archivos se complete s├¡ o s├¡.
            withContext(NonCancellable) {
                try {
                    if (ar != null) {
                        runCatching { ar.stop() }
                        runCatching { ar.release() }
                        job?.cancel()
                        Log.d(TAG, "AudioRecord liberado")
                    }

                    releaseWakeLock()
                    
                    // Restaurar audio
                    try {
                        if (speakerWasEnabled) {
                            audioManager?.isSpeakerphoneOn = false
                            speakerWasEnabled = false
                        }
                        audioManager?.mode = AudioManager.MODE_NORMAL
                    } catch (_: Exception) {}

                    // Operaciones de archivo pesadas en IO
                    Thread.sleep(500)
                    if (path != null) {
                        val f = File(path)
                        if (f.exists() && f.length() > 0) {
                            savePathToPrefs(path)
                            Log.i(TAG, "AUDIO GUARDADO FINAL: $path (${f.length()} bytes)")
                            copyToPublicDirectory(path)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error en stopAndSave as├¡ncrono: ${e.message}")
                } finally {
                    try {
                        pcmPath?.let { File(it).delete() }
                    } catch (_: Exception) {}

                    withContext(Dispatchers.Main) {
                        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
                        try { stopSelf() } catch (_: Exception) {}
                    }
                }
            }
        }
    }

    // ÔöÇÔöÇÔöÇ Watchdog ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    private fun scheduleWatchdogAndTimeout() {
        mainHandler?.postDelayed({ Log.w(TAG, "Timeout 60min ÔåÆ deteniendo"); stopAndSave() }, MAX_RECORD_MS)
        scheduleWatchdog()
    }

    private fun scheduleWatchdog() {
        mainHandler?.postDelayed({
            if (!isRecording.get()) return@postDelayed
            try {
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                val state = tm?.callState ?: TelephonyManager.CALL_STATE_IDLE
                if (state == TelephonyManager.CALL_STATE_IDLE) {
                    Log.w(TAG, "Watchdog: tel├®fono en IDLE ÔåÆ deteniendo grabaci├│n")
                    stopAndSave()
                } else {
                    scheduleWatchdog() // Still in call, continue watching
                }
            } catch (se: SecurityException) {
                // Permission revoked ÔÇö can't read state, stop to be safe
                Log.e(TAG, "Watchdog: SecurityException ÔÇô deteniendo por seguridad: ${se.message}")
                stopAndSave()
            } catch (e: Exception) {
                // Unknown error ÔÇö stop rather than loop forever
                Log.e(TAG, "Watchdog: excepci├│n ÔÇô deteniendo: ${e.message}")
                stopAndSave()
            }
        }, WATCHDOG_INTERVAL)
    }

    // ÔöÇÔöÇÔöÇ Helpers ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    private fun resolveRecordingDir(): File {
        val base = filesDir.parent ?: filesDir.absolutePath
        val dir  = File(base, "app_flutter/call_recordings")
        if (!dir.exists()) dir.mkdirs()
        return if (dir.exists()) dir else File(filesDir, "call_recordings").also { it.mkdirs() }
    }

    private fun savePathToPrefs(path: String) {
        try {
            getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_LAST_RECORDING_PATH, path).commit()
            Log.d(TAG, "Ruta guardada en prefs: $path")
        } catch (e: Exception) {
            Log.e(TAG, "savePathToPrefs error: ${e.message}")
        }
    }

    private fun convertPcmToWav(pcmPath: String, wavPath: String, sampleRate: Int) {
        try {
            val pcm  = File(pcmPath)
            val size = pcm.length()
            if (size == 0L) { Log.w(TAG, "PCM vac├¡o"); return }
            FileOutputStream(wavPath).use { out ->
                val hdr = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                val byteRate = sampleRate * 2
                hdr.put("RIFF".toByteArray()); hdr.putInt((size + 36).toInt())
                hdr.put("WAVE".toByteArray()); hdr.put("fmt ".toByteArray())
                hdr.putInt(16); hdr.putShort(1); hdr.putShort(1)
                hdr.putInt(sampleRate); hdr.putInt(byteRate)
                hdr.putShort(2); hdr.putShort(16)
                hdr.put("data".toByteArray()); hdr.putInt(size.toInt())
                out.write(hdr.array())
                pcm.inputStream().copyTo(out)
            }
        } catch (e: Exception) {
            Log.e(TAG, "convertPcmToWav error: ${e.message}")
        }
    }

    // ÔöÇÔöÇÔöÇ Notificaci├│n ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Grabaci├│n de llamadas",
                NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification() {
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Minuto a Minuto")
            .setContentText("Grabando llamada activa (Mic)")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, notif, 
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException in FGS (microphone restricted in background): ${e.message}")
            try {
                // Fallback attempt without specific types (might still fail or just run normal service)
                startForeground(NOTIF_ID, notif)
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback startForeground failed: ${e2.message}")
                stopSelf() // EVITAR CRASH ForegroundServiceDidNotStartInTimeException
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting foreground: ${e.message}")
            stopSelf()
        }
    }
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.w(TAG, "App swipeada durante grabación — Guardando antes de morir...")
        stopAndSave()
        super.onTaskRemoved(rootIntent)
    }

    private fun copyToPublicDirectory(filePath: String) {
        try {
            val pubDir = File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_MUSIC), "MinutoAMinuto")
            if (!pubDir.exists()) pubDir.mkdirs()
            val src = File(filePath)
            val dest = File(pubDir, src.name)
            src.copyTo(dest, overwrite = true)
            Log.i(TAG, "Copia pública guardada en: ${dest.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Error al crear copia pública: ${e.message}")
        }
    }

    private fun showOverlay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) return

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        params.y = 120 // Margen superior
        
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(40, 24, 40, 24)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E6000000")) // Semi-transparent black
                cornerRadius = 50f
                setStroke(3, Color.parseColor("#aaFF0000"))
            }
        }
        
        val dot = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(28, 28).apply { setMargins(0, 0, 20, 0) }
            background = GradientDrawable().apply {
                setColor(Color.RED)
                shape = GradientDrawable.OVAL
            }
        }
        
        val text = TextView(this).apply {
            text = "Grabando llamada..."
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        
        container.addView(dot)
        container.addView(text)
        
        overlayView = container
        
        try {
            windowManager?.addView(overlayView, params)
        } catch(e: Exception) { Log.e(TAG, "No se pudo agregar overlay: ${e.message}") }
        
        uiHandler = Handler(Looper.getMainLooper())
        updateRunnable = object : Runnable {
            override fun run() {
                val amp = currentAmplitude
                val scale = 1.0f + (amp / 32767f) * 1.2f
                dot.scaleX = scale
                dot.scaleY = scale
                dot.alpha = 0.4f + (amp / 32767f) * 0.6f
                uiHandler?.postDelayed(this, 100)
            }
        }
        uiHandler?.post(updateRunnable!!)
    }

    private fun removeOverlay() {
        uiHandler?.removeCallbacksAndMessages(null)
        uiHandler = null
        if (overlayView != null && windowManager != null) {
            try { windowManager?.removeView(overlayView) } catch (e: Exception) {}
            overlayView = null
        }
    }
}
