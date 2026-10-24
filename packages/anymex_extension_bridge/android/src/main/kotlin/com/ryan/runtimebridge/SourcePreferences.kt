package com.ryan.runtimebridge

import android.content.Context
import android.view.ContextThemeWrapper
import androidx.preference.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Run extension-defined preference defaults and listeners on Android's UI thread. */
internal object SourcePreferences {
    suspend fun execute(context: Context, id: Long, method: String, args: Map<*, *>, setup: (PreferenceScreen) -> Unit): Any = withContext(Dispatchers.Main) {
        val themed = ContextThemeWrapper(context, androidx.appcompat.R.style.Theme_AppCompat)
        val manager = PreferenceManager(themed).apply { sharedPreferencesName = "source_$id" }
        val screen = manager.createPreferenceScreen(themed)
        setup(screen)
        val preferences = mutableListOf<Preference>()
        fun collect(group: PreferenceGroup) {
            for (i in 0 until group.preferenceCount) {
                val pref = group.getPreference(i)
                if (pref is PreferenceGroup) collect(pref) else preferences.add(pref)
            }
        }
        collect(screen)
        if (method == "saveSourcePreference") {
            val key = args["key"] as? String ?: error("Preference key is required")
            val pref = preferences.firstOrNull { it.key == key } ?: error("Unknown preference $key")
            check(pref.isEnabled) { "Preference $key is disabled" }
            val value = args["value"]
            val normalized: Any = when(pref) {
                is TwoStatePreference -> value as? Boolean ?: error("$key needs a boolean")
                is ListPreference -> (value as? String ?: error("$key needs a selection")).also {
                    require(pref.entryValues.any { v -> v.toString() == it }) { "Invalid selection for $key" }
                }
                is MultiSelectListPreference -> (value as? List<*>)?.map { it as? String ?: error("Invalid selection for $key") }?.toSet()?.also {
                    require(it.all { v -> pref.entryValues.any { entry -> entry.toString() == v } }) { "Invalid selection for $key" }
                } ?: error("$key needs a selection list")
                is EditTextPreference -> value as? String ?: error("$key needs text")
                else -> error("Unsupported preference $key")
            }
            check(pref.callChangeListener(normalized)) { "The source rejected this value for $key" }
            when(pref) {
                is TwoStatePreference -> pref.isChecked = normalized as Boolean
                is ListPreference -> pref.value = normalized as String
                is MultiSelectListPreference -> { @Suppress("UNCHECKED_CAST") val values = normalized as Set<String>; pref.values = values }
                is EditTextPreference -> pref.text = normalized as String
            }
            true
        } else {
            preferences.filter { !it.key.isNullOrEmpty() && it.isVisible }.mapNotNull { pref ->
                val item = mutableMapOf<String, Any?>("key" to pref.key, "title" to pref.title?.toString(), "summary" to pref.summary?.toString())
                when(pref) {
                    is CheckBoxPreference -> item.putAll(mapOf("type" to "checkbox", "value" to pref.isChecked))
                    is TwoStatePreference -> item.putAll(mapOf("type" to "switch", "value" to pref.isChecked))
                    is ListPreference -> item.putAll(mapOf("type" to "list", "value" to pref.value, "entries" to pref.entries?.map { it.toString() }, "entryValues" to pref.entryValues?.map { it.toString() }))
                    is MultiSelectListPreference -> item.putAll(mapOf("type" to "multi_select", "value" to pref.values.toList(), "entries" to pref.entries?.map { it.toString() }, "entryValues" to pref.entryValues?.map { it.toString() }))
                    is EditTextPreference -> item.putAll(mapOf("type" to "text", "value" to pref.text))
                    else -> return@mapNotNull null
                }
                item
            }
        }
    }
}
