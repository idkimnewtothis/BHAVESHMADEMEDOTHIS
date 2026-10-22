package com.ryan.runtimebridge

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import dalvik.system.PathClassLoader
import eu.kanade.tachiyomi.animesource.*
import eu.kanade.tachiyomi.animesource.model.*
import eu.kanade.tachiyomi.animesource.online.AnimeHttpSource
import eu.kanade.tachiyomi.network.NetworkHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.serialization.json.Json
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton
import java.io.File
import java.security.MessageDigest

/** Only installed, explicitly trusted Aniyomi anime APKs enter this runtime. */
class AnymexExtensionRuntimeBridgePlugin : FlutterPlugin {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var hostChannel: MethodChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val sources = java.util.concurrent.ConcurrentHashMap<String, Loaded>()
    private val failures = mutableListOf<Map<String, String>>()
    private data class Loaded(val source: AnimeSource, val pkg: String, val lib: Int, val version: String, val nsfw: Boolean)
    private val flags = PackageManager.GET_META_DATA or PackageManager.GET_CONFIGURATIONS or (if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES)
    private val supported = setOf(14, 16, 17)
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        Injekt.addSingleton(context)
        Injekt.addSingleton(context.applicationContext as android.app.Application)
        val network = NetworkHelper(context)
        Injekt.addSingleton(network)
        Injekt.addSingleton(network.client)
        Injekt.addSingleton(Json { ignoreUnknownKeys = true })
        hostChannel = MethodChannel(binding.binaryMessenger, "anymeXBridge")
        hostChannel.setMethodCallHandler { call, result ->
            when(call.method) {
                "isLoaded" -> result.success(true)
                "loadAnymeXRuntimeHost" -> result.error("UNSUPPORTED", "The anime runtime is bundled; external hosts are disabled", null)
                "cancelRequest" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        channel = MethodChannel(binding.binaryMessenger, "aniyomiExtensionBridge")
        channel.setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    val value = execute(call)
                    withContext(Dispatchers.Main) { result.success(value) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.error("SOURCE_ERROR", "${(call.arguments as? Map<*, *>)?.get("sourceId") ?: "Extension store"}: ${e.message}", null) }
                } catch (e: LinkageError) {
                    withContext(Dispatchers.Main) { result.error("EXTENSION_ABI", "${(call.arguments as? Map<*, *>)?.get("sourceId")}: incompatible extension member: ${e.message}", null) }
                }
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope.cancel(); channel.setMethodCallHandler(null); hostChannel.setMethodCallHandler(null)
    }
    private fun certificates(info: PackageInfo): Set<String> {
        val signers = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        require(!signers.isNullOrEmpty()) { "APK has no signing certificate" }
        return signers.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
        }.toSet()
    }
    private fun validate(info: PackageInfo): Int {
        require(info.packageName.startsWith("eu.kanade.tachiyomi.animeextension.")) { "Only Aniyomi anime APKs can be installed or loaded" }
        val features = info.reqFeatures.orEmpty().map { it.name }
        require("tachiyomi.animeextension" in features && "tachiyomi.extension" !in features) { "Not an anime-only extension APK" }
        val meta = info.applicationInfo?.metaData ?: error("Extension metadata is missing")
        val lib = meta.getInt("aniyomix.extensionLib", 0).takeIf { it != 0 }
            ?: info.versionName?.substringBeforeLast('.')?.toIntOrNull()
        require(lib in supported) { "Found lib $lib; supported libs: 14, 16, 17" }
        return lib!!
    }
    private val trust get() = context.getSharedPreferences("anime-extension-trust", Context.MODE_PRIVATE)
    @Synchronized private fun load(): List<Map<String, Any?>> {
        sources.clear(); failures.clear()
        val packages = context.packageManager.getInstalledPackages(flags)
        for (info in packages.filter { it.packageName.startsWith("eu.kanade.tachiyomi.animeextension.") }) {
            try {
                val lib = validate(info)
                val expected = trust.getString(info.packageName, null) ?: error("Not trusted. Install or trust this extension from its repository first.")
                require(certificates(info) == setOf(expected)) { "Signing certificate mismatch" }
                val app = info.applicationInfo ?: error("Application metadata missing")
                // Parent-first resolution prevents extensions replacing host API classes.
                val loader = PathClassLoader(app.sourceDir, context.classLoader)
                val classes = app.metaData.getString("tachiyomi.animeextension.class") ?: error("Source class metadata missing")
                for (name in classes.split(';')) {
                    val fullName = name.trim().let { if(it.startsWith('.')) info.packageName + it else it }
                    val obj = loader.loadClass(fullName).getDeclaredConstructor().newInstance()
                    val list = when(obj) { is AnimeSource -> listOf(obj); is AnimeSourceFactory -> obj.createSources(); else -> error("Unsupported source class $fullName") }
                    for (source in list) sources[source.id.toString()] = Loaded(source, info.packageName, lib, info.versionName ?: "", app.metaData.getInt("tachiyomi.animeextension.nsfw", 0) == 1)
                }
            } catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                failures += mapOf("package" to info.packageName, "reason" to (e.message ?: e.javaClass.simpleName))
            }
        }
        return sources.values.map { loaded ->
            val s = loaded.source
            mapOf("id" to s.id.toString(), "name" to s.name, "pkgName" to loaded.pkg, "version" to loaded.version,
                "libVersion" to loaded.lib, "lang" to s.lang, "baseUrl" to (s as? AnimeHttpSource)?.baseUrl,
                "itemType" to 1, "isNsfw" to loaded.nsfw, "isShared" to true, "supportsLatest" to s.supportsLatest, "supportsPopular" to true)
        }
    }
    private suspend fun execute(call: MethodCall): Any? {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any,Any>()
        require(args["isAnime"] != false && !call.method.contains("Manga")) { "No manga sources in this build" }
        when(call.method) {
            "getInstalledAnimeExtensions" -> return load()
            "getLoadFailures" -> return synchronized(this) { failures.toList() }
            "inspectApk", "installVerifiedApk" -> {
                val file = File(args["path"] as String)
                val info = context.packageManager.getPackageArchiveInfo(file.path, flags) ?: error("Invalid APK")
                val lib = validate(info)
                val certs = certificates(info)
                require(certs.size == 1) { "Multiple APK signers are unsupported" }
                if(call.method == "inspectApk") return mapOf("package" to info.packageName, "fingerprint" to certs.single(), "lib" to lib, "version" to info.versionName)
                require(args["package"] == info.packageName) { "APK package differs from repository entry" }
                require(certs == setOf((args["fingerprint"] as String).lowercase())) { "Signing certificate does not match repository" }
                trust.edit().putString(info.packageName, certs.single()).commit()
                val uri = FileProvider.getUriForFile(context, context.packageName + ".anime-apks", file)
                withContext(Dispatchers.Main) {
                    context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION))
                }
                return true
            }
            "uninstallAnimeExtension" -> {
                val pkg = args["package"] as String
                require(pkg.startsWith("eu.kanade.tachiyomi.animeextension."))
                withContext(Dispatchers.Main) { context.startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                return true
            }
            "getPageList", "installSourceInternal" -> error("Only Android package installation of anime APKs is supported")
            "stopHttpServer" -> return null
        }
        val id = args["sourceId"] as? String ?: error("Source id is required")
        val loaded = sources[id] ?: run { load(); sources[id] } ?: error("Source $id is not installed or trusted")
        val source = loaded.source
        return withTimeout(20_000) {
            when(call.method) {
                "getPopular" -> page(source.getPopularAnime((args["page"] as Number).toInt()))
                "getLatestUpdates" -> page(source.getLatestUpdates((args["page"] as Number).toInt()))
                "search" -> page(source.getSearchAnime((args["page"] as Number).toInt(), args["query"] as String, source.getFilterList()))
                "getFilterList" -> emptyList<Any>()
                "getDetail" -> {
                    val input = args["media"] as Map<*, *>
                    val anime = SAnime.create().apply { url = input["url"] as? String ?: error("Title URL is missing"); title = input["title"] as? String ?: "" }
                    require(anime.url.isNotEmpty()) { "Title URL is empty" }
                    val update = if(loaded.lib == 17) source.getAnimeEpisodeUpdate(anime, emptyList(), true, true)
                    else {
                        val details = source.getAnimeDetails(anime)
                        if(details.url.isEmpty()) details.url = anime.url
                        SAnimeEpisodeUpdate(details, source.getEpisodeList(details))
                    }
                    media(update.anime).toMutableMap().apply { put("url", anime.url); put("episodes", update.episodes.map { ep ->
                        mapOf("url" to ep.url, "name" to ep.name, "episodeNumber" to ep.episode_number.toDouble(), "dateUpload" to ep.date_upload,
                            "thumbnail" to ep.preview_url, "description" to ep.summary, "scanlator" to ep.scanlator)
                    }) }
                }
                "getVideoList" -> {
                    val input = args["episode"] as Map<*, *>
                    val episode = SEpisode.create().apply { url = input["url"] as String; name = input["name"] as? String ?: "" }
                    val videos = if(loaded.lib == 14) source.getVideoList(episode) else source.getHosterList(episode).flatMap { source.getVideoList(it) }
                    videos.map { mapOf("url" to it.videoUrl, "quality" to it.quality, "originalUrl" to it.url) }
                }
                else -> error("Unsupported anime source operation ${call.method}")
            }
        }
    }
    private fun media(s: SAnime): Map<String, Any?> = mapOf("title" to s.title, "url" to s.url, "thumbnail_url" to s.thumbnail_url,
        "description" to s.description, "genre" to s.genre?.split(',')?.map { it.trim() }, "status" to when(s.status) { 1 -> "Ongoing"; 2 -> "Completed"; 3 -> "Licensed"; 4 -> "Publishing finished"; 5 -> "Cancelled"; 6 -> "On hiatus"; else -> "Unknown" }, "author" to s.author, "artist" to s.artist)
    private fun page(p: AnimesPage) = mapOf("list" to p.animes.map(::media), "hasNextPage" to p.hasNextPage)
}
