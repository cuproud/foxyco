package com.foxyco.foxyco

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.PersistableBundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import slayer.accessibility.service.flutter_accessibility_service.AccessibilityListener

class MainActivity : FlutterActivity() {
    private var textToSpeech: TextToSpeech? = null
    private var speechReady = false
    private var pendingSpeech: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSensitiveText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text") ?: ""
                val clip = ClipData.newPlainText("FoxyCo diagnostics", text)
                clip.description.extras = PersistableBundle().apply {
                    putBoolean("android.content.extra.IS_SENSITIVE", true)
                }
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(clip)
                Handler(Looper.getMainLooper()).postDelayed({
                    val current = clipboard.primaryClip
                        ?.takeIf { it.itemCount > 0 }
                        ?.getItemAt(0)
                        ?.coerceToText(this)
                        ?.toString()
                    if (current == text) {
                        clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                    }
                }, 60_000)
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/ocr")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(AccessibilityListener.isOcrAvailable())
                    "capture" -> {
                        val accepted = AccessibilityListener.captureOcr { lines ->
                            runOnUiThread { result.success(lines) }
                        }
                        if (!accepted) result.success(emptyList<String>())
                    }
                    "stop" -> {
                        AccessibilityListener.cancelOcr()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        speak(call.argument<String>("text").orEmpty())
                        result.success(null)
                    }
                    "stop" -> {
                        pendingSpeech = null
                        textToSpeech?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun speak(text: String) {
        if (text.isBlank()) return
        pendingSpeech = text
        if (textToSpeech == null) {
            textToSpeech = TextToSpeech(applicationContext) { status ->
                speechReady = status == TextToSpeech.SUCCESS
                if (speechReady) flushPendingSpeech()
            }
        } else if (speechReady) {
            flushPendingSpeech()
        }
    }

    private fun flushPendingSpeech() {
        val text = pendingSpeech ?: return
        pendingSpeech = null
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "foxyco-good-offer")
    }

    override fun onDestroy() {
        pendingSpeech = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
