package com.example.game_tracker.application.queue

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.model.CommandId
import java.util.PriorityQueue

class CommandQueue {

    private val queue = PriorityQueue<DomainCommand>(
        Comparator.comparingInt { cmd -> cmd.metadata.priority.level }
    )

    @Synchronized
    fun enqueue(command: DomainCommand) {
        queue.add(command)
    }

    @Synchronized
    fun poll(): DomainCommand? {
        return queue.poll()
    }

    @Synchronized
    fun peek(): DomainCommand? {
        return queue.peek()
    }

    @Synchronized
    fun size(): Int = queue.size

    @Synchronized
    fun isEmpty(): Boolean = queue.isEmpty()

    @Synchronized
    fun clear() {
        queue.clear()
    }
}
