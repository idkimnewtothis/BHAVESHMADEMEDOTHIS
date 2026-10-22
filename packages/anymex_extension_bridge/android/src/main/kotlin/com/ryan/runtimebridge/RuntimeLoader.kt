package com.ryan.runtimebridge

import android.content.Context

/** External runtime hosts are forbidden; the anime runtime is built with the app. */
object RuntimeLoader {
    fun loadRuntime(context: Context, path: String): LoadedBridge {
        throw UnsupportedOperationException("External runtime APKs are not supported in this build")
    }
}

data class LoadedBridge(val bridgeClass: Class<*>, val bridgeInstance: Any)
