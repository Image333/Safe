package com.safe.safe

import android.content.Intent
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val voiceTriggerChannel = "safe/voice_trigger"
	private val volumeButtonChannel = "safe/volume_button"
	private val minRecordingDurationSec = 5
	private val maxRecordingDurationSec = 600

	private var volumeEventSink: EventChannel.EventSink? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voiceTriggerChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"startListening" -> {
						val args = call.arguments as? Map<*, *>
						val keyword = (args?.get("keyword") as? String)?.trim().orEmpty()
						val rawDuration = (args?.get("recordingDurationSec") as? Int) ?: 15
						val duration = rawDuration.coerceIn(minRecordingDurationSec, maxRecordingDurationSec)

						if (keyword.isBlank()) {
							result.error("invalid_arguments", "keyword manquant", null)
							return@setMethodCallHandler
						}

						val intent = Intent(this, VoiceTriggerForegroundService::class.java).apply {
							action = VoiceTriggerForegroundService.ACTION_START
							putExtra(VoiceTriggerForegroundService.EXTRA_KEYWORD, keyword)
							putExtra(VoiceTriggerForegroundService.EXTRA_RECORDING_DURATION_SEC, duration)
						}

						startForegroundService(intent)
						result.success(null)
					}

					"stopListening" -> {
						val intent = Intent(this, VoiceTriggerForegroundService::class.java).apply {
							action = VoiceTriggerForegroundService.ACTION_STOP
						}
						startService(intent)
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, volumeButtonChannel)
			.setStreamHandler(object : EventChannel.StreamHandler {
				override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
					volumeEventSink = events
				}

				override fun onCancel(arguments: Any?) {
					volumeEventSink = null
				}
			})
	}

	override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
		val sink = volumeEventSink
		if (sink != null) {
			when (keyCode) {
				KeyEvent.KEYCODE_VOLUME_UP -> {
					sink.success("up")
					return true
				}
				KeyEvent.KEYCODE_VOLUME_DOWN -> {
					sink.success("down")
					return true
				}
			}
		}
		return super.onKeyDown(keyCode, event)
	}
}
