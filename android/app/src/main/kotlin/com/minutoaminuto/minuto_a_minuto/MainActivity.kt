package com.minutoaminuto.minuto_a_minuto

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val callStateChannelName = "minutoaminuto/call_state"
    private var eventSink: EventChannel.EventSink? = null
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null

    private var lastState: Int = TelephonyManager.CALL_STATE_IDLE
    private var isIncoming: Boolean = false
    private var lastIncomingNumber: String = ""

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
    }

    @Suppress("DEPRECATION")
    private fun startPhoneStateListener() {
        if (phoneStateListener != null) return
        val hasPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) return

        telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, incomingNumber: String?) {
                super.onCallStateChanged(state, incomingNumber)
                handleCallStateChanged(state, incomingNumber ?: "")
            }
        }
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    @Suppress("DEPRECATION")
    private fun stopPhoneStateListener() {
        val listener = phoneStateListener ?: return
        telephonyManager?.listen(listener, PhoneStateListener.LISTEN_NONE)
        phoneStateListener = null
    }

    private fun handleCallStateChanged(state: Int, incomingNumber: String) {
        if (lastState == state) return
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                lastIncomingNumber = incomingNumber
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (lastState == TelephonyManager.CALL_STATE_RINGING) {
                    isIncoming = true
                    sendEvent(
                        state = "start",
                        direction = "incoming",
                        number = incomingNumber.ifBlank { lastIncomingNumber },
                    )
                } else {
                    isIncoming = false
                    sendEvent(
                        state = "start",
                        direction = "outgoing",
                        number = incomingNumber,
                    )
                }
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                    lastState == TelephonyManager.CALL_STATE_RINGING
                ) {
                    sendEvent(
                        state = "end",
                        direction = if (isIncoming) "incoming" else "outgoing",
                        number = incomingNumber.ifBlank { lastIncomingNumber },
                    )
                }
                isIncoming = false
                lastIncomingNumber = ""
            }
        }
        lastState = state
    }

    private fun sendEvent(state: String, direction: String, number: String) {
        eventSink?.success(
            mapOf(
                "state" to state,
                "direction" to direction,
                "number" to number,
            )
        )
    }

    override fun onDestroy() {
        stopPhoneStateListener()
        super.onDestroy()
    }
}
