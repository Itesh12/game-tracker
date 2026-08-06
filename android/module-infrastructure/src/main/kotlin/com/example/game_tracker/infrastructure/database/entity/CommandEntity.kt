package com.example.game_tracker.infrastructure.database.entity

data class CommandEntity(
    val commandId: String,
    val traceId: String,
    val featureId: String,
    val commandType: String,
    val priority: Int,
    val createdAtTimestamp: Long,
    val expiresAtTimestamp: Long,
    val status: String,
    val payloadJson: String
)
