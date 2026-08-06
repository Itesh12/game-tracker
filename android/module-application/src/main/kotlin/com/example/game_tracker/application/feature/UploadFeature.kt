package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.command.UploadCommand
import com.example.game_tracker.domain.controller.UploadController
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.FailureCategory

class UploadFeature(
    private val uploadController: UploadController
) : Feature {

    override val featureId = FeatureId("FEATURE_UPLOAD")
    override val policy = CapabilityPolicy(
        requiresNetwork = true, // Network mandatory for cloud upload
        supportsFGS = false,
        supportsWorkManager = true,
        supportsRecovery = true
    )

    override suspend fun execute(
        command: DomainCommand,
        context: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport {
        val uploadCmd = command as UploadCommand
        val start = services.clock.currentTimeMillis()

        if (!context.networkAvailable) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.QUEUED,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.NETWORK_UNAVAILABLE,
                payload = EmptyPayload("Upload deferred: Network connection unavailable"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        val workId = uploadController.enqueueUploadWorker(
            localFilePath = uploadCmd.localFilePath,
            destinationUrl = uploadCmd.destinationFolder
        )

        val duration = services.clock.currentTimeMillis() - start
        services.logger.d("UploadFeature", "Enqueued background upload workId=$workId for file=${uploadCmd.localFilePath}")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = duration,
            payload = UploadPayload(
                workRequestId = workId,
                localFilePath = uploadCmd.localFilePath,
                destinationUrl = uploadCmd.destinationFolder
            ),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
