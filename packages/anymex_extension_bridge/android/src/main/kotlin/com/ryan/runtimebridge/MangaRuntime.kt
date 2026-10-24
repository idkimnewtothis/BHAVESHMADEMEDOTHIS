package com.ryan.runtimebridge

import android.content.Context
import android.content.pm.PackageInfo
import dalvik.system.PathClassLoader
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.model.*
import eu.kanade.tachiyomi.source.online.HttpSource
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.withTimeout

/** Public source-api from Mihon v0.21.2, supporting libraries 1.4 and 1.6. */
internal class MangaRuntime(private val context: Context) {
    private val sources = java.util.concurrent.ConcurrentHashMap<String, Source>()
    val failures = mutableListOf<Map<String, String>>()
    @Synchronized fun load(packages: List<PackageInfo>, verify: (PackageInfo) -> Unit): List<Map<String, Any?>> {
        val next = mutableMapOf<String, Source>()
        val result = mutableListOf<Map<String, Any?>>()
        failures.clear()
        for (info in packages.filter { it.packageName.startsWith("eu.kanade.tachiyomi.extension.") }) {
            try {
                verify(info)
                val app = info.applicationInfo ?: error("Application metadata missing")
                val loader = PathClassLoader(app.sourceDir, context.classLoader)
                val classes = app.metaData.getString("tachiyomi.extension.class") ?: error("Source class metadata missing")
                for (name in classes.split(';')) {
                    val full = name.trim().let { if (it.startsWith('.')) info.packageName + it else it }
                    val instance = loader.loadClass(full).getDeclaredConstructor().newInstance()
                    val loaded = when(instance) {
                        is Source -> listOf(instance)
                        is SourceFactory -> instance.createSources()
                        else -> error("Unsupported source class $full")
                    }
                    for (s in loaded) {
                        check(next.put(s.id.toString(), s) == null) { "Duplicate source id ${s.id}" }
                        result += mapOf("id" to s.id.toString(), "name" to s.name, "pkgName" to info.packageName,
                            "version" to info.versionName, "lang" to s.lang, "baseUrl" to (s as? HttpSource)?.baseUrl,
                            "itemType" to 0, "isShared" to true, "supportsLatest" to s.supportsLatest, "supportsPopular" to true,
                            "isNsfw" to (app.metaData.getInt("tachiyomi.extension.nsfw", 0) == 1))
                    }
                }
            } catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                failures += mapOf("package" to info.packageName, "reason" to (e.message ?: e.javaClass.simpleName))
            }
        }
        sources.clear(); sources.putAll(next)
        return result
    }
    suspend fun execute(call: MethodCall): Any? = withTimeout(30_000) {
        val a = call.arguments as Map<*, *>
        val source = sources[a["sourceId"]] ?: error("Manga source ${a["sourceId"]} is not installed or trusted. Refresh Sources.")
        when(call.method) {
            "getPopular" -> page(source.getPopularManga((a["page"] as Number).toInt()))
            "getLatestUpdates" -> page(source.getLatestUpdates((a["page"] as Number).toInt()))
            "search" -> page(source.getSearchManga((a["page"] as Number).toInt(), a["query"] as String, source.getFilterList()))
            "getFilterList" -> emptyList<Any>()
            "getDetail" -> {
                val input = a["media"] as Map<*, *>
                val manga = SManga.create().apply { url = input["url"] as? String ?: error("Title URL missing"); title = input["title"] as? String ?: "" }
                require(manga.url.isNotEmpty()) { "Title URL is empty" }
                val update = source.getMangaUpdate(manga, emptyList(), true, true)
                media(update.manga).toMutableMap().apply {
                    put("url", manga.url)
                    put("episodes", update.chapters.map { c -> mapOf("url" to c.url, "name" to c.name,
                        "episodeNumber" to c.chapter_number.toDouble(), "dateUpload" to c.date_upload, "scanlator" to c.scanlator) })
                }
            }
            "getPageList" -> {
                val input = a["episode"] as Map<*, *>
                val chapter = SChapter.create().apply { url = input["url"] as String; name = input["name"] as? String ?: "" }
                val http = source as? HttpSource
                source.getPageList(chapter).map { p ->
                    val url = p.imageUrl?.takeIf { it.isNotEmpty() } ?: http?.getImageUrl(p) ?: error("${source.name}: page ${p.index + 1} has no image URL")
                    p.imageUrl = url
                    val request = http?.imageRequest(p)
                    mapOf("url" to (request?.url?.toString() ?: url), "headers" to request?.headers?.names()?.associateWith { request.header(it) ?: "" })
                }
            }
            else -> error("Unsupported manga operation ${call.method}")
        }
    }
    private fun media(s: SManga): Map<String, Any?> = mapOf("url" to s.url, "title" to s.title, "thumbnail_url" to s.thumbnail_url,
        "description" to s.description, "genre" to s.genre?.split(',')?.map { it.trim() }, "author" to s.author, "artist" to s.artist,
        "status" to when(s.status) { 1 -> "Ongoing"; 2 -> "Completed"; 3 -> "Licensed"; 4 -> "Publishing finished"; 5 -> "Cancelled"; 6 -> "On hiatus"; else -> "Unknown" })
    private fun page(p: MangasPage) = mapOf("list" to p.mangas.map(::media), "hasNextPage" to p.hasNextPage)
}
