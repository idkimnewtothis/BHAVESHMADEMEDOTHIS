package eu.kanade.tachiyomi

/** Host identity exposed through the pinned extension API. */
object AppInfo {
    fun getVersionCode(): Int = 1
    fun getVersionName(): String = "1.0.0"
}
