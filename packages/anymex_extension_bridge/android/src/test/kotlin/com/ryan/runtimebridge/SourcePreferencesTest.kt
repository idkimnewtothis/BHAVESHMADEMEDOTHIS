package com.ryan.runtimebridge

import android.content.Context
import androidx.preference.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SourcePreferencesTest {
    private val context get() = RuntimeEnvironment.getApplication()
    @Before fun prepare() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        context.getSharedPreferences("source_42", Context.MODE_PRIVATE).edit().clear().commit()
    }
    @After fun cleanup() { Dispatchers.resetMain() }
    private fun setup(screen: PreferenceScreen) {
        screen.addPreference(SwitchPreferenceCompat(screen.context).apply { key = "enabled"; title = "Enabled"; setDefaultValue(true) })
        screen.addPreference(ListPreference(screen.context).apply { key = "language"; entries = arrayOf("English", "Japanese"); entryValues = arrayOf("en", "ja"); setDefaultValue("en") })
        val group = PreferenceCategory(screen.context).apply { title = "Advanced" }
        screen.addPreference(group)
        group.addPreference(MultiSelectListPreference(screen.context).apply { key = "groups"; entries = arrayOf("One", "Two"); entryValues = arrayOf("one", "two"); setDefaultValue(setOf("one")) })
        group.addPreference(EditTextPreference(screen.context).apply { key = "label"; setDefaultValue("Default"); setOnPreferenceChangeListener { _, value -> value != "rejected" } })
    }
    @Suppress("UNCHECKED_CAST")
    private suspend fun read() = SourcePreferences.execute(context, 42, "getPreference", emptyMap<String,Any>(), ::setup) as List<Map<String,Any?>>
    private suspend fun save(key: String, value: Any) = SourcePreferences.execute(context,42,"saveSourcePreference",mapOf("key" to key,"value" to value),::setup)
    @Test fun defaultsAndNestedSettingsAreMapped() = runTest {
        val values = read().associateBy { it["key"] }
        assertEquals(4, values.size)
        assertEquals(true, values["enabled"]!!["value"])
        assertEquals("en", values["language"]!!["value"])
        assertEquals(listOf("one"), values["groups"]!!["value"])
        assertEquals("Default", values["label"]!!["value"])
    }
    @Test fun editsPersistAcrossNewScreensInSourceNamespace() = runTest {
        assertEquals(true, save("enabled",false))
        save("language","ja")
        save("groups", listOf("two"))
        save("label","Saved")
        val values = read().associateBy { it["key"] }
        assertEquals(false, values["enabled"]!!["value"])
        assertEquals("ja", values["language"]!!["value"])
        assertEquals(listOf("two"), values["groups"]!!["value"])
        assertEquals("Saved", context.getSharedPreferences("source_42",Context.MODE_PRIVATE).getString("label",null))
    }
    @Test fun invalidSelectionAndSourceRejectedValueDoNotPersist() = runTest {
        save("label","Accepted")
        try { save("label","rejected"); fail("listener must reject") } catch (_: IllegalStateException) {}
        try { save("language","invalid"); fail("invalid option must reject") } catch (_: IllegalArgumentException) {}
        try { save("enabled","false"); fail("wrong type must reject") } catch (_: IllegalStateException) {}
        val values = read().associateBy { it["key"] }
        assertEquals("Accepted", values["label"]!!["value"])
        assertEquals("en", values["language"]!!["value"])
        assertEquals(true, values["enabled"]!!["value"])
    }
}
