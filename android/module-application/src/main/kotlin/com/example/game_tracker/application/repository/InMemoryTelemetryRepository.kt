package com.example.game_tracker.application.repository

import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.FeatureId
import com.example.game_tracker.domain.model.TraceId
import com.example.game_tracker.domain.repository.TelemetryRepository

data class MetricRecord(
    val traceId: TraceId,
    val commandId: CommandId,
    val featureId: FeatureId,
    val executionMode: String,
    val durationMs: Long,
    val success: Boolean,
    val error: String?
)

data class AuditRecord(
    val traceId: TraceId,
    val commandId: CommandId,
    val featureId: FeatureId,
    val status: String,
    val durationMs: Long
)

class InMemoryTelemetryRepository : TelemetryRepository {
    val loggedMetrics = mutableListOf<MetricRecord>()
    val auditRecords = mutableListOf<AuditRecord>()

    override fun logMetric(
        traceId: TraceId,
        commandId: CommandId,
        featureId: FeatureId,
        executionMode: String,
        durationMs: Long,
        success: Boolean,
        error: String?
    ) {
        loggedMetrics.add(MetricRecord(traceId, commandId, featureId, executionMode, durationMs, success, error))
    }

    override fun recordAudit(
        traceId: TraceId,
        commandId: CommandId,
        featureId: FeatureId,
        status: String,
        durationMs: Long
    ) {
        auditRecords.add(AuditRecord(traceId, commandId, featureId, status, durationMs))
    }
}
