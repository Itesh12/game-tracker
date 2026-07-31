package com.example.game_tracker

import android.util.Log

object AppLogger {
    private const val TAG = "LudoRealmEngine"

    fun i(message: String) {
        Log.i(TAG, format(message))
    }

    fun d(message: String) {
        Log.d(TAG, format(message))
    }

    fun w(message: String) {
        Log.w(TAG, format(message))
    }

    fun e(message: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(TAG, format(message), throwable)
        } else {
            Log.e(TAG, format(message))
        }
    }

    private fun format(msg: String): String {
        val thread = Thread.currentThread().name
        return "[$thread] $msg"
    }
}
