package com.example.game_tracker.domain.command

import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.CommandPriority
import com.example.game_tracker.domain.model.CommandSource
import com.example.game_tracker.domain.model.TraceId

data class CommandMetadata(
    val commandId: CommandId,
    val traceId: TraceId,
    val parentTraceId: TraceId? = null,
    val createdAtTimestamp: Long = System.currentTimeMillis(),
    val expiresAtTimestamp: Long,
    val attempt: Int = 1,
    val origin: CommandSource,
    val priority: CommandPriority = CommandPriority.NORMAL,
    val commandVersion: Int = 1,
    val schemaVersion: Int = 1,
    val appVersion: String = "1.0.0",
    val minSupportedVersion: String = "1.0.0"
)
