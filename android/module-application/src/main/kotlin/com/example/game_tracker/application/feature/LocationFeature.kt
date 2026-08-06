package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.command.LocationCommand
import com.example.game_tracker.domain.controller.LocationController
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.FailureCategory

class LocationFeature(
    private val locationController: LocationController
) : Feature {

    override val featureId = FeatureId("FEATURE_LOCATION")
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
        val locationCmd = command as LocationCommand
        val start = services.clock.currentTimeMillis()

        // 1. Check GPS Availability & Permission
        if (!locationController.isGpsAvailable()) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_OS,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.DEVICE_UNSUPPORTED,
                payload = EmptyPayload("GPS hardware or location provider unavailable"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        if (!locationController.isLocationPermissionGranted()) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = featureId,
                status = ExecutionResultStatus.BLOCKED_BY_PERMISSION,
                executionContext = context,
                durationMs = services.clock.currentTimeMillis() - start,
                failureCategory = FailureCategory.PERMISSION_DENIED,
                payload = EmptyPayload("Location permission (android.permission.ACCESS_FINE_LOCATION) denied"),
                timestamp = services.clock.currentTimeMillis()
            )
        }

        // 2. Fetch Single Location Fix via Controller Contract
        val (lat, lng) = locationController.getSingleLocationFix(locationCmd.highAccuracy)
        val duration = services.clock.currentTimeMillis() - start

        services.logger.d("LocationFeature", "Fetched GPS fix: lat=$lat, lng=$lng")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = duration,
            payload = LocationPayload(
                latitude = lat,
                longitude = lng,
                accuracyMeters = 5.0f
            ),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
