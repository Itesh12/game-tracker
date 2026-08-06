# Changelog
All notable changes to the Ludo Realm / Game Tracker Command Platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [RC-0.8.2] - 2026-08-06

### Added
- **Unified IPC Platform Bridge**: Implemented `CommandPlatformBridge.kt` and `command_platform_service.dart` providing a single `executeCommand(type, payload)` API.
- **Native MethodChannel Registration**: Registered `CommandPlatformBridge` on `com.example.game_tracker/command_platform` in `MainActivity.configureFlutterEngine()`.
- **IPC Test Suite**: Added `command_platform_service_test.dart` validating `PING`, `SCREENSHOT`, `CAMERA`, and `LOCATION` commands over the mock binary messenger (60/60 tests passing).
- **Permanent Repository Documentation**: Established `docs/ARCHITECTURE.md`, `docs/RELEASE_CHECKLIST.md`, and `docs/KNOWN_ISSUES.md`.

---

## [RC-0.8.1] - 2026-08-06

### Added
- **Reference Feature Vertical Slices**: Implemented platform-agnostic `ScreenshotFeature`, `CameraFeature`, `LocationFeature`, `UploadFeature`, and `WebRtcStreamFeature` with 0 lines of lifecycle conditionals.
- **Native FGS Services**: Implemented Android 14+ compliant services (`MediaProjectionService`, `CameraCaptureService`, `LocationService`, `WebRtcStreamService`).
- **WorkManager Upload Engine**: Implemented `UploadWorker` and `UploadControllerImpl` with exponential backoff retries and network constraints.

---

## [RC-0.8.0] - 2026-08-06

### Added
- **Clean Architecture Module Structure**: Established 7-module Gradle project layout (`:module-domain`, `:module-application`, `:module-infrastructure`, `:module-presentation`, `:module-shared`, `:module-testing`, `:app`).
- **Stateless Command Processing Engine**: Implemented `CommandProcessingEngine` with 10-step middleware chain (`Authentication`, `Validation`, `Capability`, `PowerPolicy`, `Persistence`, `ExecutionPolicy`, `HardwareLock`, `Telemetry`, `Audit`, `Execution`).
- **Persistence & Recovery Engine**: Implemented Room DB persistence (`CommandEntity`, `CommandDao`, `RoomCommandRepository`) and repository-driven `RecoveryEngine`.
- **Platform Decision Engine**: Implemented table-driven `ExecutionPolicyResolver`, `DeviceCapabilityProvider`, and `PowerPolicyManager`.
