package com.example.game_tracker.application.queue

import com.example.game_tracker.domain.command.CommandMetadata
import com.example.game_tracker.domain.command.PingCommand
import com.example.game_tracker.domain.model.*
import org.junit.Assert.*
import org.junit.Test

class CommandQueueTest {

    private fun createPingCommand(id: String, priority: CommandPriority): PingCommand {
        return PingCommand(
            metadata = CommandMetadata(
                commandId = CommandId(id),
                traceId = TraceId("trace_$id"),
                expiresAtTimestamp = System.currentTimeMillis() + 60000L,
                origin = CommandSource.ADMIN_UI,
                priority = priority
            ),
            echoMessage = id
        )
    }

    @Test
    fun commandQueue_ordersCommandsByPriority() {
        val queue = CommandQueue()

        val lowCmd = createPingCommand("cmd_low", CommandPriority.LOW)
        val normalCmd = createPingCommand("cmd_normal", CommandPriority.NORMAL)
        val highCmd1 = createPingCommand("cmd_high_1", CommandPriority.HIGH)
        val highCmd2 = createPingCommand("cmd_high_2", CommandPriority.HIGH)
        val bgCmd = createPingCommand("cmd_bg", CommandPriority.BACKGROUND)

        // Enqueue out of order: LOW, NORMAL, HIGH1, HIGH2, BACKGROUND
        queue.enqueue(lowCmd)
        queue.enqueue(normalCmd)
        queue.enqueue(highCmd1)
        queue.enqueue(highCmd2)
        queue.enqueue(bgCmd)

        assertEquals(5, queue.size())

        // Poll & Assert priority order: HIGH1, HIGH2, NORMAL, LOW, BACKGROUND
        assertEquals("cmd_high_1", queue.poll()?.metadata?.commandId?.value)
        assertEquals("cmd_high_2", queue.poll()?.metadata?.commandId?.value)
        assertEquals("cmd_normal", queue.poll()?.metadata?.commandId?.value)
        assertEquals("cmd_low", queue.poll()?.metadata?.commandId?.value)
        assertEquals("cmd_bg", queue.poll()?.metadata?.commandId?.value)
        assertTrue(queue.isEmpty())
    }
}
