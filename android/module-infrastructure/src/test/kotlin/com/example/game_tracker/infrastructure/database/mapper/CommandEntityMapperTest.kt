package com.example.game_tracker.infrastructure.database.mapper

import com.example.game_tracker.domain.command.CommandMetadata
import com.example.game_tracker.domain.command.PingCommand
import com.example.game_tracker.domain.model.*
import org.junit.Assert.*
import org.junit.Test

class CommandEntityMapperTest {

    @Test
    fun roundTrip_domainToEntityToDomain_preservesAllMetadata() {
        val commandId = CommandId("cmd_mapper_001")
        val traceId = TraceId("trace_mapper_001")
        val createdAt = System.currentTimeMillis()
        val expiresAt = createdAt + 60000L

        val originalCommand = PingCommand(
            metadata = CommandMetadata(
                commandId = commandId,
                traceId = traceId,
                createdAtTimestamp = createdAt,
                expiresAtTimestamp = expiresAt,
                origin = CommandSource.ADMIN_UI,
                priority = CommandPriority.HIGH
            ),
            echoMessage = "ROUND_TRIP_TEST"
        )

        // Map Domain -> Entity
        val entity = CommandEntityMapper.toEntity(originalCommand, ExecutionResultStatus.QUEUED)
        assertEquals(commandId.value, entity.commandId)
        assertEquals(traceId.value, entity.traceId)
        assertEquals("QUEUED", entity.status)
        assertEquals(CommandPriority.HIGH.level, entity.priority)
        assertEquals("ROUND_TRIP_TEST", entity.payloadJson)

        // Map Entity -> Domain
        val restoredCommand = CommandEntityMapper.toDomain(entity) as PingCommand
        assertEquals(commandId, restoredCommand.metadata.commandId)
        assertEquals(traceId, restoredCommand.metadata.traceId)
        assertEquals(createdAt, restoredCommand.metadata.createdAtTimestamp)
        assertEquals(expiresAt, restoredCommand.metadata.expiresAtTimestamp)
        assertEquals(CommandPriority.HIGH, restoredCommand.metadata.priority)
        assertEquals("ROUND_TRIP_TEST", restoredCommand.echoMessage)
    }
}
