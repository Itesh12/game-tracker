package com.example.game_tracker.domain.command

import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.SessionId
import com.example.game_tracker.domain.model.TraceId

data class TraceContext(
    val traceId: TraceId,
    val requestId: String,
    val sessionId: SessionId,
    val parentCommandId: CommandId? = null
)
