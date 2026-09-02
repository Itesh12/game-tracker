package com.example.game_tracker

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager

object MediaProjectionStore {
    private const val PREFS_NAME = "media_projection_prefs"
    private const val KEY_RESULT_CODE = "media_projection_result_code"
    private const val KEY_INTENT_URI = "media_projection_intent_uri"

    @Volatile
    var cachedResultCode: Int = 0
    @Volatile
    var cachedResultData: Intent? = null
    @Volatile
    var activeMediaProjection: MediaProjection? = null
    @Volatile
    var activeVirtualDisplay: android.hardware.display.VirtualDisplay? = null
    @Volatile
    var activeImageReader: android.media.ImageReader? = null

    fun clear() {
        try {
            activeVirtualDisplay?.release()
        } catch (_: Throwable) {}
        activeVirtualDisplay = null

        try {
            activeImageReader?.close()
        } catch (_: Throwable) {}
        activeImageReader = null

        try {
            activeMediaProjection?.stop()
        } catch (_: Throwable) {}
        activeMediaProjection = null
    }

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

    fun getOrCreateMediaProjection(context: Context): MediaProjection? {
        if (activeMediaProjection != null) {
            return activeMediaProjection
        }
        val (resultCode, data) = load(context)
        if (resultCode == 0 || data == null) {
            return null
        }
        return try {
            val mgr = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val proj = mgr.getMediaProjection(resultCode, data)
            if (proj != null) {
                activeMediaProjection = proj
            }
            proj
        } catch (e: Throwable) {
            e.printStackTrace()
            null
        }
    }

    fun hasPermission(context: Context): Boolean {
        if (activeMediaProjection != null) return true

        // On Android 14+ (API 34+), MediaProjection tokens cannot survive process death.
        // If activeMediaProjection is null, a fresh consent is required.
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return false
        }

        if (cachedResultCode != 0 && cachedResultData != null) return true
        val (resultCode, data) = load(context)
        return resultCode != 0 && data != null
    }
}
