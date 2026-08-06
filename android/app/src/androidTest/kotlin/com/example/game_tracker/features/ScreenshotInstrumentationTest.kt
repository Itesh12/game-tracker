package com.example.game_tracker.features

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.game_tracker.application.feature.ScreenshotFeature
import com.example.game_tracker.domain.command.*
import com.example.game_tracker.domain.feature.FeatureLogger
import com.example.game_tracker.domain.feature.FeatureServices
import com.example.game_tracker.domain.feature.SystemClock
import com.example.game_tracker.domain.model.CommandStatus
import com.example.game_tracker.infrastructure.controller.FakeMediaProjectionController
import com.example.game_tracker.infrastructure.controller.FakeUploadController
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class ScreenshotInstrumentationTest {

    @Test
    fun executeScreenshotFeatureOnDeviceRuntime() = runBlocking {
        val fakeMediaController = FakeMediaProjectionController(hasConsent = true)
        val fakeUploadController = FakeUploadController()
        val screenshotFeature = ScreenshotFeature(fakeMediaController, fakeUploadController)

        val commandId = CommandId("cmd_shot_${UUID.randomUUID()}")
        val traceId = TraceId("trace_shot_${UUID.randomUUID()}")
        val metadata = CommandMetadata(
            commandId = commandId,
            traceId = traceId,
            expiresAtTimestamp = System.currentTimeMillis() + 60000L,
            origin = CommandSource.ADMIN_UI
        )

        val command = ScreenshotCommand(metadata, quality = 80)
        val systemServices = FeatureServices(
            logger = object : FeatureLogger {
                override fun d(tag: String, message: String) {}
                override fun e(tag: String, message: String, throwable: Throwable?) {}
            },
            clock = object : SystemClock {
                override fun currentTimeMillis(): Long = System.currentTimeMillis()
            }
        )

        val result = screenshotFeature.execute(command, systemServices)
        assertEquals(CommandStatus.SUCCESS, result.status)
        assertEquals(commandId, result.commandId)
    }
}
