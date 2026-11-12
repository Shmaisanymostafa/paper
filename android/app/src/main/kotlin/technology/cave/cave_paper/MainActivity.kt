package technology.cave.paper

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<String>()
    private val owned = mutableMapOf<String, File>()
    private var channel: MethodChannel? = null
    private var ready = false
    private var closed = false
    private var queued = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "technology.cave.paper/documents")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    ready = true
                    val paths = pending.toList()
                    pending.clear()
                    result.success(paths)
                }
                "release" -> {
                    val path = call.arguments as? String
                    // Never delete a caller-supplied path: only this Activity's copies.
                    owned.remove(path)?.delete()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent?) {
        if (closed || intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.scheme != "content" && uri.scheme != "file") return
        if (queued + owned.size >= 16) return
        queued++
        worker.execute {
            var copy: File? = null
            try {
                val target = File.createTempFile("paper-import-", ".pdf", cacheDir)
                copy = target
                contentResolver.openInputStream(uri).use { source ->
                    requireNotNull(source) { "File access unavailable" }
                    target.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var total = 0L
                        while (true) {
                            val count = source.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= 200L * 1024 * 1024) { "PDF too large" }
                            output.write(buffer, 0, count)
                        }
                    }
                }
                // The repository validates PDF content; MIME/extension alone are not trusted.
                val completed = target
                main.post {
                    queued--
                    if (closed) completed.delete()
                    else { owned[completed.path] = completed; emit(completed.path) }
                }
            } catch (_: Exception) {
                copy?.delete()
                main.post { queued--; if (!closed) emit("") }
            }
        }
    }

    private fun emit(path: String) {
        if (ready) channel?.invokeMethod("open", path) else pending.add(path)
    }

    override fun onDestroy() {
        closed = true
        channel?.setMethodCallHandler(null)
        worker.shutdown()
        owned.values.forEach { it.delete() }
        owned.clear()
        super.onDestroy()
    }
}
