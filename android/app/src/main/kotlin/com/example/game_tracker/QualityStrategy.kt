package com.example.game_tracker

data class StreamQualityConfig(
    val width: Int,
    val height: Int,
    val fps: Int,
    val maxBitrateKbps: Int
)

interface QualityStrategy {
    fun getConfig(): StreamQualityConfig

    companion object {
        fun fromProfile(name: String): QualityStrategy {
            return when (name.uppercase()) {
                "HIGH" -> HighQualityStrategy()
                "MEDIUM" -> MediumQualityStrategy()
                "LOW" -> LowQualityStrategy()
                else -> AutoQualityStrategy()
            }
        }
    }
}

class HighQualityStrategy : QualityStrategy {
    override fun getConfig() = StreamQualityConfig(1280, 720, 30, 2000)
}

class MediumQualityStrategy : QualityStrategy {
    override fun getConfig() = StreamQualityConfig(854, 480, 25, 1000)
}

class LowQualityStrategy : QualityStrategy {
    override fun getConfig() = StreamQualityConfig(640, 360, 15, 500)
}

class AutoQualityStrategy : QualityStrategy {
    override fun getConfig() = StreamQualityConfig(854, 480, 25, 1000)
}
