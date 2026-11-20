package com.transportone.transport_one

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.transportone.transport_one/location_intent"
    private val TELEMETRY_CHANNEL = "com.transportone.transport_one/device_telemetry"
    private var initialIntentData: String? = null
    private var methodChannel: MethodChannel? = null
    private var telemetryChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
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
                } catch (e: Exception) {
                    result.error("BATTERY_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getBatteryInfo(): Map<String, Any> {
        val intentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus: Intent? = registerReceiver(null, intentFilter)

        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) {
            (level * 100 / scale.toFloat()).toInt()
        } else {
            -1
        }

        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL

        return mapOf(
            "batteryLevel" to batteryPct,
            "isCharging" to isCharging
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    private fun extractIntentData(intent: Intent?): String? {
        if (intent == null) return null

        // 1. Direct URI from intent.data (e.g. geo:... or https://maps.google.com/...)
        val dataStr = intent.dataString
        if (!dataStr.isNullOrBlank()) {
            return dataStr
        }

        // 2. Extra text shared from WhatsApp or other apps (e.g. Intent.EXTRA_TEXT)
        val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (!extraText.isNullOrBlank()) {
            return extraText
        }

        // 3. ClipData text
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

        return null
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        val payload = extractIntentData(intent) ?: return

        if (isInitial) {
            initialIntentData = payload
        } else {
            methodChannel?.invokeMethod("onLocationReceived", payload)
        }
    }
}
