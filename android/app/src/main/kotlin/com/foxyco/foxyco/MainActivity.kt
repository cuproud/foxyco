package com.foxyco.foxyco

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.PersistableBundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.speech.tts.TextToSpeech
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import slayer.accessibility.service.flutter_accessibility_service.AccessibilityListener

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val UPDATE_TAG = "FoxyCoPlayUpdate"
    }
    private val appUpdateManager: AppUpdateManager by lazy {
        AppUpdateManagerFactory.create(this)
    }
    private var appUpdateInfo: AppUpdateInfo? = null
    private var updateEvents: EventChannel.EventSink? = null
    private val updateListener = InstallStateUpdatedListener { state ->
        Log.d(UPDATE_TAG, "install state=${state.installStatus()}")
        updateEvents?.success(updateState(state))
    }
    private val updateLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { result: ActivityResult ->
        if (result.resultCode != RESULT_OK) {
            updateEvents?.success(mapOf("state" to "available"))
        }
    }
    private var textToSpeech: TextToSpeech? = null
    private var speechReady = false
    private var pendingSpeech: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/play_updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> checkForUpdate(result)
                    "startFlexible" -> startFlexibleUpdate(result)
                    "complete" -> {
                        appUpdateManager.completeUpdate()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/play_updates/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    updateEvents = events
                    appUpdateManager.registerListener(updateListener)
                }

                override fun onCancel(arguments: Any?) {
                    appUpdateManager.unregisterListener(updateListener)
                    updateEvents = null
                }
            })
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

    private fun checkForUpdate(result: MethodChannel.Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                appUpdateInfo = info
                Log.d(
                    UPDATE_TAG,
                    "availability=${info.updateAvailability()} flexible=" +
                        info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) +
                        " install=${info.installStatus()}",
                )
                result.success(updateState(info))
            }
            .addOnFailureListener {
                Log.d(UPDATE_TAG, "check failed", it)
                result.success(mapOf("state" to "unavailable"))
            }
    }

    private fun startFlexibleUpdate(result: MethodChannel.Result) {
        val info = appUpdateInfo
        if (info == null || !info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
            Log.d(UPDATE_TAG, "flexible update not allowed")
            result.success(false)
            return
        }
        try {
            appUpdateManager.startUpdateFlowForResult(
                info,
                updateLauncher,
                AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(),
            )
            result.success(true)
        } catch (error: Exception) {
            Log.d(UPDATE_TAG, "start failed", error)
            result.success(false)
        }
    }

    private fun updateState(info: AppUpdateInfo): Map<String, Any> {
        val install = info.installStatus()
        return when {
            install == InstallStatus.DOWNLOADED -> mapOf("state" to "downloaded")
            install == InstallStatus.DOWNLOADING -> mapOf("state" to "downloading")
            install == InstallStatus.PENDING || install == InstallStatus.INSTALLING ->
                mapOf("state" to "starting")
            info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) ->
                mapOf("state" to "available")
            info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ->
                mapOf("state" to "notAllowed")
            else -> mapOf("state" to "unavailable")
        }
    }

    private fun updateState(state: InstallState): Map<String, Any> = when {
        state.installStatus() == InstallStatus.DOWNLOADED ->
            mapOf("state" to "downloaded")
        state.installStatus() == InstallStatus.DOWNLOADING -> mapOf(
            "state" to "downloading",
            "downloaded" to state.bytesDownloaded(),
            "total" to state.totalBytesToDownload(),
        )
        else -> mapOf("state" to "starting")
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
