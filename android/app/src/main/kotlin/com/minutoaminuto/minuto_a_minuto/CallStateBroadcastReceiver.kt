package com.minutoaminuto.minuto_a_minuto

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Receptor de estado de llamada.
 *
 * Máquina de estados simple:
 *   IDLE → RINGING  : llamada entrante, guardar número
 *   IDLE → OFFHOOK  : llamada saliente, iniciar grabación
 *   RINGING → OFFHOOK: llamada contestada, iniciar grabación
 *   OFFHOOK → IDLE  : llamada terminada, detener grabación
 *   RINGING → IDLE  : llamada rechazada, no hacer nada
 *
 * Clave de diseño: el estado previo se persiste en SharedPreferences para
 * sobrevivir reinicios del proceso. La transición OFFHOOK→IDLE es la única
 * que dispara el STOP del servicio de grabación.
 */
class CallStateBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallStateRcvr"
        private const val SHARED_PREFS       = "FlutterSharedPreferences"
        private const val KEY_SIGNAL         = "flutter.native_call_state_signal"
        private const val KEY_SIGNAL_TS      = "flutter.native_call_state_ts"
        private const val KEY_SIGNAL_NUMBER  = "flutter.native_call_state_number"
        private const val KEY_PREV_STATE     = "native_prev_call_state"
        private const val KEY_LAST_NUMBER    = "native_last_call_number"
        private const val LEGAL_CHANNEL      = "call_recording_legal"
        private const val LEGAL_NOTIF_ID     = 9002
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != TelephonyManager.ACTION_PHONE_STATE_CHANGED &&
            action != "android.intent.action.NEW_OUTGOING_CALL"
        ) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            ?: TelephonyManager.EXTRA_STATE_IDLE

        val rawNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            ?: intent.getStringExtra("android.intent.extra.PHONE_NUMBER")
            ?: ""

        val prefs    = context.getSharedPreferences(SHARED_PREFS, Context.MODE_PRIVATE)
        val prevState = prefs.getString(KEY_PREV_STATE, TelephonyManager.EXTRA_STATE_IDLE)
            ?: TelephonyManager.EXTRA_STATE_IDLE

        // Recordar número: si el nuevo no está vacío, actualizar; si no, usar el guardado
        val savedNumber = prefs.getString(KEY_LAST_NUMBER, "").orEmpty()
        val number = if (rawNumber.isNotBlank()) rawNumber else savedNumber

        Log.d(TAG, "state=$state prev=$prevState number=$number")

        val editor = prefs.edit()
        if (rawNumber.isNotBlank()) editor.putString(KEY_LAST_NUMBER, rawNumber)

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Llamada entrante: guardar número y mostrar aviso legal
                showLegalNotification(context, number, incoming = true)
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Solo actuar si venimos de IDLE o RINGING (no si ya estábamos OFFHOOK)
                if (prevState != TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    Log.d(TAG, "OFFHOOK → iniciando grabación")
                    writeSignal(editor, "start", number)
                    startRecorderService(context, number)
                    // Si es saliente (sin RINGING previo), mostrar aviso legal
                    if (prevState == TelephonyManager.EXTRA_STATE_IDLE) {
                        showLegalNotification(context, number, incoming = false)
                    }
                }
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Cancelar aviso legal siempre
                cancelLegalNotification(context)
                // Limpiar número guardado
                editor.putString(KEY_LAST_NUMBER, "")

                // Solo detener grabación si veníamos de OFFHOOK (llamada activa)
                if (prevState == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    Log.d(TAG, "IDLE desde OFFHOOK → deteniendo grabación")
                    writeSignal(editor, "end", number)
                    stopRecorderService(context)
                } else {
                    Log.d(TAG, "IDLE desde $prevState → sin acción de grabación")
                }
            }
        }

        editor.putString(KEY_PREV_STATE, state)
        editor.apply()
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun writeSignal(editor: android.content.SharedPreferences.Editor, signal: String, number: String) {
        // Flutter SharedPreferences lee Int (no Long) — usamos segundos para no desbordar Int
        val tsSeconds = (System.currentTimeMillis() / 1000).toInt()
        editor.putString(KEY_SIGNAL, signal)
        editor.putInt(KEY_SIGNAL_TS, tsSeconds)
        editor.putString(KEY_SIGNAL_NUMBER, number)
    }

    private fun startRecorderService(context: Context, number: String) {
        val intent = Intent(context, CallRecorderService::class.java).apply {
            action = CallRecorderService.ACTION_START
            putExtra(CallRecorderService.EXTRA_CALL_NUMBER, number)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startRecorderService error: ${e.message}")
        }
    }

    private fun stopRecorderService(context: Context) {
        val intent = Intent(context, CallRecorderService::class.java).apply {
            action = CallRecorderService.ACTION_STOP
        }
        try {
            context.startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "stopRecorderService error: ${e.message}")
        }
    }

    private fun showLegalNotification(context: Context, number: String, incoming: Boolean) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    LEGAL_CHANNEL, "Aviso de grabación", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Informa que la llamada será grabada"
                    setSound(null, null)
                }
                nm.createNotificationChannel(ch)
            }

            val openIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP }
            val pi = PendingIntent.getActivity(
                context, 0, openIntent ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val titulo = if (incoming) "Llamada entrante" else "Llamada saliente"
            val texto  = if (number.isNotBlank())
                "La llamada con $number será grabada por Minuto a Minuto."
            else
                "Esta llamada será grabada por Minuto a Minuto."

            val notif = NotificationCompat.Builder(context, LEGAL_CHANNEL)
                .setContentTitle(titulo)
                .setContentText(texto)
                .setStyle(NotificationCompat.BigTextStyle().bigText(
                    "$texto\nLa grabación se usa exclusivamente para registro de gestión comercial."
                ))
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(false)
                .setOngoing(true)
                .setContentIntent(pi)
                .build()

            nm.notify(LEGAL_NOTIF_ID, notif)
        } catch (e: Exception) {
            Log.e(TAG, "showLegalNotification error: ${e.message}")
        }
    }

    private fun cancelLegalNotification(context: Context) {
        try {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(LEGAL_NOTIF_ID)
        } catch (_: Exception) {}
    }
}
