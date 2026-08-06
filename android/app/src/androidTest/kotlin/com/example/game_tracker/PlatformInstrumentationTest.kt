package com.example.game_tracker

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.feature.PingFeature
import com.example.game_tracker.application.feature.SimpleFeatureProvider
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.pipeline.PipelineContext
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class PlatformInstrumentationTest {

    @Test
    fun verifyAppContextPackageName() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("com.example.game_tracker", appContext.packageName)
    }

    @Test
    fun verifyNativeEnginePipelineExecutionOnDeviceContext() = runBlocking {
        val commandRepo = InMemoryCommandRepository()
        val telemetryRepo = InMemoryTelemetryRepository()

        val featureProvider = SimpleFeatureProvider().apply {
            register(PingFeature())
        }

        val pipeline = listOf(
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

        val engine = CommandProcessingEngine(pipeline)

        val commandId = CommandId("cmd_inst_${UUID.randomUUID()}")
        val traceId = TraceId("trace_inst_${UUID.randomUUID()}")
        val metadata = CommandMetadata(
            commandId = commandId,
            traceId = traceId,
            expiresAtTimestamp = System.currentTimeMillis() + 60000L,
            origin = CommandSource.ADMIN_UI
        )

        val pingCommand = PingCommand(metadata, echoMessage = "INSTRUMENTATION_PING")

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

        val systemServices = FeatureServices(
            logger = object : FeatureLogger {
                override fun d(tag: String, message: String) { println("INSTRUMENTATION [$tag]: $message") }
                override fun e(tag: String, message: String, throwable: Throwable?) { println("INSTRUMENTATION [$tag]: $message") }
            },
            clock = object : SystemClock {
                override fun currentTimeMillis(): Long = System.currentTimeMillis()
            }
        )

        val result = engine.processCommand(pingCommand, pipelineContext, executionContext, systemServices)

        assertTrue("Expected Completed result on device runtime", result is CommandResult.Completed)
        val report = (result as CommandResult.Completed).report
        assertEquals(commandId, report.commandId)
        assertEquals(CommandStatus.SUCCESS, report.status)
    }
}
