package com.example.game_tracker.domain.pipeline

import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.TraceId

data class PipelineContext(
    val traceId: TraceId,
    val commandId: CommandId,
    val pipelineStartTimeMs: Long = System.currentTimeMillis(),
    val authenticatedPrincipal: String? = null,
    val hardwareLockAcquired: Boolean = false,
    val retryAttempt: Int = 1,
    val middlewareMetadata: MutableMap<String, String> = mutableMapOf()
)
