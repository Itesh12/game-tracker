package com.example.game_tracker

import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean

class SessionCoordinator(
    val eventBus: EventBus = EventBus(),
    var signalingTransport: SignalingTransport? = null
) {
    private var currentState: SessionState = SessionState.Idle
    private val commandQueue = ConcurrentLinkedQueue<SessionCommand>()
    private val isProcessing = AtomicBoolean(false)
    private var currentSessionId: String? = null

    init {
        eventBus.subscribe { event ->
            handleSessionEvent(event)
        }
    }

    fun getState(): SessionState = currentState

    fun enqueueCommand(command: SessionCommand) {
        commandQueue.add(command)
        processQueue()
    }

    private fun processQueue() {
        if (!isProcessing.compareAndSet(false, true)) return

        try {
            while (!commandQueue.isEmpty()) {
                val command = commandQueue.poll() ?: break
                executeCommand(command)
            }
        } finally {
            isProcessing.set(false)
        }
    }

    private fun executeCommand(command: SessionCommand) {
        AppLogger.i("Executing command: ${command.javaClass.simpleName} in state: ${currentState.name}")
        when (command) {
            is SessionCommand.StartStream -> {
                if (currentState is SessionState.Idle || currentState is SessionState.Stopped || currentState is SessionState.Failed) {
                    currentSessionId = command.sessionId
                    transitionTo(SessionState.Starting)
                    signalingTransport?.updateState(command.sessionId, "STARTING", mapOf(
                        "schemaVersion" to 1,
                        "protocolVersion" to 2,
                        "signalingVersion" to 1,
                        "sdkVersion" to "1.0.0"
                    ))
                }
            }
            SessionCommand.PauseStream -> {
                if (currentState is SessionState.Streaming) {
                    transitionTo(SessionState.Interrupted)
                }
            }
            SessionCommand.ResumeStream -> {
                if (currentState is SessionState.Interrupted) {
                    transitionTo(SessionState.Streaming)
                }
            }
            SessionCommand.RestartIce -> {
                if (currentState is SessionState.Streaming || currentState is SessionState.IceConnected) {
                    transitionTo(SessionState.Reconnecting(1))
                    eventBus.post(SessionEvent.RestartRequested)
                }
            }
            SessionCommand.StopStream -> {
                if (currentState !is SessionState.Idle && currentState !is SessionState.Stopped) {
                    transitionTo(SessionState.Stopping)
                    currentSessionId?.let { sid ->
                        signalingTransport?.updateState(sid, "STOPPED")
                    }
                    transitionTo(SessionState.Stopped)
                }
            }
            SessionCommand.Cleanup -> {
                transitionTo(SessionState.Idle)
                currentSessionId = null
            }
        }
    }

    private fun handleSessionEvent(event: SessionEvent) {
        AppLogger.d("SessionCoordinator received event: ${event.javaClass.simpleName}")
        when (event) {
            is SessionEvent.OfferCreated -> {
                transitionTo(SessionState.OfferCreated)
                currentSessionId?.let { sid ->
                    signalingTransport?.sendOffer(sid, event.sdp, event.type)
                    signalingTransport?.updateState(sid, "OFFER_CREATED")
                }
            }
            is SessionEvent.AnswerReceived -> {
                transitionTo(SessionState.AnswerReceived)
            }
            SessionEvent.IceConnected -> {
                transitionTo(SessionState.Streaming)
                currentSessionId?.let { sid ->
                    signalingTransport?.updateState(sid, "STREAMING")
                }
            }
            SessionEvent.IceDisconnected -> {
                transitionTo(SessionState.Interrupted)
            }
            is SessionEvent.StreamInterrupted -> {
                transitionTo(SessionState.Interrupted)
            }
            SessionEvent.StreamStopped -> {
                transitionTo(SessionState.Stopped)
            }
            is SessionEvent.ErrorOccurred -> {
                transitionTo(SessionState.Failed(event.message))
                currentSessionId?.let { sid ->
                    signalingTransport?.updateState(sid, "FAILED", mapOf("error" to event.message))
                }
            }
            else -> {}
        }
    }

    private fun transitionTo(newState: SessionState) {
        if (currentState == newState) return
        AppLogger.i("State transition: ${currentState.name} -> ${newState.name}")
        currentState = newState
    }
}
