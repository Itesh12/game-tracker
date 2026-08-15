package com.example.game_tracker.application.engine

import com.example.game_tracker.application.feature.PingFeature
import com.example.game_tracker.application.feature.SimpleFeatureProvider
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class PipelineIntegrationTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun pingCommand_flowsThroughPipeline_andReturnsPingPongOk() = runBlocking {
        // 1. Setup Feature Provider & Register PingFeature
        val featureProvider = SimpleFeatureProvider()
        val pingFeature = PingFeature()
        featureProvider.register(pingFeature)

        // 2. Setup Repositories & Services
        val commandRepo = InMemoryCommandRepository()
        val telemetryRepo = InMemoryTelemetryRepository()
        val testServices = FeatureServices(logger = TestLogger(), clock = TestClock())

        // 3. Assemble 10-Step Pipeline
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

        // 4. Create PingCommand & Contexts
        val commandId = CommandId("cmd_ping_001")
        val traceId = TraceId("trace_ping_001")

        val command = PingCommand(
            metadata = CommandMetadata(
                commandId = commandId,
                traceId = traceId,
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI
            ),
            echoMessage = "WORLD"
        )

        val pipelineContext = PipelineContext(traceId = traceId, commandId = commandId)
        val executionContext = ExecutionContext(
            processState = ProcessState.FOREGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FLUTTER,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.ADMIN_UI
        )

        // 5. Process Command through Engine
        val result = engine.processCommand(command, pipelineContext, executionContext, testServices)

        // 6. Assert Result
        assertTrue("Result must be Completed", result is CommandResult.Completed)
        val completedResult = result as CommandResult.Completed
        assertEquals(ExecutionResultStatus.SUCCESS, completedResult.report.status)
        assertTrue(completedResult.report.payload is PingPayload)

        val payload = completedResult.report.payload as PingPayload
        assertEquals("PING_PONG_OK: WORLD", payload.echoResponse)
        assertEquals("SKIPPED_NO_LOCK_REQUIRED", pipelineContext.middlewareMetadata["LOCK_STATUS"])


        // 7. Verify Telemetry & Audit Persistence
        assertEquals(1, telemetryRepo.loggedMetrics.size)
        assertEquals(1, telemetryRepo.auditRecords.size)
        assertEquals("SUCCESS", telemetryRepo.auditRecords[0].status)
    }
}
