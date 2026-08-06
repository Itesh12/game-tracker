package com.example.game_tracker.application.feature

import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.LocationPayload
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.infrastructure.controller.FakeLocationController
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class LocationFeatureTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun locationFeature_validPermission_fetchesSingleFixSuccessfully() = runBlocking {
        val fakeLocationController = FakeLocationController(gpsAvailable = true, permissionGranted = true, latitude = 37.7749, longitude = -122.4194)
        val locationFeature = LocationFeature(fakeLocationController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(locationFeature)

        val commandRepo = InMemoryCommandRepository()
        val telemetryRepo = InMemoryTelemetryRepository()
        val testServices = FeatureServices(logger = TestLogger(), clock = TestClock())

        val middlewarePipeline = listOf(
            AuthenticationMiddleware(),
            ValidationMiddleware(),
            CapabilityMiddleware(),
            PowerPolicyMiddleware(),
            PersistenceMiddleware(commandRepo),
            ExecutionPolicyMiddleware(),
            HardwareLockMiddleware(featureProvider),
            TelemetryMiddleware(telemetryRepo),
            AuditMiddleware(telemetryRepo),
            ExecutionMiddleware(featureProvider)
        )

        val engine = CommandProcessingEngine(middlewarePipeline)

        val command = LocationCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_loc_001"),
                traceId = TraceId("trace_loc_001"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI
            ),
            highAccuracy = true
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_loc_001"), commandId = CommandId("cmd_loc_001"))
        val executionContext = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FOREGROUND_SERVICE,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.ADMIN_UI
        )

        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)
        assertTrue(result is CommandResult.Completed)

        val completed = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.SUCCESS, completed.report.status)
        assertTrue(completed.report.payload is LocationPayload)

        val payload = completed.report.payload as LocationPayload
        assertEquals(37.7749, payload.latitude, 0.0001)
        assertEquals(-122.4194, payload.longitude, 0.0001)
    }

    @Test
    fun locationFeature_missingPermission_returnsBlockedByPermission() = runBlocking {
        val fakeLocationController = FakeLocationController(gpsAvailable = true, permissionGranted = false) // Denied
        val locationFeature = LocationFeature(fakeLocationController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(locationFeature)

        val commandRepo = InMemoryCommandRepository()
        val telemetryRepo = InMemoryTelemetryRepository()
        val testServices = FeatureServices(logger = TestLogger(), clock = TestClock())

        val middlewarePipeline = listOf(
            AuthenticationMiddleware(),
            ValidationMiddleware(),
            CapabilityMiddleware(),
            PowerPolicyMiddleware(),
            PersistenceMiddleware(commandRepo),
            ExecutionPolicyMiddleware(),
            HardwareLockMiddleware(featureProvider),
            TelemetryMiddleware(telemetryRepo),
            AuditMiddleware(telemetryRepo),
            ExecutionMiddleware(featureProvider)
        )

        val engine = CommandProcessingEngine(middlewarePipeline)

        val command = LocationCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_loc_002"),
                traceId = TraceId("trace_loc_002"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.FCM_PUSH
            )
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_loc_002"), commandId = CommandId("cmd_loc_002"))
        val executionContext = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FOREGROUND_SERVICE,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)
        assertTrue(result is CommandResult.Completed)

        val completed = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.BLOCKED_BY_PERMISSION, completed.report.status)
        assertEquals(FailureCategory.PERMISSION_DENIED, completed.report.failureCategory)
    }
}
