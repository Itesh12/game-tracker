package com.example.game_tracker.application.engine

import com.example.game_tracker.domain.command.CommandResult
import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.domain.pipeline.PipelineContext
import com.example.game_tracker.domain.repository.CommandRepository

class RecoveryEngine(
    private val commandRepository: CommandRepository,
    private val commandProcessingEngine: CommandProcessingEngine
) {

    suspend fun recoverPendingCommands(
        pendingCommands: List<DomainCommand>,
        services: FeatureServices
    ): List<CommandResult> {
        val results = mutableListOf<CommandResult>()

        for (command in pendingCommands) {
            val pipelineContext = PipelineContext(
                traceId = command.metadata.traceId,
                commandId = command.metadata.commandId,
                retryAttempt = command.metadata.attempt + 1
            )

            val executionContext = ExecutionContext(
                processState = ProcessState.RESTORED,
                platformCondition = PlatformCondition.NORMAL,
                executor = ExecutorType.FLUTTER,
                networkAvailable = true,
                batteryOptimized = false,
                restoredFromProcessDeath = true,
                source = command.metadata.origin
            )

            val result = commandProcessingEngine.processCommand(
                command,
                pipelineContext,
                executionContext,
                services
            )

            if (result is CommandResult.Completed) {
                commandRepository.updateStatus(command.metadata.commandId, ExecutionResultStatus.SUCCESS)
            }

            results.add(result)
        }

        return results
    }
}
