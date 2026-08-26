package com.foxyco.foxyco

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.speech.tts.TextToSpeech
import androidx.activity.result.ActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
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
import java.io.File
import java.io.ByteArrayOutputStream
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val UPDATE_TAG = "FoxyCoPlayUpdate"
        const val MAX_HISTORY_BYTES = 5 * 1024 * 1024
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
            // AppUpdateInfo is single-use. The resume check fetches a fresh one
            // before offering a retry.
            appUpdateInfo = null
            updateEvents?.success(mapOf("state" to "unavailable"))
        }
    }
    private var textToSpeech: TextToSpeech? = null
    private var speechReady = false
    private var pendingSpeech: String? = null
    private var pendingImageResult: MethodChannel.Result? = null
    private var pendingImageLimit = 3
    private var pendingHistoryResult: MethodChannel.Result? = null
    private var pendingHistorySaveResult: MethodChannel.Result? = null
    private var pendingHistorySaveBytes: ByteArray? = null
    private val historyPicker = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> finishPickingHistory(uri) }
    private val historySavePicker = registerForActivityResult(
        ActivityResultContracts.CreateDocument("text/csv")
    ) { uri -> finishSavingHistory(uri) }
    private val singleImagePicker = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri -> finishPickingImages(uri?.let(::listOf).orEmpty()) }
    private val twoImagePicker = registerForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(2)
    ) { finishPickingImages(it) }
    private val threeImagePicker = registerForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(3)
    ) { finishPickingImages(it) }

    private fun finishPickingImages(uris: List<Uri>) {
        val result = pendingImageResult ?: return
        pendingImageResult = null
        try {
            result.success(
                uris.distinct().take(pendingImageLimit).mapNotNull(::copyFeedbackImage)
            )
        } catch (error: Exception) {
            result.error("photo_picker_failed", "Couldn't read selected images.", null)
        }
    }

    private fun finishPickingHistory(uri: Uri?) {
        val result = pendingHistoryResult ?: return
        pendingHistoryResult = null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > MAX_HISTORY_BYTES) throw IllegalArgumentException("too_large")
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            } ?: throw IllegalArgumentException("unreadable")
            result.success(bytes)
        } catch (error: Exception) {
            if (error.message == "too_large") {
                result.error("history_file_too_large", "The backup file is too large.", null)
            } else {
                result.error("history_file_unreadable", "Couldn't read the backup file.", null)
            }
        }
    }

    private fun finishSavingHistory(uri: Uri?) {
        val result = pendingHistorySaveResult ?: return
        pendingHistorySaveResult = null
        val bytes = pendingHistorySaveBytes
        pendingHistorySaveBytes = null
        if (uri == null || bytes == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalArgumentException("unwritable")
            result.success(true)
        } catch (error: Exception) {
            result.error("history_file_save_failed", "Couldn't save the backup file.", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cleanOldFeedbackImages()
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/feedback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "context" -> result.success(feedbackContext())
                    "pickImages" -> pickFeedbackImages(
                        (call.argument<Int>("limit") ?: 3).coerceIn(1, 3),
                        result,
                    )
                    "send" -> result.success(
                        sendFeedback(
                            call.argument<String>("recipient").orEmpty(),
                            call.argument<String>("subject").orEmpty(),
                            call.argument<String>("body").orEmpty(),
                            call.argument<List<String>>("imagePaths").orEmpty(),
                        )
                    )
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/history_backup")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveCsv") {
                    if (pendingHistorySaveResult != null || pendingHistoryResult != null) {
                        result.error("history_picker_busy", "A file picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    pendingHistorySaveBytes = call.argument<ByteArray>("bytes")
                    pendingHistorySaveResult = result
                    try {
                        historySavePicker.launch(call.argument<String>("filename") ?: "FoxyCo_History.csv")
                    } catch (error: Exception) {
                        pendingHistorySaveBytes = null
                        pendingHistorySaveResult = null
                        result.error("history_picker_failed", "Couldn't open the file picker.", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "pickCsv") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingHistoryResult != null) {
                    result.error("history_picker_busy", "A file picker is already open.", null)
                    return@setMethodCallHandler
                }
                pendingHistoryResult = result
                try {
                    historyPicker.launch(
                        arrayOf(
                            "text/csv",
                            "text/comma-separated-values",
                            "application/csv",
                            "text/plain",
                            "application/vnd.ms-excel",
                        )
                    )
                } catch (error: Exception) {
                    pendingHistoryResult = null
                    result.error("history_picker_failed", "Couldn't open the file picker.", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/device_health")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "batteryUnrestricted" -> {
                        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("battery_settings_unavailable", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foxyco/ocr")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(AccessibilityListener.isOcrAvailable())
                    "capture" -> {
                        val accepted = AccessibilityListener.captureOcr { packageName, lines ->
                            runOnUiThread {
                                result.success(mapOf("packageName" to packageName, "lines" to lines))
                            }
                        }
                        if (!accepted) {
                            result.success(mapOf("packageName" to "", "lines" to emptyList<String>()))
                        }
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
            val started = appUpdateManager.startUpdateFlowForResult(
                info,
                updateLauncher,
                AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(),
            )
            appUpdateInfo = null
            result.success(started)
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
        state.installStatus() == InstallStatus.PENDING ||
            state.installStatus() == InstallStatus.INSTALLING ->
            mapOf("state" to "starting")
        else -> mapOf("state" to "unavailable")
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

    private fun feedbackContext(): Map<String, String> {
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageInfo(packageName, 0)
        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toString()
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toString()
        }
        return mapOf(
            "version" to (info.versionName ?: "Unknown"),
            "build" to build,
            "android" to Build.VERSION.RELEASE,
            "device" to listOf(Build.MANUFACTURER, Build.MODEL)
                .filter { it.isNotBlank() }
                .joinToString(" "),
        )
    }

    private fun pickFeedbackImages(limit: Int, result: MethodChannel.Result) {
        if (pendingImageResult != null) {
            result.error("photo_picker_busy", "The photo picker is already open.", null)
            return
        }
        pendingImageResult = result
        pendingImageLimit = limit
        val request = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        try {
            when (limit) {
                1 -> singleImagePicker.launch(request)
                2 -> twoImagePicker.launch(request)
                else -> threeImagePicker.launch(request)
            }
        } catch (error: Exception) {
            pendingImageResult = null
            result.error("photo_picker_failed", "Couldn't open the photo picker.", null)
        }
    }

    private fun copyFeedbackImage(uri: Uri): String? {
        val mime = contentResolver.getType(uri).orEmpty()
        if (mime.isNotEmpty() && !mime.startsWith("image/")) return null
        val suffix = when (mime) {
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            else -> ".jpg"
        }
        val directory = feedbackImageDirectory().apply { mkdirs() }
        val output = File(directory, "${UUID.randomUUID()}$suffix")
        contentResolver.openInputStream(uri)?.use { input ->
            output.outputStream().use(input::copyTo)
        } ?: return null
        return output.path
    }

    private fun sendFeedback(
        recipient: String,
        subject: String,
        body: String,
        imagePaths: List<String>,
    ): Boolean {
        if (recipient.isBlank() || subject.isBlank() || body.isBlank()) return false
        val directory = feedbackImageDirectory().canonicalFile
        val uris = imagePaths.take(3).mapNotNull { path ->
            val file = File(path).canonicalFile
            if (!file.isFile || file.parentFile != directory) return@mapNotNull null
            FileProvider.getUriForFile(this, "$packageName.feedback_files", file)
        }
        val intent = if (uris.isEmpty()) {
            Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:${Uri.encode(recipient)}")).apply {
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
            }
        } else {
            Intent(if (uris.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE).apply {
                type = "*/*"
                putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
                if (uris.size == 1) {
                    putExtra(Intent.EXTRA_STREAM, uris.first())
                } else {
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
                }
                clipData = ClipData.newUri(contentResolver, "FoxyCo feedback", uris.first()).also {
                    uris.drop(1).forEach { uri -> it.addItem(ClipData.Item(uri)) }
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        if (intent.resolveActivity(packageManager) == null) return false
        return try {
            startActivity(Intent.createChooser(intent, "Send feedback with"))
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun feedbackImageDirectory() = File(cacheDir, "feedback")

    private fun cleanOldFeedbackImages() {
        val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000
        feedbackImageDirectory()
            .listFiles()
            ?.filter { it.lastModified() < cutoff }
            ?.forEach(File::delete)
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
