package com.example.game_tracker.application.engine

import com.example.game_tracker.application.pipeline.CommandMiddleware
import com.example.game_tracker.domain.command.CommandResult
import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.FeatureExecutionReport
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.pipeline.PipelineContext

class CommandProcessingEngine(
    private val middlewarePipeline: List<CommandMiddleware>
) {
    suspend fun processCommand(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices
    ): CommandResult {
        return try {
            val report = executePipeline(0, command, pipelineContext, executionContext, services)
            CommandResult.Completed(report)
        } catch (e: Exception) {
            CommandResult.Rejected(command.metadata.commandId, e.message ?: "Unknown error")
        }
    }

    private suspend fun executePipeline(
        index: Int,
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport {
        if (index >= middlewarePipeline.size) {
            throw IllegalStateException("Pipeline terminated without invoking ExecutionMiddleware")
        }
        return middlewarePipeline[index].process(command, pipelineContext, executionContext, services) { nextCmd, nextPipeCtx, nextExecCtx, nextSvc ->
            executePipeline(index + 1, nextCmd, nextPipeCtx, nextExecCtx, nextSvc)
        }
    }
}
