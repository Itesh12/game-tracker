package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.feature.Feature
import com.example.game_tracker.domain.feature.FeatureProvider
import com.example.game_tracker.domain.model.FeatureId
import java.util.concurrent.ConcurrentHashMap

class SimpleFeatureProvider : FeatureProvider {
    private val features = ConcurrentHashMap<FeatureId, Feature>()

    fun register(feature: Feature) {
        features[feature.featureId] = feature
    }

    override fun get(featureId: FeatureId): Feature {
        return features[featureId]
            ?: throw IllegalArgumentException("No feature registered for ${featureId.value}")
    }
}
