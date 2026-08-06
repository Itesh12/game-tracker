package com.example.game_tracker.infrastructure.database.repository

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.model.CommandId
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.repository.CommandRepository
import com.example.game_tracker.infrastructure.database.dao.CommandDao
import com.example.game_tracker.infrastructure.database.mapper.CommandEntityMapper

class RoomCommandRepository(
    private val commandDao: CommandDao
) : CommandRepository {

    override suspend fun saveCommand(command: DomainCommand, status: ExecutionResultStatus) {
        val entity = CommandEntityMapper.toEntity(command, status)
        commandDao.insertOrUpdate(entity)
    }

    override suspend fun getCommand(commandId: CommandId): DomainCommand? {
        val entity = commandDao.getCommandById(commandId.value) ?: return null
        return CommandEntityMapper.toDomain(entity)
    }

    override suspend fun updateStatus(commandId: CommandId, status: ExecutionResultStatus) {
        commandDao.updateStatus(commandId.value, status.name)
    }

    suspend fun getCommandsByStatus(statuses: List<ExecutionResultStatus>): List<DomainCommand> {
        val statusStrings = statuses.map { it.name }
        val entities = commandDao.getCommandsByStatus(statusStrings)
        return entities.map { CommandEntityMapper.toDomain(it) }
    }
}
