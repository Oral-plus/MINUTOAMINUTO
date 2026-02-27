package com.minutoaminuto.minuto_a_minuto

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

// Samsung bloquea VOICE_COMMUNICATION/VOICE_CALL → usamos MIC con altavoz activado

/**
 * Graba el audio del sistema (voz de la otra persona) + micrófono (tu voz)
 * usando MediaProjection API.
 *
 * Flujo:
 *  1. MainActivity solicita permiso MediaProjection al usuario (diálogo del sistema)
 *  2. El usuario aprueba → MainActivity guarda el Intent de resultado
 *  3. Al inicio de llamada → se inicia este servicio con el Intent de MediaProjection
 *  4. Graba AUDIO_PLAYBACK (voz remota) + MIC (tu voz) en pistas separadas
 *  5. Mezcla ambas pistas en un único archivo WAV
 *  6. Guarda la ruta en SharedPreferences para que Flutter la consuma
 *
 * Requiere API 29+ para AUDIO_PLAYBACK capture.
 * En API < 29 cae en fallback al MIC únicamente.
 */
class MediaProjectionRecorderService : Service() {

    companion object {
        private const val TAG = "MediaProjRecorder"
        private const val CHANNEL_ID = "media_proj_recorder_channel"
        private const val NOTIF_ID = 9004

        const val ACTION_START = "com.minutoaminuto.MEDIA_PROJ_START"
        const val ACTION_STOP  = "com.minutoaminuto.MEDIA_PROJ_STOP"
        const val EXTRA_RESULT_CODE   = "result_code"
        const val EXTRA_RESULT_DATA   = "result_data"
        const val EXTRA_CALL_NUMBER   = "call_number"

        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CFG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FMT   = AudioFormat.ENCODING_PCM_16BIT

        val isRecording = AtomicBoolean(false)
    }

    private var mediaProjection: MediaProjection? = null
    private var playbackRecord: AudioRecord? = null   // audio del sistema (voz remota)
    private var micRecord: AudioRecord? = null        // micrófono (tu voz)
    private var mixThread: Thread? = null
    private var currentPath: String? = null

