package com.example.game_tracker.infrastructure.worker

import android.content.Context
import androidx.work.*
import com.example.game_tracker.domain.controller.UploadController
import java.util.concurrent.TimeUnit

class UploadControllerImpl(
    private val context: Context
) : UploadController {

    override suspend fun enqueueUploadWorker(localFilePath: String, destinationUrl: String): String {
        val inputData = workDataOf("KEY_FILE_PATH" to localFilePath)

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val uploadWorkRequest = OneTimeWorkRequestBuilder<UploadWorker>()
            .setInputData(inputData)
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS
            )
            .build()

        WorkManager.getInstance(context).enqueue(uploadWorkRequest)
        return uploadWorkRequest.id.toString()
    }
}
