package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.CameraCommand
import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.controller.CameraController
import com.example.game_tracker.domain.controller.UploadController
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.FailureCategory
import com.example.game_tracker.domain.model.PlatformRestriction

class CameraFeature(
    private val cameraController: CameraController,
    private val uploadController: UploadController
) : Feature {

    override val featureId = FeatureId("FEATURE_CAMERA")
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
        val cameraCmd = command as CameraCommand
        val start = services.clock.currentTimeMillis()

        // 1. Check Camera Availability & Permission
        if (!cameraController.isCameraAvailable()) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_OS,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.DEVICE_UNSUPPORTED,
                payload = EmptyPayload("Camera hardware not available on device"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        if (!cameraController.isCameraPermissionGranted()) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_PERMISSION,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.PERMISSION_DENIED,
                payload = EmptyPayload(PlatformRestriction.CameraPermissionMissing.message),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        // 2. Capture Still Photo via Controller Contract
        val photoPath = cameraController.captureStillPhoto(cameraCmd.cameraFacing)

        // 3. Enqueue Cloudinary Upload Worker
        val workId = uploadController.enqueueUploadWorker(
            localFilePath = photoPath,
            destinationUrl = cameraCmd.targetCloudinaryFolder
        )

        val duration = services.clock.currentTimeMillis() - start
        services.logger.d("CameraFeature", "Captured photo ($cameraFacing) at $photoPath, uploadWorkId=$workId")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = duration,
            payload = CameraPayload(
                imagePath = photoPath,
                cameraFacing = cameraCmd.cameraFacing,
                uploadWorkId = workId
            ),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