    private var audioManager: AudioManager? = null
    private var prevAudioMode = AudioManager.MODE_NORMAL
    private var prevSpeakerOn = false
    private var speakerActivated = false

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
    }

    private fun activateSpeaker() {
        try {
            val am = audioManager ?: return
            prevAudioMode = am.mode
            prevSpeakerOn = am.isSpeakerphoneOn
            am.mode = AudioManager.MODE_IN_CALL
            am.isSpeakerphoneOn = true
            speakerActivated = true
            Log.d(TAG, "Altavoz activado para MediaProjection")
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
            Log.d(TAG, "Audio restaurado en MediaProjection")
        } catch (e: Exception) {
            Log.w(TAG, "restoreSpeaker error: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                if (isRecording.get()) {
                    Log.d(TAG, "Ya grabando, ignorando ACTION_START")
                    return START_NOT_STICKY
                }
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                val resultData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_RESULT_DATA)
                }
                val number = intent.getStringExtra(EXTRA_CALL_NUMBER) ?: ""

                if (resultCode != Activity.RESULT_OK || resultData == null) {
                    Log.w(TAG, "MediaProjection no autorizado — usando solo MIC")
                    startForegroundNotification()
                    Thread { startMicOnlyRecording(number) }.start()
                } else {
                    startForegroundNotification()
                    Thread { startMediaProjectionRecording(resultCode, resultData, number) }.start()
                }
            }
            ACTION_STOP -> stopAndSave()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopAndSave()
        super.onDestroy()
    }

    // ─── Grabación con MediaProjection (API 29+) ──────────────────────────────

    private fun startMediaProjectionRecording(resultCode: Int, resultData: Intent, number: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            Log.w(TAG, "API < 29 — MediaProjection audio no disponible, usando MIC")
            startMicOnlyRecording(number)
            return
        }

        try {
            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = mgr.getMediaProjection(resultCode, resultData)
            if (projection == null) {
                Log.w(TAG, "MediaProjection null — usando MIC")
                startMicOnlyRecording(number)
                return
            }
            mediaProjection = projection

            val dir = resolveRecordingDir()
            val ts  = System.currentTimeMillis()
            val wavPath = "${dir.absolutePath}/call_${ts}.wav"
            currentPath = wavPath

            val bufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT)
                .coerceAtLeast(8192)

            // ── Captura de audio del sistema (voz remota) ──
            val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .build()

            val playbackAudioFormat = AudioFormat.Builder()
                .setEncoding(AUDIO_FMT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(CHANNEL_CFG)
                .build()

            val pbRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(playbackConfig)
                .setAudioFormat(playbackAudioFormat)
                .setBufferSizeInBytes(bufSize * 4)
                .build()

            // ── Activar altavoz para que MIC capture la voz remota también ──
            activateSpeaker()
            Thread.sleep(300)

            // ── Captura de micrófono (tu voz + eco del altavoz = voz remota) ──
            val micRec = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT, bufSize * 4
            )

            val pbOk = pbRecord.state == AudioRecord.STATE_INITIALIZED
            val micOk = micRec.state == AudioRecord.STATE_INITIALIZED

            if (!pbOk && !micOk) {
                pbRecord.release(); micRec.release()
                Log.e(TAG, "Ningún AudioRecord inicializado")
                stopSelfSafe(); return
            }

            if (pbOk) { pbRecord.startRecording(); playbackRecord = pbRecord }
            else { pbRecord.release() }

            if (micOk) { micRec.startRecording(); micRecord = micRec }
            else { micRec.release() }

            isRecording.set(true)
            Log.d(TAG, "Grabando con MediaProjection + MIC → $wavPath")

            mixThread = Thread { mixAndWriteWav(wavPath, bufSize) }
                .also { it.isDaemon = true; it.start() }

        } catch (e: Exception) {
            Log.e(TAG, "startMediaProjectionRecording error: ${e.message}")
            startMicOnlyRecording(number)
        }
    }

    // ─── Fallback: solo micrófono ─────────────────────────────────────────────

    private fun startMicOnlyRecording(number: String) {
        try {
            val dir = resolveRecordingDir()
            val ts  = System.currentTimeMillis()
            val wavPath = "${dir.absolutePath}/call_${ts}_mic.wav"
            currentPath = wavPath

            val bufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT)
                .coerceAtLeast(8192)

            // Activar altavoz para capturar ambas voces con MIC
            activateSpeaker()
            Thread.sleep(300)

            // Samsung bloquea VOICE_COMMUNICATION/VOICE_CALL → usar solo MIC con altavoz
            val ar = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE, CHANNEL_CFG, AUDIO_FMT, bufSize * 4
            )

            if (ar.state != AudioRecord.STATE_INITIALIZED) {
                ar.release()
                Log.e(TAG, "No se pudo inicializar AudioRecord MIC")
                restoreSpeaker()
                stopSelfSafe(); return
            }

            ar.startRecording()
            if (ar.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                ar.stop(); ar.release()
                Log.e(TAG, "AudioRecord MIC no está grabando")
                restoreSpeaker()
                stopSelfSafe(); return
            }

            micRecord = ar
            isRecording.set(true)
            Log.d(TAG, "Grabando MIC (altavoz activado) → $wavPath")

            mixThread = Thread { writeSingleTrackWav(ar, wavPath, bufSize) }
                .also { it.isDaemon = true; it.start() }

        } catch (e: Exception) {
            Log.e(TAG, "startMicOnlyRecording error: ${e.message}")
            restoreSpeaker()
            stopSelfSafe()
        }
    }

    // ─── Mezcla de dos pistas en WAV ──────────────────────────────────────────

    private fun mixAndWriteWav(wavPath: String, bufSize: Int) {
        val pcmPath = wavPath.replace(".wav", "_mix.pcm")
        try {
            val pb  = playbackRecord
            val mic = micRecord
            val buf1 = ShortArray(bufSize / 2)
            val buf2 = ShortArray(bufSize / 2)

            FileOutputStream(pcmPath).use { fos ->
                val outBuf = ByteArray(bufSize)
                while (isRecording.get()) {
                    val n1 = if (pb != null && pb.recordingState == AudioRecord.RECORDSTATE_RECORDING)
                        pb.read(buf1, 0, buf1.size) else 0
                    val n2 = if (mic != null && mic.recordingState == AudioRecord.RECORDSTATE_RECORDING)
                        mic.read(buf2, 0, buf2.size) else 0

                    val n = maxOf(n1, n2).coerceAtLeast(0)
                    if (n == 0) { Thread.sleep(10); continue }

                    // Mezcla: suma con clamp para evitar distorsión
                    val bb = ByteBuffer.wrap(outBuf).order(ByteOrder.LITTLE_ENDIAN)
                    for (i in 0 until n) {
                        val s1 = if (i < n1) buf1[i].toInt() else 0
                        val s2 = if (i < n2) buf2[i].toInt() else 0
                        val mixed = (s1 + s2).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                        bb.putShort(mixed.toShort())
                    }
                    fos.write(outBuf, 0, n * 2)
                }
            }

            convertPcmToWav(pcmPath, wavPath)
            File(pcmPath).delete()
            Log.d(TAG, "WAV mezclado listo: $wavPath (${File(wavPath).length()} bytes)")
            savePathToPrefsIfValid(wavPath)

        } catch (e: Exception) {
            Log.e(TAG, "mixAndWriteWav error: ${e.message}")
        }
    }

    private fun writeSingleTrackWav(ar: AudioRecord, wavPath: String, bufSize: Int) {
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
            Log.d(TAG, "WAV MIC listo: $wavPath (${File(wavPath).length()} bytes)")
            savePathToPrefsIfValid(wavPath)
        } catch (e: Exception) {
            Log.e(TAG, "writeSingleTrackWav error: ${e.message}")
        }
    }

    // ─── Parada ───────────────────────────────────────────────────────────────

    @Synchronized
    fun stopAndSave() {
        if (!isRecording.getAndSet(false)) {
            stopSelfSafe(); return
        }

        try { playbackRecord?.stop() } catch (_: Exception) {}
        try { playbackRecord?.release() } catch (_: Exception) {}
        playbackRecord = null

        try { micRecord?.stop() } catch (_: Exception) {}
        try { micRecord?.release() } catch (_: Exception) {}
        micRecord = null

        try { mediaProjection?.stop() } catch (_: Exception) {}
        mediaProjection = null

        mixThread?.join(12_000)
        mixThread = null

        restoreSpeaker()

        Log.d(TAG, "Grabación detenida. path=$currentPath")
        currentPath = null
        stopSelfSafe()
    }

    private fun stopSelfSafe() {
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        try { stopSelf() } catch (_: Exception) {}
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun resolveRecordingDir(): File {
        val base = filesDir.parent ?: filesDir.absolutePath
        val dir  = File(base, "app_flutter/call_recordings")
        if (!dir.exists()) dir.mkdirs()
        return if (dir.exists()) dir else File(filesDir, "call_recordings").also { it.mkdirs() }
    }

    private fun savePathToPrefsIfValid(path: String) {
        val f = File(path)
        if (f.exists() && f.length() > 1024) {
            try {
                getSharedPreferences(CallRecorderService.SHARED_PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(CallRecorderService.KEY_LAST_RECORDING_PATH, path)
                    .commit()
                Log.d(TAG, "Ruta guardada en prefs: $path (${f.length()} bytes)")
            } catch (e: Exception) {
                Log.e(TAG, "savePathToPrefsIfValid error: ${e.message}")
            }
        } else {
            Log.w(TAG, "Archivo inválido o vacío: ${f.length()} bytes — no se guarda")
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
            val ch = NotificationChannel(
                CHANNEL_ID, "Grabación de llamada (audio completo)",
                NotificationManager.IMPORTANCE_LOW
            ).apply { setSound(null, null) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification() {
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Minuto a Minuto")
            .setContentText("Grabando llamada (audio completo)...")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID, notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }
}
