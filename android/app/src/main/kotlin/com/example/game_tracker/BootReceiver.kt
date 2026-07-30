package com.example.game_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            try {
                // Start sticky background foreground service
                ForegroundService.startService(context)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            try {
                // Start main activity
                val i = Intent(context, MainActivity::class.java)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(i)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
