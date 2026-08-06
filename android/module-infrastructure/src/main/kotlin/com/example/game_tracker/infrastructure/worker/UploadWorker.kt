package com.example.game_tracker.infrastructure.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class UploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val filePath = inputData.getString("KEY_FILE_PATH") ?: return@withContext Result.failure()
        val file = File(filePath)

        if (!file.exists()) {
            return@withContext Result.failure()
        }

        // Simulate Cloudinary HTTP REST Upload
        try {
            kotlinx.coroutines.delay(200L)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
