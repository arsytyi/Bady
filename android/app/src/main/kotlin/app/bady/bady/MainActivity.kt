package app.bady.bady

import android.app.Activity
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Notification sound picker and preview, and saving/opening backup files
 * through the system file picker.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var filePending: MethodChannel.Result? = null
    private var saveText: String? = null
    private var playing: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bady/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> pick(call.argument<String>("current"), result)
                    "play" -> {
                        play(call.argument<String>("sound"))
                        result.success(null)
                    }
                    "stop" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bady/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> saveFile(
                        call.argument<String>("name") ?: "bady-backup.json",
                        call.argument<String>("text") ?: "",
                        result,
                    )
                    "open" -> openFile(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startFileRequest(intent: Intent, code: Int, result: MethodChannel.Result) {
        filePending?.success(null)
        filePending = result
        try {
            startActivityForResult(intent, code)
        } catch (e: Exception) {
            filePending = null
            result.error("unavailable", e.message, null)
        }
    }

    private fun saveFile(name: String, text: String, result: MethodChannel.Result) {
        saveText = text
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startFileRequest(intent, SAVE_REQUEST, result)
    }

    private fun openFile(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        startFileRequest(intent, OPEN_REQUEST, result)
    }

    private fun finishFileRequest(requestCode: Int, resultCode: Int, data: Intent?) {
        val result = filePending ?: return
        filePending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            saveText = null
            result.success(null)
            return
        }
        try {
            if (requestCode == SAVE_REQUEST) {
                contentResolver.openOutputStream(uri, "wt")?.use {
                    it.write((saveText ?: "").toByteArray(Charsets.UTF_8))
                }
                saveText = null
                result.success(true)
            } else {
                val text = contentResolver.openInputStream(uri)?.use {
                    it.readBytes().toString(Charsets.UTF_8)
                }
                result.success(text)
            }
        } catch (e: Exception) {
            saveText = null
            result.error("io", e.message, null)
        }
    }

    private fun uriFor(sound: String?): Uri = when {
        sound == null -> Settings.System.DEFAULT_NOTIFICATION_URI
        sound.startsWith("raw:") ->
            Uri.parse("android.resource://$packageName/raw/${sound.substring(4)}")
        else -> Uri.parse(sound)
    }

    private fun play(sound: String?) {
        stop()
        try {
            playing = RingtoneManager.getRingtone(this, uriFor(sound))?.also { it.play() }
        } catch (_: Exception) {
        }
    }

    private fun stop() {
        playing?.stop()
        playing = null
    }

    private fun pick(current: String?, result: MethodChannel.Result) {
        stop()
        pending?.success(null)
        pending = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            if (current != null && !current.startsWith("raw:")) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
            }
        }
        try {
            startActivityForResult(intent, PICK_REQUEST)
        } catch (e: Exception) {
            pending = null
            result.error("unavailable", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAVE_REQUEST || requestCode == OPEN_REQUEST) {
            finishFileRequest(requestCode, resultCode, data)
            return
        }
        if (requestCode != PICK_REQUEST) return
        val result = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        @Suppress("DEPRECATION")
        val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null || uri == Settings.System.DEFAULT_NOTIFICATION_URI) {
            result.success(mapOf("uri" to "default"))
            return
        }
        val title = try {
            RingtoneManager.getRingtone(this, uri)?.getTitle(this)
        } catch (_: Exception) {
            null
        }
        result.success(mapOf("uri" to uri.toString(), "title" to title))
    }

    override fun onPause() {
        stop()
        super.onPause()
    }

    companion object {
        private const val PICK_REQUEST = 4021
        private const val SAVE_REQUEST = 4022
        private const val OPEN_REQUEST = 4023
    }
}
