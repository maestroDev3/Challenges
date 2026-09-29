package de.maestrodev.challenges

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Datei-Kanal für Backups: Speichern und Öffnen über die Android-Dateiauswahl
 * (Storage Access Framework) – der Nutzer wählt den Ort, die App braucht
 * keine Speicher-Berechtigung.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "Dateiauswahl ist bereits offen", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "save" -> {
                        pending = result
                        pendingContent = call.argument<String>("content") ?: ""
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mimeType") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        }
                        startActivityForResult(intent, REQUEST_SAVE)
                    }
                    "open" -> {
                        pending = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, REQUEST_OPEN)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return
        val result = pending ?: return
        pending = null
        val content = pendingContent ?: ""
        pendingContent = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == REQUEST_SAVE) false else null)
            return
        }
        try {
            if (requestCode == REQUEST_SAVE) {
                val stream = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("Datei ist nicht beschreibbar")
                stream.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                result.success(true)
            } else {
                val stream = contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("Datei ist nicht lesbar")
                result.success(stream.use { it.readBytes().toString(Charsets.UTF_8) })
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    companion object {
        private const val CHANNEL = "ritual/backup_files"
        private const val REQUEST_SAVE = 4711
        private const val REQUEST_OPEN = 4712
    }
}
