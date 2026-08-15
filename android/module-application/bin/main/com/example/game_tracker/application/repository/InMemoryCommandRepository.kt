package com.example.game_tracker.application.repository

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.repository.CommandRepository
import java.util.concurrent.ConcurrentHashMap

class InMemoryCommandRepository : CommandRepository {
    private val commands = ConcurrentHashMap<CommandId, DomainCommand>()
    private val statuses = ConcurrentHashMap<CommandId, ExecutionResultStatus>()

    override suspend fun saveCommand(command: DomainCommand, status: ExecutionResultStatus) {
        commands[command.metadata.commandId] = command
        statuses[command.metadata.commandId] = status
    }

    override suspend fun getCommand(commandId: CommandId): DomainCommand? {
        return commands[commandId]
    }

    override suspend fun updateStatus(commandId: CommandId, status: ExecutionResultStatus) {
        statuses[commandId] = status
    }

    fun getStatus(commandId: CommandId): ExecutionResultStatus? {
        return statuses[commandId]
    }
}
