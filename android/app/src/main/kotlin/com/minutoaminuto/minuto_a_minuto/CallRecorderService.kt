package com.minutoaminuto.minuto_a_minuto

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.*
import android.os.*
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Servicio de grabación de llamadas.
 *
 * Estrategia en Samsung (Android 14+):
 *  - VOICE_CALL / VOICE_COMMUNICATION están bloqueados por Samsung → silencio
 *  - Solución: activar altavoz (speakerphone) durante la grabación y usar MIC
 *    El micrófono captura el audio del altavoz (voz remota) + tu voz
 *  - Al terminar: restaurar el modo de audio original
 *
 * Orden de intentos:
 *  1. MediaRecorder + MIC (altavoz activado) → M4A
 *  2. AudioRecord + MIC (altavoz activado) → WAV
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

        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CFG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FMT   = AudioFormat.ENCODING_PCM_16BIT
        private const val MAX_RECORD_MS     = 60L * 60 * 1000
        private const val WATCHDOG_INTERVAL = 20_000L

        val isRecording = AtomicBoolean(false)

        // Referencias estáticas para evitar que el GC destruya los objetos
        // mientras el servicio está grabando
        @Volatile var staticMediaRecorder: MediaRecorder? = null
        @Volatile var staticAudioRecord:   AudioRecord?   = null
    }

    private var mediaRecorder: MediaRecorder? = null
        set(value) { field = value; staticMediaRecorder = value }
    private var audioRecord:   AudioRecord?   = null
        set(value) { field = value; staticAudioRecord = value }
    private var recordThread:  Thread?        = null
    private var mainHandler:   Handler?       = null
    private var currentPath:   String?        = null
    private var usingAudioRecord = false

    private var audioManager: AudioManager? = null
    private var prevAudioMode = AudioManager.MODE_NORMAL
    private var prevSpeakerOn = false
    private var speakerActivated = false

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mainHandler  = Handler(Looper.getMainLooper())
        createNotificationChannel()
        // Limpiar mutex al crear el servicio por si quedó sucio de una sesión anterior
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
                    Log.w(TAG, "ACTION_START recibido pero teléfono en IDLE — ignorando")
                    mainHandler?.post {
                        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
                        try { stopSelf() } catch (_: Exception) {}
                    }
                    return START_NOT_STICKY
                }
                // Mutex global via SharedPreferences para evitar dos instancias grabando
                val prefs = getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                val alreadyRecording = prefs.getBoolean(KEY_RECORDING_MUTEX, false)
                if (alreadyRecording || isRecording.get()) {
                    Log.w(TAG, "Ya hay una grabación activa (mutex=$alreadyRecording atomic=${isRecording.get()}) — ignorando")
                    mainHandler?.post {
                        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
                        try { stopSelf() } catch (_: Exception) {}
                    }
                    return START_NOT_STICKY
                }
                prefs.edit().putBoolean(KEY_RECORDING_MUTEX, true).commit()
                startForegroundNotification()
                Thread { startRecording(number) }.start()
            }
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP recibido")
                stopAndSave()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        stopAndSave()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            if (tm?.callState == TelephonyManager.CALL_STATE_IDLE) stopAndSave()
        } catch (_: Exception) { stopAndSave() }
    }

    // ─── Inicio de grabación ──────────────────────────────────────────────────

    private fun startRecording(number: String) {
        val dir = resolveRecordingDir()
        val ts  = System.currentTimeMillis()

        // Activar altavoz para que el MIC capture ambas voces
        activateSpeaker()
        Thread.sleep(600)

        // Orden de intentos para Samsung Android 14+:
        // 1. VOICE_RECOGNITION  — en Samsung puede capturar audio de llamada
        // 2. UNPROCESSED        — sin cancelación de eco, capta el altavoz
        // 3. MIC                — fallback estándar
        // 4. VOICE_COMMUNICATION — último recurso
        // Si MediaRecorder falla → AudioRecord con los mismos sources

        val sources = listOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.UNPROCESSED,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
        )

        for ((idx, src) in sources.withIndex()) {
            val path = "${dir.absolutePath}/call_${ts}_${idx}.m4a"
            if (tryMediaRecorder(path, src)) {
                currentPath = path; usingAudioRecord = false
                isRecording.set(true)
                Log.d(TAG, "Grabando MediaRecorder src=$src: $path")
                scheduleWatchdogAndTimeout(); return
            }
        }

        // Fallback: AudioRecord (PCM→WAV)
        for ((idx, src) in sources.withIndex()) {
            val path = "${dir.absolutePath}/call_${ts}_ar${idx}.wav"
            if (tryAudioRecord(path, src)) {
                currentPath = path; usingAudioRecord = true
                isRecording.set(true)
                Log.d(TAG, "Grabando AudioRecord src=$src: $path")
                scheduleWatchdogAndTimeout(); return
            }
        }

        Log.e(TAG, "Todos los métodos de grabación fallaron")
        restoreSpeaker()
        mainHandler?.post { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    }

    // ─── Altavoz ──────────────────────────────────────────────────────────────

    private fun activateSpeaker() {
        try {
            val am = audioManager ?: return
            prevAudioMode  = am.mode
            prevSpeakerOn  = am.isSpeakerphoneOn
            am.mode = AudioManager.MODE_IN_CALL
            am.isSpeakerphoneOn = true
            speakerActivated = true
            Log.d(TAG, "Altavoz activado para grabación (prevMode=$prevAudioMode prevSpeaker=$prevSpeakerOn)")
        } catch (e: Exception) {
            Log.w(TAG, "activateSpeaker error: ${e.message}")
        }
    }

    private fun restoreSpeaker() {
        if (!speakerActivated) return
        try {
            val am = audioManager ?: return
            am.isSpeakerphoneOn = prevSpeakerOn
            am.mode = prevAudioMode
            speakerActivated = false
            Log.d(TAG, "Audio restaurado (mode=$prevAudioMode speaker=$prevSpeakerOn)")
        } catch (e: Exception) {
            Log.w(TAG, "restoreSpeaker error: ${e.message}")
        }
    }

    // ─── MediaRecorder ────────────────────────────────────────────────────────

    private fun tryMediaRecorder(path: String, audioSource: Int): Boolean {
        return try {
            val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                MediaRecorder(this) else @Suppress("DEPRECATION") MediaRecorder()

            mr.setAudioSource(audioSource)
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mr.setAudioEncodingBitRate(128_000)
            mr.setAudioSamplingRate(44100)
            mr.setAudioChannels(1)
            mr.setOutputFile(path)
            mr.prepare()
            mr.start()

            Thread.sleep(1200)
            val size = File(path).length()
            if (size < 1024) {
                try { mr.stop() } catch (_: Exception) {}
                mr.release()
                File(path).delete()
                Log.w(TAG, "MediaRecorder src=$audioSource: archivo muy pequeño ($size bytes)")
                return false
            }

            mediaRecorder = mr
            Log.d(TAG, "MediaRecorder src=$audioSource OK ($size bytes)")
            true
        } catch (e: Exception) {
            Log.w(TAG, "MediaRecorder src=$audioSource falló: ${e.message}")
            try { File(path).delete() } catch (_: Exception) {}
            false
        }
    }

    // ─── AudioRecord (PCM → WAV) ──────────────────────────────────────────────

    private fun tryAudioRecord(wavPath: String, audioSource: Int): Boolean {
        return try {
            val bufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT)
                .coerceAtLeast(8192)
            val ar = AudioRecord(
                audioSource,
                SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT, bufSize * 4
            )
            if (ar.state != AudioRecord.STATE_INITIALIZED) {
                ar.release()
                Log.w(TAG, "AudioRecord src=$audioSource: no inicializado")
                return false
            }
            ar.startRecording()
            Thread.sleep(300)
            if (ar.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                ar.stop(); ar.release()
                Log.w(TAG, "AudioRecord src=$audioSource: no grabando")
                return false
            }
            audioRecord = ar
            recordThread = Thread { writePcmToWav(ar, wavPath, bufSize) }
                .also { it.isDaemon = true; it.start() }
            Log.d(TAG, "AudioRecord src=$audioSource OK → $wavPath")
            true
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord src=$audioSource falló: ${e.message}")
            false
        }
    }

    private fun writePcmToWav(ar: AudioRecord, wavPath: String, bufSize: Int) {
        val pcmPath = wavPath.replace(".wav", ".pcm")
        try {
            FileOutputStream(pcmPath).use { fos ->
                val buf = ByteArray(bufSize)
                while (ar.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    val n = ar.read(buf, 0, buf.size)
                    if (n > 0) fos.write(buf, 0, n)
                }
            }
            convertPcmToWav(pcmPath, wavPath)
            File(pcmPath).delete()
            Log.d(TAG, "WAV listo: $wavPath (${File(wavPath).length()} bytes)")
            val f = File(wavPath)
            if (f.exists() && f.length() > 1024) savePathToPrefs(wavPath)
        } catch (e: Exception) {
            Log.e(TAG, "writePcmToWav error: ${e.message}")
        }
    }

    // ─── Parada ───────────────────────────────────────────────────────────────

    @Synchronized
    fun stopAndSave() {
        // Liberar mutex global siempre, incluso si no estábamos grabando
        try {
            getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_RECORDING_MUTEX, false).commit()
        } catch (_: Exception) {}

        if (!isRecording.getAndSet(false)) {
            mainHandler?.post {
                try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
                try { stopSelf() } catch (_: Exception) {}
            }
            return
        }

        mainHandler?.removeCallbacksAndMessages(null)

        val mr = mediaRecorder
        val ar = audioRecord
        mediaRecorder = null
        audioRecord   = null

        if (mr != null) {
            try { mr.stop()    } catch (_: Exception) {}
            try { mr.release() } catch (_: Exception) {}
        }
        if (ar != null) {
            try { ar.stop()    } catch (_: Exception) {}
            try { ar.release() } catch (_: Exception) {}
            recordThread?.join(10_000)
            recordThread = null
        }

        // Restaurar audio DESPUÉS de detener la grabación
        restoreSpeaker()

        val path = currentPath
        currentPath = null
        Log.d(TAG, "Grabación detenida. path=$path usingAudioRecord=$usingAudioRecord")

        if (!usingAudioRecord && path != null) {
            val f = File(path)
            if (f.exists() && f.length() > 1024) {
                savePathToPrefs(path)
                Log.d(TAG, "Ruta M4A guardada: $path (${f.length()} bytes)")
            } else {
                Log.w(TAG, "M4A inválido: ${f.length()} bytes")
            }
        }

        mainHandler?.post {
            try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
            try { stopSelf() } catch (_: Exception) {}
        }
    }

    // ─── Watchdog ─────────────────────────────────────────────────────────────

    private fun scheduleWatchdogAndTimeout() {
        mainHandler?.postDelayed({ Log.w(TAG, "Timeout 60min → deteniendo"); stopAndSave() }, MAX_RECORD_MS)
        scheduleWatchdog()
    }

    private fun scheduleWatchdog() {
        mainHandler?.postDelayed({
            if (!isRecording.get()) return@postDelayed
            try {
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                if (tm?.callState == TelephonyManager.CALL_STATE_IDLE) {
                    Log.w(TAG, "Watchdog: IDLE → deteniendo")
                    stopAndSave()
                } else scheduleWatchdog()
            } catch (_: Exception) { scheduleWatchdog() }
        }, WATCHDOG_INTERVAL)
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

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

    private fun convertPcmToWav(pcmPath: String, wavPath: String) {
        try {
            val pcm  = File(pcmPath)
            val size = pcm.length()
            if (size == 0L) { Log.w(TAG, "PCM vacío"); return }
            FileOutputStream(wavPath).use { out ->
                val hdr = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                val byteRate = SAMPLE_RATE * 2
                hdr.put("RIFF".toByteArray()); hdr.putInt((size + 36).toInt())
                hdr.put("WAVE".toByteArray()); hdr.put("fmt ".toByteArray())
                hdr.putInt(16); hdr.putShort(1); hdr.putShort(1)
                hdr.putInt(SAMPLE_RATE); hdr.putInt(byteRate)
                hdr.putShort(2); hdr.putShort(16)
                hdr.put("data".toByteArray()); hdr.putInt(size.toInt())
                out.write(hdr.array())
                pcm.inputStream().copyTo(out)
            }
        } catch (e: Exception) {
            Log.e(TAG, "convertPcmToWav error: ${e.message}")
        }
    }

    // ─── Notificación ─────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Grabación de llamadas",
                NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification() {
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Minuto a Minuto")
            .setContentText("Grabando llamada...")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true).build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else
            startForeground(NOTIF_ID, notif)
    }
}
