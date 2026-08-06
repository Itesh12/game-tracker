package com.example.game_tracker.features

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.game_tracker.application.feature.PingFeature
import com.example.game_tracker.domain.command.CommandId
import com.example.game_tracker.domain.command.CommandMetadata
import com.example.game_tracker.domain.command.CommandSource
import com.example.game_tracker.domain.command.PingCommand
import com.example.game_tracker.domain.command.TraceId
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.CommandStatus
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class PingInstrumentationTest {

    @Test
    fun executePingFeatureOnDeviceRuntime() = runBlocking {
        val pingFeature = PingFeature()
        val commandId = CommandId("cmd_ping_${UUID.randomUUID()}")
        val traceId = TraceId("trace_ping_${UUID.randomUUID()}")
        val metadata = CommandMetadata(
            commandId = commandId,
            traceId = traceId,
            expiresAtTimestamp = System.currentTimeMillis() + 60000L,
            origin = CommandSource.ADMIN_UI
        )

        val pingCommand = PingCommand(metadata, echoMessage = "DEVICE_PING_FEAT")

        val systemServices = FeatureServices(
            logger = object : FeatureLogger {
                override fun d(tag: String, message: String) {}
                override fun e(tag: String, message: String, throwable: Throwable?) {}
            },
            clock = object : SystemClock {
                override fun currentTimeMillis(): Long = System.currentTimeMillis()
            }
        )

        val result = pingFeature.execute(pingCommand, systemServices)
        assertEquals(CommandStatus.SUCCESS, result.status)
        assertEquals(commandId, result.commandId)
    }
}
