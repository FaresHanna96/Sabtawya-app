package com.sabtawya.sabtawya

import android.content.Context
import org.json.JSONObject

/// The phone numbers the app may name when they call, kept in the app's own
/// private storage. Keys are the last ten digits of a number, values the name
/// to show ("أم مينا جورج – فصل 5 بنات"). Empty until the servant switches
/// "show caller name" on, and cleared when they switch it off or sign out.
object CallerIdStore {
    private const val FILE = "caller_id"
    private const val LABELS = "labels"

    fun save(context: Context, labels: Map<String, String>) {
        val json = JSONObject()
        for ((number, label) in labels) json.put(number, label)
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit().putString(LABELS, json.toString()).apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit().remove(LABELS).apply()
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).contains(LABELS)

    /// The name for [incoming], or null when it is not one of the saved numbers.
    fun lookup(context: Context, incoming: String): String? {
        val raw = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(LABELS, null) ?: return null
        val digits = incoming.filter { it.isDigit() }
        if (digits.isEmpty()) return null
        val key = if (digits.length <= 10) digits else digits.takeLast(10)
        return try {
            JSONObject(raw).optString(key, "").ifEmpty { null }
        } catch (e: Exception) {
            null
        }
    }
}
