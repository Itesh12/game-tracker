package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.command.StreamCommand
import com.example.game_tracker.domain.controller.WebRtcController
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.FailureCategory
import com.example.game_tracker.domain.model.PlatformRestriction
import java.util.UUID

class WebRtcStreamFeature(
    private val webRtcController: WebRtcController
) : Feature {

    override val featureId = FeatureId("FEATURE_WEBRTC_STREAM")
    override val policy = CapabilityPolicy(
        requiresNetwork = true, // WebRTC requires active network connection
        supportsFGS = true,     // WebRTC requires active Foreground Service
        requiresForegroundService = true,
        supportsRecovery = true
    )

    override suspend fun execute(
        command: DomainCommand,
        context: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport {
        val streamCmd = command as StreamCommand
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
                payload = EmptyPayload("WebRTC Stream deferred: Network connection unavailable"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        if (!webRtcController.isWebRtcSupported()) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_OS,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.DEVICE_UNSUPPORTED,
                payload = EmptyPayload("WebRTC engine not supported on device"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        val initialized = webRtcController.initializePeerConnection(streamCmd.streamType)
        if (!initialized) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_PERMISSION,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.PERMISSION_DENIED,
                payload = EmptyPayload(PlatformRestriction.BackgroundActivityLaunchBlocked.message),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        val sdpAnswer = webRtcController.processSdpOffer(streamCmd.sdpOffer)
        val sessionId = "webrtc_session_${UUID.randomUUID()}"
        val duration = services.clock.currentTimeMillis() - start

        services.logger.d("WebRtcStreamFeature", "Initialized WebRTC peer connection session=$sessionId")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = duration,
            payload = StreamPayload(
                streamSessionId = sessionId,
                sdpAnswer = sdpAnswer,
                activeTracksCount = 2
            ),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
