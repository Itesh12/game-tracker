package com.example.game_tracker.application.pipeline

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.FeatureExecutionReport
import com.example.game_tracker.domain.feature.FeatureProvider
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.domain.repository.CommandRepository
import com.example.game_tracker.domain.repository.TelemetryRepository

class AuthenticationMiddleware : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        // Stub: Authentication verifiers check PASS
        pipelineContext.middlewareMetadata["AUTH_STATUS"] = "PASSED"
        return next(command, pipelineContext, executionContext, services)
    }
}

class ValidationMiddleware : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        val now = services.clock.currentTimeMillis()
        if (now > command.metadata.expiresAtTimestamp) {
            return FeatureExecutionReport(
                commandId = command.metadata.commandId,
                traceId = command.metadata.traceId,
                featureId = command.featureId,
                status = ExecutionResultStatus.EXPIRED,
                executionContext = executionContext,
                durationMs = 0L,
                timestamp = now
            )
        }
        pipelineContext.middlewareMetadata["VALIDATION_STATUS"] = "PASSED"
        return next(command, pipelineContext, executionContext, services)
    }
}

class CapabilityMiddleware : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        pipelineContext.middlewareMetadata["CAPABILITY_STATUS"] = "PASSED"
        return next(command, pipelineContext, executionContext, services)
    }
}

class PowerPolicyMiddleware : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        pipelineContext.middlewareMetadata["POWER_POLICY_STATUS"] = "PASSED"
        return next(command, pipelineContext, executionContext, services)
    }
}

class PersistenceMiddleware(
    private val commandRepository: CommandRepository
) : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        commandRepository.saveCommand(command, ExecutionResultStatus.QUEUED)
        pipelineContext.middlewareMetadata["PERSISTENCE_STATUS"] = "QUEUED_IN_MEMORY"
        return next(command, pipelineContext, executionContext, services)
    }
}

class ExecutionPolicyMiddleware : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        pipelineContext.middlewareMetadata["POLICY_STATUS"] = "RESOLVED"
        return next(command, pipelineContext, executionContext, services)
    }
}

class HardwareLockMiddleware(
    private val featureProvider: FeatureProvider
) : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        val feature = featureProvider.get(command.featureId)
        if (feature.policy.supportsFGS || feature.policy.requiresUnlockedDevice) {
            pipelineContext.middlewareMetadata["LOCK_STATUS"] = "ACQUIRED"
        } else {
            pipelineContext.middlewareMetadata["LOCK_STATUS"] = "SKIPPED_NO_LOCK_REQUIRED"
        }
        return next(command, pipelineContext, executionContext, services)
    }
}


class TelemetryMiddleware(
    private val telemetryRepository: TelemetryRepository
) : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        val start = services.clock.currentTimeMillis()
        val report = next(command, pipelineContext, executionContext, services)
        val duration = services.clock.currentTimeMillis() - start

        telemetryRepository.logMetric(
            traceId = command.metadata.traceId,
            commandId = command.metadata.commandId,
            featureId = command.featureId,
            executionMode = executionContext.executor.name,
            durationMs = duration,
            success = report.status == ExecutionResultStatus.SUCCESS,
            error = report.failureCategory?.name
        )

        return report
    }
}

class AuditMiddleware(
    private val telemetryRepository: TelemetryRepository
) : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        val start = services.clock.currentTimeMillis()
        val report = next(command, pipelineContext, executionContext, services)
        val duration = services.clock.currentTimeMillis() - start

        telemetryRepository.recordAudit(
            traceId = command.metadata.traceId,
            commandId = command.metadata.commandId,
            featureId = command.featureId,
            status = report.status.name,
            durationMs = duration
        )

        return report
    }
}

class ExecutionMiddleware(
    private val featureProvider: FeatureProvider
) : CommandMiddleware {
    override suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport {
        val feature = featureProvider.get(command.featureId)
        return feature.execute(command, executionContext, services)
    }
}
