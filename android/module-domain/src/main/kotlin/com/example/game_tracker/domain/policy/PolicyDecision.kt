package com.example.game_tracker.domain.policy

import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.CapabilityPolicy
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.ExecutorType

enum class RetryPolicy {
    NO_RETRY,
    IMMEDIATE_RETRY,
    EXPONENTIAL_BACKOFF
}

sealed interface PolicyDecision {
    data class Execute(
        val executor: ExecutorType,
        val requiresWakeLock: Boolean = false,
        val requiresForegroundNotification: Boolean = false,
        val shouldPersistFirst: Boolean = true,
        val retryPolicy: RetryPolicy = RetryPolicy.EXPONENTIAL_BACKOFF,
        val reason: String = "Policy resolved for execution"
    ) : PolicyDecision
    data class Queue(val reason: String) : PolicyDecision
    data class Blocked(val status: ExecutionResultStatus, val reason: String) : PolicyDecision
}


interface ExecutionPolicyResolver {
    fun resolvePolicy(
        context: ExecutionContext,
        policy: CapabilityPolicy
    ): PolicyDecision
}

interface DeviceCapabilityProvider {
    fun isCapabilityAvailable(capabilityName: String): Boolean
    fun isPermissionGranted(permissionName: String): Boolean
    fun isNetworkAvailable(): Boolean
}

interface PowerPolicyManager {
    fun evaluatePowerCondition(policy: CapabilityPolicy): PowerEvaluationResult
}

data class PowerEvaluationResult(
    val canExecuteImmediately: Boolean,
    val isDozeActive: Boolean,
    val isBatterySaverActive: Boolean,
    val isThermalThrottlingActive: Boolean,
    val deferralReason: String? = null
)
