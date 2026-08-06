package com.example.game_tracker.application.pipeline

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.feature.FeatureExecutionReport
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.pipeline.PipelineContext

interface CommandMiddleware {
    suspend fun process(
        command: DomainCommand,
        pipelineContext: PipelineContext,
        executionContext: ExecutionContext,
        services: FeatureServices,
        next: suspend (DomainCommand, PipelineContext, ExecutionContext, FeatureServices) -> FeatureExecutionReport
    ): FeatureExecutionReport
}
