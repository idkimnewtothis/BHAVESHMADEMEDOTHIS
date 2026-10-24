package eu.kanade.tachiyomi

/** Host identity exposed through the pinned extension API. */
object AppInfo {
    fun getVersionCode(): Int = 2
    fun getVersionName(): String = "2.0.0"
}
