package com.example.game_tracker.smoke

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppLaunchSmokeTest {

    @Test
    fun verifyApplicationContextLaunch() {
        val targetContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertNotNull("Target ApplicationContext must not be null", targetContext)
        assertNotNull("Application PackageName must be valid", targetContext.packageName)
    }
}
