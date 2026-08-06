package com.example.game_tracker.application.feature

import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.CameraPayload
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.infrastructure.controller.FakeCameraController
import com.example.game_tracker.infrastructure.controller.FakeUploadController
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class CameraFeatureTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun cameraFeature_validPermission_capturesPhotoAndEnqueuesUpload() = runBlocking {
        val fakeCameraController = FakeCameraController(cameraAvailable = true, permissionGranted = true)
        val fakeUploadController = FakeUploadController()
        val cameraFeature = CameraFeature(fakeCameraController, fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(cameraFeature)

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

        val command = CameraCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_cam_001"),
                traceId = TraceId("trace_cam_001"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI
            ),
            cameraFacing = "BACK"
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_cam_001"), commandId = CommandId("cmd_cam_001"))
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
        assertTrue(completed.report.payload is CameraPayload)

        val payload = completed.report.payload as CameraPayload
        assertNotNull(payload.imagePath)
        assertEquals("BACK", payload.cameraFacing)
        assertNotNull(payload.uploadWorkId)
    }

    @Test
    fun cameraFeature_missingPermission_returnsBlockedByPermission() = runBlocking {
        val fakeCameraController = FakeCameraController(cameraAvailable = true, permissionGranted = false) // Denied
        val fakeUploadController = FakeUploadController()
        val cameraFeature = CameraFeature(fakeCameraController, fakeUploadController)

        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(cameraFeature)

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

        val command = CameraCommand(
            metadata = CommandMetadata(
                commandId = CommandId("cmd_cam_002"),
                traceId = TraceId("trace_cam_002"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.FCM_PUSH
            )
        )

        val pipelineContext = PipelineContext(traceId = TraceId("trace_cam_002"), commandId = CommandId("cmd_cam_002"))
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
