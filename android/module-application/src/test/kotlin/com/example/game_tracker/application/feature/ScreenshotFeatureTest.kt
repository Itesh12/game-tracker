package com.example.game_tracker.application.feature

import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.engine.RecoveryEngine
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.policy.DefaultExecutionPolicyResolver
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.ScreenshotPayload
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.infrastructure.controller.FakeMediaProjectionController
import com.example.game_tracker.infrastructure.controller.FakeUploadController
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class ScreenshotFeatureTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun screenshotFeature_foregroundValidToken_capturesAndEnqueuesUpload() = runBlocking {
        val fakeMediaController = FakeMediaProjectionController(tokenValid = true)
        val fakeUploadController = FakeUploadController()
        val screenshotFeature = ScreenshotFeature(fakeMediaController, fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(screenshotFeature)

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

        val command = ScreenshotCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_shot_001"),
                traceId = TraceId("trace_shot_001"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI
            )
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_shot_001"), commandId = CommandId("cmd_shot_001"))
        val executionContext = ExecutionContext(
            processState = ProcessState.FOREGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FLUTTER,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.ADMIN_UI
        )

        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)
        assertTrue(result is CommandResult.Completed)

        val completed = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.SUCCESS, completed.report.status)
        assertTrue(completed.report.payload is ScreenshotPayload)

        val payload = completed.report.payload as ScreenshotPayload
        assertNotNull(payload.filePath)
        assertNotNull(payload.uploadWorkId)
    }

    @Test
    fun screenshotFeature_expiredConsentToken_returnsBlockedByPermission() = runBlocking {
        val fakeMediaController = FakeMediaProjectionController(tokenValid = false) // Expired Token
        val fakeUploadController = FakeUploadController()
        val screenshotFeature = ScreenshotFeature(fakeMediaController, fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(screenshotFeature)

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

        val command = ScreenshotCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_shot_002"),
                traceId = TraceId("trace_shot_002"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.FCM_PUSH
            )
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_shot_002"), commandId = CommandId("cmd_shot_002"))
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
