package com.example.game_tracker.application.policy

import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.CapabilityPolicy
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.policy.*

class DefaultExecutionPolicyResolver(
    private val capabilityProvider: DeviceCapabilityProvider = DefaultDeviceCapabilityProvider(),
    private val powerPolicyManager: PowerPolicyManager = DefaultPowerPolicyManager()
) : ExecutionPolicyResolver {

    override fun resolvePolicy(
        context: ExecutionContext,
        policy: CapabilityPolicy
    ): PolicyDecision {
        // 1. Check Platform Condition lockout (FORCE_STOPPED)
        if (context.platformCondition == PlatformCondition.FORCE_STOPPED) {
            return PolicyDecision.Blocked(
                status = ExecutionResultStatus.BLOCKED_BY_OS,
                reason = "Application is in FLAG_STOPPED state (Force-Stopped by user)"
            )
        }

        // 2. Check Permission Requirements
        if (policy.requiresForegroundService && !capabilityProvider.isPermissionGranted("android.permission.FOREGROUND_SERVICE")) {
            return PolicyDecision.Blocked(
                status = ExecutionResultStatus.BLOCKED_BY_PERMISSION,
                reason = "Foreground service permission denied"
            )
        }

        // 3. Check Network Requirement
        if (policy.requiresNetwork && !context.networkAvailable) {
            return PolicyDecision.Queue(
                reason = "Command requires network connection which is currently unavailable"
            )
        }

        // 4. Evaluate Power Conditions
        val powerResult = powerPolicyManager.evaluatePowerCondition(policy)
        if (!powerResult.canExecuteImmediately) {
            return PolicyDecision.Queue(
                reason = powerResult.deferralReason ?: "Deferred due to power optimization"
            )
        }

        // 5. Process State Execution Decision Routing
        return when (context.processState) {
            ProcessState.FOREGROUND -> PolicyDecision.Execute(
                executor = ExecutorType.FLUTTER,
                reason = "Executing in Foreground via Flutter UI"
            )

            ProcessState.BACKGROUND, ProcessState.RESTORED -> {
                when {
                    policy.supportsFGS -> PolicyDecision.Execute(
                        executor = ExecutorType.FOREGROUND_SERVICE,
                        requiresForegroundNotification = true,
                        requiresWakeLock = true,
                        reason = "Executing via Native Foreground Service"
                    )
                    policy.supportsWorkManager -> PolicyDecision.Execute(
                        executor = ExecutorType.WORK_MANAGER,
                        shouldPersistFirst = true,
                        reason = "Executing via WorkManager Job"
                    )
                    else -> PolicyDecision.Execute(
                        executor = ExecutorType.FLUTTER,
                        reason = "Executing via Flutter UI in Background"
                    )
                }
            }

            ProcessState.PROCESS_DEAD -> PolicyDecision.Queue(
                reason = "Process is dead; command queued for recovery resurrection"
            )
        }
    }
}

