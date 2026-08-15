package com.example.game_tracker.domain.repository

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.ExecutionResultStatus

interface CommandRepository {
    suspend fun saveCommand(command: DomainCommand, status: ExecutionResultStatus)
    suspend fun getCommand(commandId: CommandId): DomainCommand?
    suspend fun updateStatus(commandId: CommandId, status: ExecutionResultStatus)
}
