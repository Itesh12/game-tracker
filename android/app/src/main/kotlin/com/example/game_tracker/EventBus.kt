package com.example.game_tracker

import java.util.concurrent.CopyOnWriteArrayList

class EventBus {
    private val listeners = CopyOnWriteArrayList<(SessionEvent) -> Unit>()

    fun subscribe(listener: (SessionEvent) -> Unit) {
        listeners.add(listener)
    }

    fun unsubscribe(listener: (SessionEvent) -> Unit) {
        listeners.remove(listener)
    }

    fun post(event: SessionEvent) {
        for (listener in listeners) {
            try {
                listener(event)
            } catch (e: Exception) {
                AppLogger.e("EventBus error handling event: ${event.javaClass.simpleName}", e)
            }
        }
    }
}
