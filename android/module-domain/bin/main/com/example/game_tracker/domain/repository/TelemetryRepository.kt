package com.example.game_tracker.domain.repository

import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.TraceId

interface TelemetryRepository {
    fun logMetric(
        traceId: TraceId,
        commandId: CommandId,
        featureId: FeatureId,
        executionMode: String,
        durationMs: Long,
        success: Boolean,
        error: String? = null
    )

    fun recordAudit(
        traceId: TraceId,
        commandId: CommandId,
        featureId: FeatureId,
        status: String,
        durationMs: Long
    )
}
