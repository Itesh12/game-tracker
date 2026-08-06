package com.example.game_tracker.domain.command

import com.example.game_tracker.domain.model.*

data class ExecutionContext(
    val processState: ProcessState,
    val platformCondition: PlatformCondition,
    val executor: ExecutorType,
    val networkAvailable: Boolean,
    val batteryOptimized: Boolean,
    val restoredFromProcessDeath: Boolean,
    val source: CommandSource
)
