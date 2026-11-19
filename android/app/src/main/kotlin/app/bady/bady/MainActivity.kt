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

/** Notification sound picker and preview for the settings screen. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
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
    }
}
