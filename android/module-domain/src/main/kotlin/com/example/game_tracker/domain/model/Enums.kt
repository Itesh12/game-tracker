package com.example.game_tracker.domain.model

enum class ProcessState {
    FOREGROUND,
    BACKGROUND,
    RESTORED,
    PROCESS_DEAD
}

enum class PlatformCondition {
    NORMAL,
    FORCE_STOPPED
}

enum class ExecutorType {
    FLUTTER,
    FOREGROUND_SERVICE,
    WORK_MANAGER,
    BOOT_RECEIVER,
    FCM_SERVICE
}

enum class CommandSource {
    FCM_PUSH,
    FIRESTORE_SYNC,
    ADMIN_UI,
    LOCAL_SCHEDULER,
    BOOT_EVENT
}

enum class CommandPriority(val level: Int) {
    HIGH(1),
    NORMAL(2),
    LOW(3),
    BACKGROUND(4)
}

enum class ExecutionResultStatus {
    SUCCESS,
    FAILED,
    RETRY,
    QUEUED,
    BLOCKED_BY_OS,
    BLOCKED_BY_PERMISSION,
    EXPIRED
}

enum class FailureCategory {
    PERMISSION_DENIED,
    DEVICE_UNSUPPORTED,
    NETWORK_UNAVAILABLE,
    HARDWARE_BUSY,
    AUTHENTICATION_FAILED,
    COMMAND_EXPIRED,
    SECURITY_VIOLATION,
    INTERNAL_ERROR
}
