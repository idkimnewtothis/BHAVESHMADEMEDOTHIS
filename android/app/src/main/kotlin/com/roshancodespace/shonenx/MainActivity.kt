package io.github.idkimnewtothis.shonenxplus

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private var folderResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "shonenxplus/downloads").setMethodCallHandler { call, result ->
            when (call.method) {
                "wifiAvailable" -> {
                    val manager = getSystemService(android.net.ConnectivityManager::class.java)
                    val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                    result.success(caps != null && (caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) || caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET)))
                }
                "start" -> { startForegroundService(Intent(this, DownloadService::class.java)); result.success(null) }
                "progress" -> {
                    val args = call.arguments as Map<*, *>
                    startService(Intent(this, DownloadService::class.java).putExtra("title", args["title"] as String).putExtra("progress", (args["progress"] as Number).toInt()))
                    result.success(null)
                }
                "stop" -> { stopService(Intent(this, DownloadService::class.java)); result.success(null) }
                "chooseFolder" -> {
                    if (folderResult != null) { result.error("BUSY", "Folder picker is already open", null) }
                    else {
                        folderResult = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION), 4102)
                    }
                }
                "sync" -> {
                    val requests = call.arguments as? List<*> ?: emptyList<Any>()
                    worker.execute {
                        try {
                            val uri = getPreferences(MODE_PRIVATE).getString("oneDmFolder", null)
                            val root = uri?.let { DocumentFile.fromTreeUri(this, Uri.parse(it)) }
                            val files = mutableMapOf<String, MutableList<DocumentFile>>()
                            fun scan(dir: DocumentFile, depth: Int) {
                                if (depth > 4) return
                                for (file in dir.listFiles()) {
                                    if (file.isDirectory) scan(file, depth + 1)
                                    else file.name?.let { files.getOrPut(it) { mutableListOf() }.add(file) }
                                }
                            }
                            if (root != null) scan(root, 0)
                            val copied = mutableListOf<String>()
                            for (raw in requests) {
                                val request = raw as Map<*, *>
                                val name = request["name"] as String
                                val dest = File(request["path"] as String).canonicalFile
                                val allowed = listOfNotNull(filesDir, getExternalFilesDir(null)).any { dest.path.startsWith(it.canonicalPath + File.separator) }
                                require(allowed) { "Import destination must be app-specific storage" }
                                val candidates = files[name] ?: continue
                                require(candidates.size == 1) { "Duplicate 1DM file: $name. Choose a more specific folder." }
                                val file = candidates.single()
                                val size = file.length()
                                val modified = file.lastModified()
                                // 1DM partial files have a different name. Also avoid copying a
                                // final-named file that is still being written.
                                if (size <= 0 || modified <= 0 || System.currentTimeMillis() - modified < 5000) continue
                                dest.parentFile?.mkdirs()
                                val temp = File(dest.path + ".importing")
                                contentResolver.openInputStream(file.uri)?.use { input -> temp.outputStream().use { input.copyTo(it) } }
                                    ?: error("Cannot read $name")
                                if (temp.length() != size || file.length() != size || file.lastModified() != modified) { temp.delete(); continue }
                                if (!temp.renameTo(dest)) { temp.delete(); error("Cannot save $name") }
                                copied += dest.path
                            }
                            runOnUiThread { result.success(copied) }
                        } catch (e: Exception) { runOnUiThread { result.error("IMPORT", e.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Android activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4102) return
        val result = folderResult; folderResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result?.success(false); return }
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            getPreferences(MODE_PRIVATE).edit().putString("oneDmFolder", uri.toString()).apply()
            result?.success(true)
        } catch(e: Exception) { result?.error("FOLDER", e.message, null) }
    }
    override fun onDestroy() {
        folderResult?.error("CLOSED", "Folder selection was interrupted", null)
        folderResult = null
        worker.shutdown()
        super.onDestroy()
    }
}
