package com.example.game_tracker

import io.flutter.app.FlutterApplication
import com.google.firebase.FirebaseApp
import android.util.Log

class GameTrackerApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
            Log.i("GameTrackerApp", "Firebase initialized in native Application")
        } catch (e: Throwable) {
            Log.w("GameTrackerApp", "Firebase initialization info: ${e.message}")
        }
    }
}
