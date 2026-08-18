package com.example.game_tracker

import android.content.Context
import android.content.Intent

object MediaProjectionStore {
    private const val PREFS_NAME = "media_projection_prefs"
    private const val KEY_RESULT_CODE = "media_projection_result_code"
    private const val KEY_INTENT_URI = "media_projection_intent_uri"

    @Volatile
    var cachedResultCode: Int = 0
    @Volatile
    var cachedResultData: Intent? = null

    fun save(context: Context, resultCode: Int, data: Intent) {
        cachedResultCode = resultCode
        cachedResultData = data
        try {
            val uri = data.toUri(Intent.URI_INTENT_SCHEME)
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_RESULT_CODE, resultCode)
                .putString(KEY_INTENT_URI, uri)
                .apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun load(context: Context): Pair<Int, Intent?> {
        if (cachedResultCode != 0 && cachedResultData != null) {
            return Pair(cachedResultCode, cachedResultData)
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val resultCode = prefs.getInt(KEY_RESULT_CODE, 0)
        val intentUri = prefs.getString(KEY_INTENT_URI, null)
        if (intentUri.isNullOrEmpty()) {
            return Pair(0, null)
        }
        return try {
            val intent = Intent.parseUri(intentUri, 0)
            Pair(resultCode, intent)
        } catch (e: Exception) {
            e.printStackTrace()
            Pair(0, null)
        }
    }

    fun hasPermission(context: Context): Boolean {
        val (resultCode, data) = load(context)
        return resultCode != 0 && data != null
    }
}
