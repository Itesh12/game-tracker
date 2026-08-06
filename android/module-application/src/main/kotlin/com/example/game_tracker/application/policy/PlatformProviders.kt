package com.example.game_tracker.application.policy

import com.example.game_tracker.domain.feature.CapabilityPolicy
import com.example.game_tracker.domain.policy.DeviceCapabilityProvider
import com.example.game_tracker.domain.policy.PowerEvaluationResult
import com.example.game_tracker.domain.policy.PowerPolicyManager

class DefaultDeviceCapabilityProvider(
    private val networkAvailable: Boolean = true
) : DeviceCapabilityProvider {
    override fun isCapabilityAvailable(capabilityName: String): Boolean = true
    override fun isPermissionGranted(permissionName: String): Boolean = true
    override fun isNetworkAvailable(): Boolean = networkAvailable
}

class DefaultPowerPolicyManager(
    private val isDozeActive: Boolean = false,
    private val isBatterySaverActive: Boolean = false,
    private val isThermalThrottlingActive: Boolean = false
) : PowerPolicyManager {

    override fun evaluatePowerCondition(policy: CapabilityPolicy): PowerEvaluationResult {
        val canExecute = !(isDozeActive && policy.requiresNetwork)
        val reason = if (!canExecute) "Execution deferred due to active Doze mode" else null

        return PowerEvaluationResult(
            canExecuteImmediately = canExecute,
            isDozeActive = isDozeActive,
            isBatterySaverActive = isBatterySaverActive,
            isThermalThrottlingActive = isThermalThrottlingActive,
            deferralReason = reason
        )
    }
}
