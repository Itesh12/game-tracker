package com.example.game_tracker.application.policy

import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.CapabilityPolicy
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.policy.PolicyDecision
import org.junit.Assert.*
import org.junit.Test

class ExecutionPolicyResolverTest {

    private val resolver = DefaultExecutionPolicyResolver()

    @Test
    fun foreground_anyFeature_resolvesToFlutterExecutor() {
        val context = ExecutionContext(
            processState = ProcessState.FOREGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FLUTTER,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.ADMIN_UI
        )

        val policy = CapabilityPolicy(requiresNetwork = false, supportsFGS = true)

        val decision = resolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Execute)
        assertEquals(ExecutorType.FLUTTER, (decision as PolicyDecision.Execute).executor)
    }

    @Test
    fun background_supportsFGS_resolvesToForegroundServiceExecutor() {
        val context = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FOREGROUND_SERVICE,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val policy = CapabilityPolicy(requiresNetwork = true, supportsFGS = true)

        val decision = resolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Execute)
        assertEquals(ExecutorType.FOREGROUND_SERVICE, (decision as PolicyDecision.Execute).executor)
    }

    @Test
    fun background_supportsWorkManager_resolvesToWorkManagerExecutor() {
        val context = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.WORK_MANAGER,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val policy = CapabilityPolicy(requiresNetwork = true, supportsFGS = false, supportsWorkManager = true)

        val decision = resolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Execute)
        assertEquals(ExecutorType.WORK_MANAGER, (decision as PolicyDecision.Execute).executor)
    }

    @Test
    fun forceStopped_anyFeature_resolvesToBlockedByOS() {
        val context = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.FORCE_STOPPED,
            executor = ExecutorType.FCM_SERVICE,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val policy = CapabilityPolicy(requiresNetwork = true, supportsFGS = true)

        val decision = resolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Blocked)
        assertEquals(ExecutionResultStatus.BLOCKED_BY_OS, (decision as PolicyDecision.Blocked).status)
    }

    @Test
    fun background_fgsRequired_permissionDenied_resolvesToBlockedByPermission() {
        val denierCapabilityProvider = object : DeviceCapabilityProvider {
            override fun isCapabilityAvailable(capabilityName: String): Boolean = true
            override fun isPermissionGranted(permissionName: String): Boolean = false
            override fun isNetworkAvailable(): Boolean = true
        }

        val customResolver = DefaultExecutionPolicyResolver(capabilityProvider = denierCapabilityProvider)

        val context = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.FOREGROUND_SERVICE,
            networkAvailable = true,
            batteryOptimized = false,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val policy = CapabilityPolicy(requiresForegroundService = true, supportsFGS = true)

        val decision = customResolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Blocked)
        assertEquals(ExecutionResultStatus.BLOCKED_BY_PERMISSION, (decision as PolicyDecision.Blocked).status)
    }

    @Test
    fun background_dozeActive_requiresNetwork_resolvesToQueue() {
        val dozePowerManager = DefaultPowerPolicyManager(isDozeActive = true)
        val customResolver = DefaultExecutionPolicyResolver(powerPolicyManager = dozePowerManager)

        val context = ExecutionContext(
            processState = ProcessState.BACKGROUND,
            platformCondition = PlatformCondition.NORMAL,
            executor = ExecutorType.WORK_MANAGER,
            networkAvailable = true,
            batteryOptimized = true,
            restoredFromProcessDeath = false,
            source = CommandSource.FCM_PUSH
        )

        val policy = CapabilityPolicy(requiresNetwork = true, supportsWorkManager = true)

        val decision = customResolver.resolvePolicy(context, policy)
        assertTrue(decision is PolicyDecision.Queue)
    }
}

