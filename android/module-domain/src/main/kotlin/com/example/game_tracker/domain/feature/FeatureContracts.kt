package com.example.game_tracker.domain.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.model.*

// Strongly Typed Payload
sealed interface FeatureResultPayload

data class EmptyPayload(val message: String = "No payload returned") : FeatureResultPayload
data class PingPayload(val echoResponse: String) : FeatureResultPayload

data class CapabilityPolicy(
    val requiresNetwork: Boolean = false,
    val supportsFGS: Boolean = false,
    val supportsWorkManager: Boolean = false,
    val requiresUnlockedDevice: Boolean = false,
    val supportsRecovery: Boolean = false
)

interface FeatureLogger {
    fun d(tag: String, message: String)
    fun e(tag: String, message: String, throwable: Throwable? = null)
}

interface SystemClock {
    fun currentTimeMillis(): Long
}

data class FeatureServices(
    val logger: FeatureLogger,
    val clock: SystemClock
)

data class FeatureExecutionReport(
    val commandId: CommandId,
    val traceId: TraceId,
    val featureId: FeatureId,
    val status: ExecutionResultStatus,
    val executionContext: ExecutionContext,
    val durationMs: Long,
    val retryCount: Int = 0,
    val failureCategory: FailureCategory? = null,
    val payload: FeatureResultPayload? = null,
    val timestamp: Long = System.currentTimeMillis()
)

interface Feature {
    val featureId: FeatureId
    val policy: CapabilityPolicy

    suspend fun execute(
        command: DomainCommand,
        context: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport
}

interface FeatureProvider {
    fun get(featureId: FeatureId): Feature
}
