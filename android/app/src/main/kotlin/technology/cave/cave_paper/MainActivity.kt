package technology.cave.paper

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<String>()
    // Staged file path -> the private directory that holds it.
    private val owned = mutableMapOf<String, File>()
    private var channel: MethodChannel? = null
    private var storageChannel: MethodChannel? = null
    private var storageResult: MethodChannel.Result? = null
    private var ready = false
    private var closed = false
    private var queued = 0
    private val stagingRoot by lazy { File(cacheDir, "paper-open-in") }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A previous process may have exited before Flutter released its copies.
        // This runs first on the serial worker, before any new copy is staged.
        val root = stagingRoot
        worker.execute { root.deleteRecursively() }
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
                    owned.remove(path)?.deleteRecursively()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "technology.cave.paper/storage")
        storageChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(if (storageGranted()) "granted" else "denied")
                "request" -> requestStorage(result)
                "roots" -> result.success(storageRoots())
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

    // ---- Device PDF listing: an explicit, user-granted permission only. ----

    private fun storageGranted(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }

    private fun requestStorage(result: MethodChannel.Result) {
        if (storageGranted()) {
            result.success("granted")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android shows its own All files access switch. Flutter checks the
            // status again when the app resumes.
            val specific = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName"))
            try {
                startActivity(specific)
            } catch (_: Exception) {
                try {
                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                } catch (_: Exception) {
                    result.success("unavailable")
                    return
                }
            }
            result.success("pending")
            return
        }
        if (storageResult != null) {
            result.success("pending")
            return
        }
        storageResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), STORAGE_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_REQUEST) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        storageResult?.success(if (granted) "granted" else "denied")
        storageResult = null
    }

    private fun storageRoots(): List<String> {
        if (!storageGranted()) return emptyList()
        val roots = linkedSetOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = getSystemService(StorageManager::class.java)
            for (volume in manager?.storageVolumes.orEmpty()) {
                val state = volume.state
                if (state == Environment.MEDIA_MOUNTED || state == Environment.MEDIA_MOUNTED_READ_ONLY) {
                    volume.directory?.let { roots.add(it.absolutePath) }
                }
            }
        } else {
            @Suppress("DEPRECATION")
            roots.add(Environment.getExternalStorageDirectory().absolutePath)
            for (dir in getExternalFilesDirs(null).filterNotNull()) {
                val index = dir.absolutePath.indexOf("/Android/data/")
                if (index > 0) roots.add(dir.absolutePath.substring(0, index))
            }
        }
        return roots.toList()
    }

    // ---- Open with / Share to Cave Paper ----

    private fun incoming(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        val uris = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(streamExtra(intent))
            Intent.ACTION_SEND_MULTIPLE -> streamListExtra(intent)
            else -> emptyList()
        }
        return uris.filter { it.scheme == "content" || it.scheme == "file" }
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }).orEmpty().filterNotNull()

    private fun receive(intent: Intent?) {
        if (closed) return
        for (uri in incoming(intent)) {
            if (queued + owned.size >= 16) return
            stage(uri)
        }
    }

    private fun stage(uri: Uri) {
        queued++
        worker.execute {
            var directory: File? = null
            try {
                val folder = File(stagingRoot, UUID.randomUUID().toString())
                directory = folder
                require(folder.mkdirs()) { "Staging unavailable" }
                // The original name becomes the library title; the folder keeps
                // concurrent copies with the same name apart.
                val target = File(folder, displayName(uri))
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
                main.post {
                    queued--
                    if (closed) folder.deleteRecursively()
                    else { owned[target.path] = folder; emit(target.path) }
                }
            } catch (_: Exception) {
                directory?.deleteRecursively()
                main.post { queued--; if (!closed) emit("") }
            }
        }
    }

    private fun displayName(uri: Uri): String {
        var name: String? = null
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor ->
                        val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (column >= 0 && cursor.moveToFirst()) name = cursor.getString(column)
                    }
            } catch (_: Exception) {
                // Some providers refuse metadata queries; fall back to the URI.
            }
        }
        if (name.isNullOrBlank()) name = uri.lastPathSegment
        return safeFileName(name)
    }

    private fun emit(path: String) {
        if (ready) channel?.invokeMethod("open", path) else pending.add(path)
    }

    override fun onDestroy() {
        closed = true
        channel?.setMethodCallHandler(null)
        storageChannel?.setMethodCallHandler(null)
        worker.shutdown()
        owned.values.forEach { it.deleteRecursively() }
        owned.clear()
        super.onDestroy()
    }

    companion object {
        private const val STORAGE_REQUEST = 4107

        /** A single path component ending in .pdf, never a path or hidden file. */
        fun safeFileName(raw: String?): String {
            var name = (raw ?: "").substringAfterLast('/').substringAfterLast('\\')
                .filter { it >= ' ' && it != '\u007f' && it !in ":*?\"<>|" }
                .trim().trimStart('.').trim()
            if (name.length > 120) name = name.take(120).trim()
            if (name.isEmpty()) name = "Document"
            if (!name.lowercase().endsWith(".pdf")) name += ".pdf"
            return name
        }
    }
}
