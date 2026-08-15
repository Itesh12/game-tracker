package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.command.ScreenshotCommand
import com.example.game_tracker.domain.controller.MediaProjectionController
import com.example.game_tracker.domain.controller.UploadController
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.FailureCategory
import com.example.game_tracker.domain.model.PlatformRestriction

class ScreenshotFeature(
    private val mediaProjectionController: MediaProjectionController,
    private val uploadController: UploadController
) : Feature {

    override val featureId = FeatureId("FEATURE_SCREENSHOT")
    override val policy = CapabilityPolicy(
        requiresNetwork = false,
        supportsFGS = true,
        requiresForegroundService = true,
        supportsRecovery = true
    )

    override suspend fun execute(
        command: DomainCommand,
        context: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport {
        val screenshotCmd = command as ScreenshotCommand
        val start = services.clock.currentTimeMillis()

        // 1. Evaluate MediaProjection consent token validity
        if (!mediaProjectionController.isConsentTokenValid()) {
            services.logger.e("ScreenshotFeature", "MediaProjection consent token invalid or expired")
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_PERMISSION,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.PERMISSION_DENIED,
                payload = EmptyPayload(PlatformRestriction.MediaProjectionConsentRequired.message),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        // 2. Perform Capture via Controller Contract
        val imageBytes = mediaProjectionController.captureVirtualDisplay()
        val filePath = mediaProjectionController.savePngToCache(imageBytes)

        // 3. Enqueue Cloudinary Upload Worker
        val workId = uploadController.enqueueUploadWorker(
            localFilePath = filePath,
            destinationUrl = screenshotCmd.targetCloudinaryFolder
        )

        val duration = services.clock.currentTimeMillis() - start
        services.logger.d("ScreenshotFeature", "Captured screenshot successfully at $filePath, uploadWorkId=$workId")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = duration,
            payload = ScreenshotPayload(
                filePath = filePath,
                width = 1080,
                height = 1920,
                uploadWorkId = workId
            ),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
