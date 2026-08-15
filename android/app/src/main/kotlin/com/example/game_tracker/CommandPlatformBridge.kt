package com.example.game_tracker

import com.example.game_tracker.application.engine.CommandProcessingEngine
import com.example.game_tracker.application.feature.SimpleFeatureProvider
import com.example.game_tracker.application.feature.*
import com.example.game_tracker.application.pipeline.*
import com.example.game_tracker.application.repository.InMemoryCommandRepository
import com.example.game_tracker.application.repository.InMemoryTelemetryRepository
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.infrastructure.service.*
import com.example.game_tracker.infrastructure.worker.UploadControllerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.UUID

class CommandPlatformBridge(
    private val context: android.content.Context,
    private val methodChannel: MethodChannel
) : MethodChannel.MethodCallHandler {

    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val commandRepo = InMemoryCommandRepository()
    private val telemetryRepo = InMemoryTelemetryRepository()

    private val mediaProjectionController = MediaProjectionControllerImpl(context)
    private val cameraController = CameraControllerImpl(context)
    private val locationController = LocationControllerImpl(context)
    private val uploadController = UploadControllerImpl(context)
    private val webRtcController = WebRtcControllerImpl(context)

    private val featureProvider = SimpleFeatureProvider().apply {
        register(PingFeature())
        register(ScreenshotFeature(mediaProjectionController, uploadController))
        register(CameraFeature(cameraController, uploadController))
        register(LocationFeature(locationController))
        register(UploadFeature(uploadController))
        register(WebRtcStreamFeature(webRtcController))
    }

    private val middlewarePipeline = listOf(
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

    private val engine = CommandProcessingEngine(middlewarePipeline)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "executeCommand") {
            val commandType = call.argument<String>("type") ?: "PING"
            val payloadMap = call.argument<Map<String, Any>>("payload") ?: emptyMap()

            coroutineScope.launch {
                val response = executeCommandInternal(commandType, payloadMap)
                result.success(response)
            }
        } else {
            result.notImplemented()
        }
    }

    private suspend fun executeCommandInternal(
        commandType: String,
        payloadMap: Map<String, Any>
    ): Map<String, Any> = withContext(Dispatchers.Default) {
        val commandId = CommandId("cmd_${UUID.randomUUID()}")
        val traceId = TraceId("trace_${UUID.randomUUID()}")
        val metadata = CommandMetadata(
            commandId = commandId,
            traceId = traceId,
            expiresAtTimestamp = System.currentTimeMillis() + 60000L,
            origin = CommandSource.ADMIN_UI
        )

        val command: DomainCommand = when (commandType.uppercase()) {
            "PING" -> PingCommand(metadata, echoMessage = payloadMap["echoMessage"] as? String ?: "PING_OK")
            "SCREENSHOT" -> ScreenshotCommand(metadata, quality = (payloadMap["quality"] as? Number)?.toInt() ?: 80)
            "CAMERA" -> CameraCommand(metadata, cameraFacing = payloadMap["cameraFacing"] as? String ?: "BACK")
            "LOCATION" -> LocationCommand(metadata, highAccuracy = payloadMap["highAccuracy"] as? Boolean ?: true)
            "UPLOAD" -> UploadCommand(metadata, localFilePath = payloadMap["localFilePath"] as? String ?: "")
            "WEBRTC_STREAM" -> StreamCommand(metadata, streamType = payloadMap["streamType"] as? String ?: "SCREEN")
            else -> PingCommand(metadata)
        }

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
                override fun d(tag: String, message: String) { println("BRIDGE [$tag]: $message") }
                override fun e(tag: String, message: String, throwable: Throwable?) { println("BRIDGE [$tag]: $message") }
            },
            clock = object : SystemClock {
                override fun currentTimeMillis(): Long = System.currentTimeMillis()
            }
        )

        val cmdResult = engine.processCommand(command, pipelineContext, executionContext, systemServices)

        when (cmdResult) {
            is CommandResult.Completed -> {
                val report = cmdResult.report
                mapOf(
                    "status" to report.status.name,
                    "commandId" to report.commandId.value,
                    "traceId" to report.traceId.value,
                    "featureId" to report.featureId.value,
                    "durationMs" to report.durationMs,
                    "timestamp" to report.timestamp
                )
            }
            is CommandResult.Rejected -> {
                mapOf(
                    "status" to "REJECTED",
                    "commandId" to cmdResult.commandId.value,
                    "reason" to cmdResult.reason
                )
            }
            is CommandResult.BlockedByPlatform -> {
                mapOf(
                    "status" to "BLOCKED",
                    "commandId" to cmdResult.commandId.value,
                    "reason" to cmdResult.restriction
                )
            }
            else -> {
                mapOf(
                    "status" to "PENDING",
                    "result" to cmdResult.toString()
                )
            }
        }
    }
}
