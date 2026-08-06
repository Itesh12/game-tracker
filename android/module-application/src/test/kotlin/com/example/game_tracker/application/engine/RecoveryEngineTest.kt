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

class RecoveryEngineTest {

    private class TestLogger : FeatureLogger {
        override fun d(tag: String, message: String) { println("DEBUG [$tag]: $message") }
        override fun e(tag: String, message: String, throwable: Throwable?) { println("ERROR [$tag]: $message") }
    }

    private class TestClock : SystemClock {
        override fun currentTimeMillis(): Long = System.currentTimeMillis()
    }

    @Test
    fun recoveryEngine_resumesPendingCommands_afterSimulatedProcessDeath() = runBlocking {
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

        // 2. Simulate pending command saved before process death (LMK)
        val commandId = CommandId("cmd_orphaned_101")
        val traceId = TraceId("trace_orphaned_101")

        val orphanedCommand = PingCommand(
            metadata = CommandMetadata(
                commandId = commandId,
                traceId = traceId,
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.FCM_PUSH,
                priority = CommandPriority.HIGH
            ),
            echoMessage = "PROCESS_DEATH_RESURRECTION"
        )

        commandRepo.saveCommand(orphanedCommand, ExecutionResultStatus.QUEUED)

        // 3. Instantiate RecoveryEngine & Trigger Recovery
        val recoveryEngine = RecoveryEngine(commandRepo, engine)
        val pendingList = listOf(orphanedCommand)

        val results = recoveryEngine.recoverPendingCommands(pendingList, testServices)

        // 4. Assert Resurrection Success
        assertEquals(1, results.size)
        assertTrue("Recovery result must be Completed", results[0] is CommandResult.Completed)

        val completed = results[0] as CommandResult.Completed
        assertEquals(ExecutionResultStatus.SUCCESS, completed.report.status)
        assertEquals(ProcessState.RESTORED, completed.report.executionContext.processState)
        assertTrue(completed.report.executionContext.restoredFromProcessDeath)
    }
}
