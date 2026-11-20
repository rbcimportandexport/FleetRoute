package com.transportone.transport_one

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.transportone.transport_one/location_intent"
    private val TELEMETRY_CHANNEL = "com.transportone.transport_one/device_telemetry"
    private val BATTERY_STREAM_CHANNEL = "com.transportone.transport_one/battery_stream"
    private var initialIntentData: String? = null
    private var methodChannel: MethodChannel? = null
    private var telemetryChannel: MethodChannel? = null
    private var batteryEventChannel: EventChannel? = null
    private var batteryReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            handleIntent(intent, isInitial = true)
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLocation") {
                result.success(initialIntentData)
                initialIntentData = null
            } else {
                result.notImplemented()
            }
        }

        telemetryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TELEMETRY_CHANNEL)
        telemetryChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getBatteryInfo") {
                try {
                    val batteryInfo = getBatteryInfo()
                    result.success(batteryInfo)
                } catch (_: Exception) {
                    result.success(mapOf("batteryLevel" to -1, "isCharging" to false))
                }
            } else {
                result.notImplemented()
            }
        }

        batteryEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_STREAM_CHANNEL)
        batteryEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                // Emit current status immediately on listen
                events.success(getBatteryInfo())

                batteryReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        try {
                            events.success(getBatteryInfo())
                        } catch (_: Exception) {}
                    }
                }

                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_BATTERY_CHANGED)
                    addAction(Intent.ACTION_POWER_CONNECTED)
                    addAction(Intent.ACTION_POWER_DISCONNECTED)
                }

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(batteryReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(batteryReceiver, filter)
                    }
                } catch (_: Exception) {}
            }

            override fun onCancel(arguments: Any?) {
                try {
                    if (batteryReceiver != null) {
                        unregisterReceiver(batteryReceiver)
                        batteryReceiver = null
                    }
                } catch (_: Exception) {}
            }
        })
    }

    override fun onDestroy() {
        try {
            if (batteryReceiver != null) {
                unregisterReceiver(batteryReceiver)
                batteryReceiver = null
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun getBatteryInfo(): Map<String, Any> {
        var batteryPct = -1
        var isCharging = false

        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (bm != null) {
                batteryPct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    isCharging = bm.isCharging
                }
            }
        } catch (_: Exception) {}

        if (batteryPct < 0 || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            try {
                val intentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                val batteryStatus: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(null, intentFilter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(null, intentFilter)
                }

                if (batteryStatus != null) {
                    val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                    if (level >= 0 && scale > 0) {
                        batteryPct = (level * 100 / scale.toFloat()).toInt()
                    }
                    val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                    isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL
                }
            } catch (_: Exception) {}
        }

        return mapOf(
            "batteryLevel" to batteryPct,
            "isCharging" to isCharging
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        try {
            setIntent(intent)
            handleIntent(intent, isInitial = false)
        } catch (_: Exception) {}
    }

    private fun extractIntentData(intent: Intent?): String? {
        if (intent == null) return null
        try {
            val dataStr = intent.dataString
            if (!dataStr.isNullOrBlank()) {
                return dataStr
            }

            val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!extraText.isNullOrBlank()) {
                return extraText
            }

            val clipData = intent.clipData
            if (clipData != null && clipData.itemCount > 0) {
                val itemText = clipData.getItemAt(0)?.text?.toString()
                if (!itemText.isNullOrBlank()) {
                    return itemText
                }
                val itemUri = clipData.getItemAt(0)?.uri?.toString()
                if (!itemUri.isNullOrBlank()) {
                    return itemUri
                }
            }
        } catch (_: Exception) {}

        return null
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        try {
            val payload = extractIntentData(intent) ?: return

            if (isInitial) {
                initialIntentData = payload
            } else {
                methodChannel?.invokeMethod("onLocationReceived", payload)
            }
        } catch (_: Exception) {}
    }
}
