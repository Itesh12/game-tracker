package com.example.game_tracker

import android.app.Application
import com.google.firebase.FirebaseApp
import android.util.Log

class GameTrackerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            FirebaseApp.initializeApp(this)
            Log.i("GameTrackerApp", "Firebase initialized in native Application")
        } catch (e: Exception) {
            Log.w("GameTrackerApp", "Firebase initialization failed: ${e.message}")
        }
    }
}
