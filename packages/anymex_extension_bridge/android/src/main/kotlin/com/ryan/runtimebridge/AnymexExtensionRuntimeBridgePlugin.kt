package com.ryan.runtimebridge

import android.app.Activity
import android.provider.Settings
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
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

/** Only installed, certificate-verified anime or manga APKs enter this runtime. */
class AnymexExtensionRuntimeBridgePlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {
    private var activityBinding: ActivityPluginBinding? = null
    private data class PendingInstall(val file: File, val pkg: String, val fingerprint: String, val versionCode: Long, val result: CompletableDeferred<Boolean>)
    private var pendingInstall: PendingInstall? = null
    private data class PendingRemoval(val pkg: String, val result: CompletableDeferred<Boolean>)
    private var pendingRemoval: PendingRemoval? = null
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        pendingInstall?.result?.completeExceptionally(IllegalStateException("Installation interrupted. Retry from the store."))
        pendingInstall = null
        pendingRemoval?.result?.completeExceptionally(IllegalStateException("Removal interrupted. Retry from the store."))
        pendingRemoval = null
    }
    private fun launchInstaller(install: PendingInstall) {
        val activity = activityBinding?.activity ?: error("Open the app to install an extension")
        if (Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()) {
            activity.startActivityForResult(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")), 6201)
            return
        }
        val uri = FileProvider.getUriForFile(context, context.packageName + ".anime-apks", install.file)
        activity.startActivityForResult(Intent(Intent.ACTION_INSTALL_PACKAGE).setData(uri)
            .putExtra(Intent.EXTRA_RETURN_RESULT, true)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION), 6202)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == 6203) {
            val removal = pendingRemoval ?: return true
            try {
                check(resultCode == Activity.RESULT_OK) { "Android removal was canceled or failed" }
                val exists = try { context.packageManager.getPackageInfo(removal.pkg, 0); true } catch (_: PackageManager.NameNotFoundException) { false }
                check(!exists) { "Android did not remove the extension" }
                check(trust.edit().remove(removal.pkg).commit()) { "Could not clear extension trust" }
                removal.result.complete(true)
            } catch (e: Exception) { removal.result.completeExceptionally(e) }
            pendingRemoval = null
            return true
        }
        if (requestCode != 6201 && requestCode != 6202) return false
        val install = pendingInstall ?: return true
        try {
            if (requestCode == 6201) {
                check(context.packageManager.canRequestPackageInstalls()) { "Allow installs from ShonenX+ in Android settings, then retry." }
                launchInstaller(install)
            } else {
                check(resultCode == Activity.RESULT_OK) { "Android installation was canceled or failed. Retry to install the extension." }
                val installed = context.packageManager.getPackageInfo(install.pkg, flags)
                check(certificates(installed) == setOf(install.fingerprint)) { "Installed certificate does not match the trusted repository" }
                val code = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
                check(code >= install.versionCode) { "Android did not install the requested extension version" }
                check(trust.edit().putString(install.pkg, install.fingerprint).commit()) { "Could not save extension trust" }
                install.result.complete(true)
                pendingInstall = null
            }
        } catch (e: Exception) {
            install.result.completeExceptionally(e)
            pendingInstall = null
        }
        return true
    }

    private lateinit var manga: MangaRuntime
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var hostChannel: MethodChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    @Volatile private var sources: Map<String, Loaded> = emptyMap()
    @Volatile private var failures: List<Map<String, String>> = emptyList()
    private data class Loaded(val source: AnimeSource, val pkg: String, val lib: Int, val version: String, val nsfw: Boolean)
    private val flags = PackageManager.GET_META_DATA or PackageManager.GET_CONFIGURATIONS or (if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES)
    private val supported = setOf(14, 16, 17)
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        manga = MangaRuntime(context)
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
                "runtimeInfo" -> result.success(mapOf("bundled" to true, "version" to "2.1.0", "mihon" to "v0.21.2", "animeLibs" to listOf(14,16,17), "mangaLibs" to listOf("1.4","1.6")))
                "loadAnymeXRuntimeHost" -> result.error("UNSUPPORTED", "Mihon and Aniyomi support is included in ShonenX+. Install an app update to update the runtime.", null)
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
        val isManga = info.packageName.startsWith("eu.kanade.tachiyomi.extension.")
        require(isManga || info.packageName.startsWith("eu.kanade.tachiyomi.animeextension.")) { "Not a supported extension package" }
        val features = info.reqFeatures.orEmpty().map { it.name }
        require((if(isManga) "tachiyomi.extension" else "tachiyomi.animeextension") in features) { "Extension feature is missing" }
        if (isManga) {
            val metadata = info.applicationInfo?.metaData ?: error("Extension metadata missing")
            val version = metadata.get("tachiyomix.extensionLib")?.toString()?.toDoubleOrNull()
                ?: info.versionName?.substringBeforeLast('.')?.toDoubleOrNull()
            require(version in setOf(1.4, 1.6)) { "Found manga lib $version; supported libs: 1.4, 1.6" }
            return (version!! * 10).toInt()
        }
        val meta = info.applicationInfo?.metaData ?: error("Extension metadata is missing")
        val lib = meta.getInt("aniyomix.extensionLib", 0).takeIf { it != 0 }
            ?: info.versionName?.substringBeforeLast('.')?.toIntOrNull()
        require(lib in supported) { "Found lib $lib; supported libs: 14, 16, 17" }
        return lib!!
    }
    private val trust get() = context.getSharedPreferences("anime-extension-trust", Context.MODE_PRIVATE)
    @Synchronized private fun load(): List<Map<String, Any?>> {
        val next = mutableMapOf<String, Loaded>()
        val nextFailures = mutableListOf<Map<String, String>>()
        val packages = context.packageManager.getInstalledPackages(flags)
        for (info in packages.filter { it.packageName.startsWith("eu.kanade.tachiyomi.animeextension.") }) {
            try {
                val packageSources = mutableMapOf<String, Loaded>()
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
                    for (source in list) {
                        val id = source.id.toString()
                        check(id !in next && id !in packageSources) { "Duplicate source id $id" }
                        packageSources[id] = Loaded(source, info.packageName, lib, info.versionName ?: "", app.metaData.getInt("tachiyomi.animeextension.nsfw", 0) == 1)
                    }
                }
                next.putAll(packageSources)
            } catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                nextFailures += mapOf("package" to info.packageName, "reason" to (e.message ?: e.javaClass.simpleName))
            }
        }
        sources = next.toMap()
        failures = nextFailures.toList()
        return sources.values.map { loaded ->
            val s = loaded.source
            mapOf("id" to s.id.toString(), "name" to s.name, "pkgName" to loaded.pkg, "version" to loaded.version,
                "libVersion" to loaded.lib, "lang" to s.lang, "baseUrl" to (s as? AnimeHttpSource)?.baseUrl,
                "itemType" to 1, "isNsfw" to loaded.nsfw, "isShared" to true, "supportsLatest" to s.supportsLatest, "supportsPopular" to true)
        }
    }
    private suspend fun execute(call: MethodCall): Any? {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any,Any>()

        when(call.method) {
            "getInstalledAnimeExtensions" -> return load()
            "getInstalledMangaExtensions" -> return manga.load(context.packageManager.getInstalledPackages(flags)) { info ->
                validate(info)
                val expected = trust.getString(info.packageName, null) ?: error("Not trusted. Install from a trusted repository first.")
                require(certificates(info) == setOf(expected)) { "Signing certificate mismatch" }
            }
            "getLoadFailures" -> return synchronized(this) { failures.toList() + manga.failures.toList() }
            "inspectApk", "installVerifiedApk" -> {
                val file = File(args["path"] as String)
                val info = context.packageManager.getPackageArchiveInfo(file.path, flags) ?: error("Invalid APK")
                val lib = validate(info)
                val certs = certificates(info)
                require(certs.size == 1) { "Multiple APK signers are unsupported" }
                if(call.method == "inspectApk") return mapOf("package" to info.packageName, "fingerprint" to certs.single(), "lib" to lib, "version" to info.versionName)
                require(args["package"] == info.packageName) { "APK package differs from repository entry" }
                require(certs == setOf((args["fingerprint"] as String).lowercase())) { "Signing certificate does not match repository" }
                val pending = withContext(Dispatchers.Main) {
                    check(pendingInstall == null && pendingRemoval == null) { "Finish the current Android package operation first" }
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    PendingInstall(file, info.packageName, certs.single(), code, CompletableDeferred()).also {
                        pendingInstall = it
                        try { launchInstaller(it) } catch (e: Exception) { pendingInstall = null; throw e }
                    }
                }
                return pending.result.await()
            }
            "uninstallAnimeExtension" -> {
                val pkg = args["package"] as String
                require(pkg.startsWith("eu.kanade.tachiyomi.animeextension.") || pkg.startsWith("eu.kanade.tachiyomi.extension."))
                val pending = withContext(Dispatchers.Main) {
                    check(pendingInstall == null && pendingRemoval == null) { "Finish the current Android package operation first" }
                    val activity = activityBinding?.activity ?: error("Open the app to remove an extension")
                    PendingRemoval(pkg, CompletableDeferred()).also {
                        pendingRemoval = it
                        try {
                            activity.startActivityForResult(Intent(Intent.ACTION_UNINSTALL_PACKAGE, Uri.parse("package:$pkg")).putExtra(Intent.EXTRA_RETURN_RESULT, true), 6203)
                        } catch (e: Exception) { pendingRemoval = null; throw e }
                    }
                }
                return pending.result.await()
            }
            "installSourceInternal" -> error("Use the Android package installer")
            "stopHttpServer" -> return null
        }
        if (args["isAnime"] == false) return manga.execute(call)
        val id = args["sourceId"] as? String ?: error("Source id is required")
        val loaded = sources[id] ?: run { load(); sources[id] } ?: error("Source $id is not installed or trusted")
        val source = loaded.source
        return withTimeout(20_000) {
            when(call.method) {
                "getPreference", "saveSourcePreference" -> {
                    val configurable = source as? ConfigurableAnimeSource
                    if (configurable == null) {
                        check(call.method == "getPreference") { "Source has no preferences" }
                        emptyList<Any>()
                    } else SourcePreferences.execute(context, source.id, call.method, args, configurable::setupPreferenceScreen)
                }
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
                    videos.map { video -> mapOf("url" to video.videoUrl, "quality" to video.quality, "originalUrl" to video.url,
                        "headers" to video.headers?.names()?.associateWith { video.headers[it] ?: "" },
                        "subtitles" to video.subtitleTracks.map { mapOf("file" to it.url, "label" to it.lang) },
                        "audios" to video.audioTracks.map { mapOf("file" to it.url, "label" to it.lang) }) }
                }
                else -> error("Unsupported anime source operation ${call.method}")
            }
        }
    }
    private fun media(s: SAnime): Map<String, Any?> = mapOf("title" to s.title, "url" to s.url, "thumbnail_url" to s.thumbnail_url,
        "description" to s.description, "genre" to s.genre?.split(',')?.map { it.trim() }, "status" to when(s.status) { 1 -> "Ongoing"; 2 -> "Completed"; 3 -> "Licensed"; 4 -> "Publishing finished"; 5 -> "Cancelled"; 6 -> "On hiatus"; else -> "Unknown" }, "author" to s.author, "artist" to s.artist)
    private fun page(p: AnimesPage) = mapOf("list" to p.animes.map(::media), "hasNextPage" to p.hasNextPage)
}
