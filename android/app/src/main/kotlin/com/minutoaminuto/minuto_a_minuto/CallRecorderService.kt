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
import android.os.PowerManager
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
        private const val MAX_RECORD_MS     = 90L * 60 * 1000  // 90 minutos
        private const val WATCHDOG_INTERVAL = 10_000L  // Verificar cada 10s
        private const val AUDIO_BUFFER_MULTIPLIER = 8  // Buffer más grande para evitar cortes
        private const val WRITE_BUFFER_SIZE = 16384    // Buffer de escritura optimizado

        val isRecording = AtomicBoolean(false)

        // Referencias estáticas para evitar que el GC destruya los objetos
        // mientras el servicio está grabando
        @Volatile var staticMediaRecorder: MediaRecorder? = null
        @Volatile var staticAudioRecord:   AudioRecord?   = null
        @Volatile var staticService: CallRecorderService? = null
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
    private var wakeLock: PowerManager.WakeLock? = null

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        staticService = this
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mainHandler  = Handler(Looper.getMainLooper())
        createNotificationChannel()
        // Configurar el proceso como prioritario para evitar que Android lo mate
        try {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
        } catch (_: Exception) {}
        
        // Adquirir WakeLock para mantener la CPU activa durante la grabación
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "MinutoAMinuto::CallRecordingWakeLock"
            ).apply {
                setReferenceCounted(false)
            }
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo crear WakeLock: ${e.message}")
        }
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

        // Adquirir WakeLock para la duración de la grabación (máximo 90 minutos)
        try {
            wakeLock?.acquire(MAX_RECORD_MS)
            Log.d(TAG, "WakeLock adquirido para grabación")
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo adquirir WakeLock: ${e.message}")
        }

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
            // Bitrate más alto para mejor calidad y menos cortes
            mr.setAudioEncodingBitRate(192_000)
            mr.setAudioSamplingRate(SAMPLE_RATE)
            mr.setAudioChannels(1)
            mr.setOutputFile(path)
            
            // Configurar listener para errores durante la grabación
            mr.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaRecorder error: what=$what extra=$extra")
                // Intentar recuperarse reiniciando con AudioRecord
                if (isRecording.get() && !usingAudioRecord) {
                    mainHandler?.post { attemptRecoveryWithAudioRecord() }
                }
            }
            
            mr.setOnInfoListener { _, what, extra ->
                Log.d(TAG, "MediaRecorder info: what=$what extra=$extra")
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED ||
                    what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    mainHandler?.post { stopAndSave() }
                }
            }
            
            mr.prepare()
            mr.start()

            // Dar más tiempo para estabilizar la grabación
            Thread.sleep(1500)
            val size = File(path).length()
            if (size < 512) {
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
    
    private fun attemptRecoveryWithAudioRecord() {
        if (!isRecording.get()) return
        Log.d(TAG, "Intentando recuperación con AudioRecord...")
        
        // Detener MediaRecorder si está activo
        val mr = mediaRecorder
        mediaRecorder = null
        try { mr?.stop() } catch (_: Exception) {}
        try { mr?.release() } catch (_: Exception) {}
        
        val dir = resolveRecordingDir()
        val ts = System.currentTimeMillis()
        val sources = listOf(
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
        )
        
        for ((idx, src) in sources.withIndex()) {
            val path = "${dir.absolutePath}/call_${ts}_recovery_$idx.wav"
            if (tryAudioRecord(path, src)) {
                currentPath = path
                usingAudioRecord = true
                Log.d(TAG, "Recuperación exitosa con AudioRecord: $path")
                return
            }
        }
        Log.e(TAG, "No se pudo recuperar la grabación")
    }

    // ─── AudioRecord (PCM → WAV) ──────────────────────────────────────────────

    private fun tryAudioRecord(wavPath: String, audioSource: Int): Boolean {
        return try {
            val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT)
            if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
                Log.w(TAG, "AudioRecord src=$audioSource: buffer size inválido")
                return false
            }
            // Buffer significativamente más grande para evitar overruns y cortes
            val bufSize = (minBufSize * AUDIO_BUFFER_MULTIPLIER).coerceAtLeast(32768)
            
            val ar = AudioRecord(
                audioSource,
                SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT, bufSize
            )
            if (ar.state != AudioRecord.STATE_INITIALIZED) {
                ar.release()
                Log.w(TAG, "AudioRecord src=$audioSource: no inicializado")
                return false
            }
            
            // Configurar notificación de posición para monitorear la grabación
            ar.positionNotificationPeriod = SAMPLE_RATE // Cada segundo
            ar.setRecordPositionUpdateListener(object : AudioRecord.OnRecordPositionUpdateListener {
                override fun onMarkerReached(recorder: AudioRecord?) {}
                override fun onPeriodicNotification(recorder: AudioRecord?) {
                    // Verificar que la grabación sigue activa
                    if (recorder?.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                        Log.w(TAG, "AudioRecord detenido inesperadamente")
                    }
                }
            })
            
            ar.startRecording()
            Thread.sleep(400)
            if (ar.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                ar.stop(); ar.release()
                Log.w(TAG, "AudioRecord src=$audioSource: no grabando")
                return false
            }
            audioRecord = ar
            
            // Thread de grabación con prioridad alta
            recordThread = Thread {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
                writePcmToWav(ar, wavPath, bufSize)
            }.also { 
                it.isDaemon = false  // No daemon para evitar terminación prematura
                it.priority = Thread.MAX_PRIORITY
                it.start() 
            }
            Log.d(TAG, "AudioRecord src=$audioSource OK (buffer=${bufSize}) → $wavPath")
            true
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord src=$audioSource falló: ${e.message}")
            false
        }
    }

    private fun writePcmToWav(ar: AudioRecord, wavPath: String, bufSize: Int) {
        val pcmPath = wavPath.replace(".wav", ".pcm")
        var totalBytesWritten = 0L
        var consecutiveErrors = 0
        val maxConsecutiveErrors = 5
        
        try {
            FileOutputStream(pcmPath).use { fos ->
                // Buffer optimizado para escritura
                val buf = ByteArray(WRITE_BUFFER_SIZE.coerceAtMost(bufSize))
                var lastLogTime = System.currentTimeMillis()
                
                while (isRecording.get() && ar.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    val n = ar.read(buf, 0, buf.size)
                    when {
                        n > 0 -> {
                            fos.write(buf, 0, n)
                            totalBytesWritten += n
                            consecutiveErrors = 0
                            
                            // Log cada 30 segundos para monitoreo
                            val now = System.currentTimeMillis()
                            if (now - lastLogTime > 30_000) {
                                Log.d(TAG, "Grabación en progreso: ${totalBytesWritten / 1024}KB")
                                lastLogTime = now
                            }
                        }
                        n == AudioRecord.ERROR_INVALID_OPERATION -> {
                            Log.w(TAG, "AudioRecord: ERROR_INVALID_OPERATION")
                            consecutiveErrors++
                            if (consecutiveErrors >= maxConsecutiveErrors) {
                                Log.e(TAG, "Demasiados errores consecutivos, deteniendo")
                                break
                            }
                            Thread.sleep(50)
                        }
                        n == AudioRecord.ERROR_BAD_VALUE -> {
                            Log.w(TAG, "AudioRecord: ERROR_BAD_VALUE")
                            consecutiveErrors++
                            if (consecutiveErrors >= maxConsecutiveErrors) break
                            Thread.sleep(50)
                        }
                        n == AudioRecord.ERROR_DEAD_OBJECT -> {
                            Log.e(TAG, "AudioRecord: DEAD_OBJECT - grabación terminada")
                            break
                        }
                        n == 0 -> {
                            // Sin datos disponibles, esperar un poco
                            Thread.sleep(10)
                        }
                    }
                }
                
                // Flush final
                fos.flush()
            }
            
            Log.d(TAG, "PCM completado: $totalBytesWritten bytes")
            
            if (totalBytesWritten > 1024) {
                convertPcmToWav(pcmPath, wavPath)
                File(pcmPath).delete()
                Log.d(TAG, "WAV listo: $wavPath (${File(wavPath).length()} bytes)")
                val f = File(wavPath)
                if (f.exists() && f.length() > 1024) savePathToPrefs(wavPath)
            } else {
                Log.w(TAG, "Grabación muy corta: $totalBytesWritten bytes")
                File(pcmPath).delete()
            }
        } catch (e: Exception) {
            Log.e(TAG, "writePcmToWav error: ${e.message}")
            try { File(pcmPath).delete() } catch (_: Exception) {}
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
        
        // Liberar WakeLock
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock liberado")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error liberando WakeLock: ${e.message}")
        }

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
