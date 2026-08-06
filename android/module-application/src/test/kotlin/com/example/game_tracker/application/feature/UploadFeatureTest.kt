package com.example.game_tracker.application.feature

import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.feature.UploadPayload
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.infrastructure.controller.FakeUploadController
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class UploadFeatureTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun uploadFeature_networkAvailable_enqueuesUploadWorkerSuccessfully() = runBlocking {
        val fakeUploadController = FakeUploadController()
        val uploadFeature = UploadFeature(fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(uploadFeature)

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

        val command = UploadCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_up_001"),
                traceId = TraceId("trace_up_001"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI
            ),
            localFilePath = "/cache/screenshot_test.png",
            destinationFolder = "remote_captures"
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_up_001"), commandId = CommandId("cmd_up_001"))
        val executionContext = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.WORK_MANAGER,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.ADMIN_UI
        )

        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)
        assertTrue(result is CommandResult.Completed)

        val completed = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.SUCCESS, completed.report.status)
        assertTrue(completed.report.payload is UploadPayload)

        val payload = completed.report.payload as UploadPayload
        assertNotNull(payload.workRequestId)
        assertEquals("/cache/screenshot_test.png", payload.localFilePath)
    }

    @Test
    fun uploadFeature_noNetwork_queuesUploadCommand() = runBlocking {
        val fakeUploadController = FakeUploadController()
        val uploadFeature = UploadFeature(fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(uploadFeature)

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

        val command = UploadCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_up_002"),
                traceId = TraceId("trace_up_002"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.FCM_PUSH
            ),
            localFilePath = "/cache/photo_test.jpg"
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_up_002"), commandId = CommandId("cmd_up_002"))
        val executionContext = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.WORK_MANAGER,
            networkAvailable = false, // Offline
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)
        assertTrue(result is CommandResult.Completed)

        val completed = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.QUEUED, completed.report.status)
    }
}
