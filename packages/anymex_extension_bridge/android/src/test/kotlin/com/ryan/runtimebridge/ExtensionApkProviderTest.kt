package com.ryan.runtimebridge

import androidx.core.content.FileProvider
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ExtensionApkProviderTest {
    @Test fun installerUriResolvesAndDoesNotExposeOtherCacheFiles() {
        val context = RuntimeEnvironment.getApplication()
        val authority = "${context.packageName}.anime-apks"
        val directory = File(context.cacheDir, "anime-apks/test-install").apply { mkdirs() }
        val apk = File(directory, "fixture.apk").apply { writeBytes(byteArrayOf(80,75,3,4)) }
        val other = File(context.cacheDir, "not-an-extension.txt").apply { writeText("private") }
        try {
            val uri = FileProvider.getUriForFile(context, authority, apk)
            assertEquals("content", uri.scheme)
            assertEquals(authority, uri.authority)
            assertArrayEquals(apk.readBytes(), context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
            try { FileProvider.getUriForFile(context, authority, other); fail("Other cache files must not be shared") }
            catch (_: IllegalArgumentException) {}
        } finally { directory.deleteRecursively(); other.delete() }
    }
}
