package com.example.game_tracker.infrastructure.database.dao

import com.example.game_tracker.infrastructure.database.entity.CommandEntity

interface CommandDao {
    suspend fun insertOrUpdate(command: CommandEntity)
    suspend fun getCommandById(commandId: String): CommandEntity?
    suspend fun getCommandsByStatus(statuses: List<String>): List<CommandEntity>
    suspend fun updateStatus(commandId: String, status: String)
    suspend fun deleteCommand(commandId: String)
}
