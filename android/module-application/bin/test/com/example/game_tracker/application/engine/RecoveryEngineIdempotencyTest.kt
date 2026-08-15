package com.example.game_tracker.application.engine

import com.example.game_tracker.application.feature.PingFeature
import com.example.game_tracker.application.feature.SimpleFeatureProvider
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class RecoveryEngineIdempotencyTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun recoveryEngine_isIdempotent_andPreservesMetadata() = runBlocking {
        // 1. Setup Feature Provider & Engine
        val featureProvider = SimpleFeatureProvider()
        featureProvider.register(PingFeature())

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
        val recoveryEngine = RecoveryEngine(commandRepo, engine)

        // 2. Setup orphaned command
        val commandId = CommandId("cmd_idempotent_001")
        val traceId = TraceId("trace_idempotent_001")
        val createdAt = System.currentTimeMillis()

        val orphanedCommand = PingCommand(
            metadata = CommandMetadata(
                commandId = commandId,
                traceId = traceId,
                createdAtTimestamp = createdAt,
                expiresAtTimestamp = createdAt + 60000L,
                origin = CommandSource.ADMIN_UI,
                priority = CommandPriority.HIGH
            ),
            echoMessage = "IDEMPOTENCY_CHECK"
        )

        commandRepo.saveCommand(orphanedCommand, ExecutionResultStatus.QUEUED)

        // 3. First Recovery Execution
        val firstRecoveryResults = recoveryEngine.recoverPendingCommands(listOf(orphanedCommand), testServices)
        assertEquals(1, firstRecoveryResults.size)
        assertTrue(firstRecoveryResults[0] is CommandResult.Completed)

        // Verify status updated to SUCCESS in repository
        assertEquals(ExecutionResultStatus.SUCCESS, commandRepo.getStatus(commandId))

        // 4. Second Recovery Execution (Simulated subsequent trigger on completed commands)
        val pendingListSecondRun = listOf(orphanedCommand).filter {
            commandRepo.getStatus(it.metadata.commandId) == ExecutionResultStatus.QUEUED
        }

        val secondRecoveryResults = recoveryEngine.recoverPendingCommands(pendingListSecondRun, testServices)
        assertEquals(0, secondRecoveryResults.size) // 0 commands executed on second run

        // 5. Verify Metadata Preservation
        val completedReport = (firstRecoveryResults[0] as CommandResult.Completed).report
        assertEquals(commandId, completedReport.commandId)
        assertEquals(traceId, completedReport.traceId)
        assertEquals(ProcessState.RESTORED, completedReport.executionContext.processState)
        assertTrue(completedReport.executionContext.restoredFromProcessDeath)
    }
}
