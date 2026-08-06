package com.example.game_tracker.infrastructure.database.mapper

import com.example.game_tracker.domain.command.CommandMetadata
import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.PingCommand
import com.example.game_tracker.domain.model.*
import com.example.game_tracker.infrastructure.database.entity.CommandEntity

object CommandEntityMapper {

    fun toEntity(command: DomainCommand, status: ExecutionResultStatus): CommandEntity {
        val echoMsg = if (command is PingCommand) command.echoMessage else ""
        return CommandEntity(
            commandId = command.metadata.commandId.value,
            traceId = command.metadata.traceId.value,
            featureId = command.featureId.value,
            commandType = command::class.java.simpleName,
            priority = command.metadata.priority.level,
            createdAtTimestamp = command.metadata.createdAtTimestamp,
            expiresAtTimestamp = command.metadata.expiresAtTimestamp,
            status = status.name,
            payloadJson = echoMsg
        )
    }

    fun toDomain(entity: CommandEntity): DomainCommand {
        val metadata = CommandMetadata(
            commandId = CommandId(entity.commandId),
            traceId = TraceId(entity.traceId),
            createdAtTimestamp = entity.createdAtTimestamp,
            expiresAtTimestamp = entity.expiresAtTimestamp,
            origin = CommandSource.ADMIN_UI,
            priority = when (entity.priority) {
                1 -> CommandPriority.HIGH
                2 -> CommandPriority.NORMAL
                3 -> CommandPriority.LOW
                else -> CommandPriority.BACKGROUND
            }
        )

        return when (entity.featureId) {
            "FEATURE_PING" -> PingCommand(metadata = metadata, echoMessage = entity.payloadJson.ifEmpty { "PING" })
            else -> PingCommand(metadata = metadata, echoMessage = "RESTORED")
        }
    }
}
