package com.example.game_tracker.domain.command

import com.example.game_tracker.domain.feature.FeatureExecutionReport
import com.example.game_tracker.domain.model.CommandId

sealed interface CommandResult {
    data class Completed(val report: FeatureExecutionReport) : CommandResult
    data class Queued(val commandId: CommandId, val queuePosition: Int) : CommandResult
    data class RetryScheduled(val commandId: CommandId, val nextAttemptDelayMs: Long) : CommandResult
    data class Rejected(val commandId: CommandId, val reason: String) : CommandResult
    data class BlockedByPlatform(val commandId: CommandId, val restriction: String) : CommandResult
    data class Expired(val commandId: CommandId, val ttlExceededMs: Long) : CommandResult
}
