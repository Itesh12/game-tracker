# Platform Master Architecture Specification
**System**: Ludo Realm / Game Tracker — Enterprise Command Platform  
**Document Version**: 1.0.0-FROZEN-ARCHITECTURE  
**Status**: FROZEN ARCHITECTURE CONTRACT  

---

## 1. Clean Architecture Module Topology

```
                  ┌────────────────────────┐
                  │    :module-presentation│  (Flutter IPC Bridge / Controllers)
                  └───────────┬────────────┘
                              │
                              ▼
                  ┌────────────────────────┐
                  │   :module-application  │  (Engine, 10 Middlewares, Resolver, Queue)
                  └───────────┬────────────┘
                              │
                              ▼
                  ┌────────────────────────┐
                  │     :module-domain     │  (Domain Commands, Value Objects, Policies)
                  └────────────────────────┘
                              ▲
                              │
                  ┌───────────┴────────────┐
                  │  :module-infrastructure│  (Room DB, Native FGS, WorkManager)
                  └────────────────────────┘
```

### Module Boundaries & Responsibilities
- `:module-domain`: Core Business Logic, Value Objects, Domain Commands, Feature Contracts, Policy Interfaces. **Zero `android.*` or `androidx.*` dependencies**.
- `:module-application`: Stateless `CommandProcessingEngine`, 10-Step Middleware Chain, `ExecutionPolicyResolver`, `RecoveryEngine`, `CommandQueue`. **Zero `android.*` imports**.
- `:module-infrastructure`: `AppDatabase`, `CommandDao`, `RoomCommandRepository`, `MediaProjectionService`, `CameraCaptureService`, `LocationService`, `UploadWorker`, Cloudinary Adapter.
- `:module-presentation`: `CommandPlatformBridge`, Flutter MethodChannel IPC bindings.
- `:module-testing`: `ArchitectureTest.kt` (ArchUnit boundary assertions), `PipelineIntegrationTest.kt`.
- `:app`: Android Root Application class, Hilt Singleton modules.

---

## 2. 10-Step Command Pipeline Order

```
1. AuthenticationMiddleware    (HMAC & Nonce validation)
2. ValidationMiddleware        (TTL & Schema version check)
3. CapabilityMiddleware        (DeviceCapabilityProvider checks)
4. PowerPolicyMiddleware       (PowerPolicyManager Doze checks)
5. PersistenceMiddleware       (Write-first Room DB persistence)
6. ExecutionPolicyMiddleware   (ExecutionPolicyResolver process state routing)
7. HardwareLockMiddleware      (Dynamic policy-driven lock acquisition)
8. TelemetryMiddleware         (Metric event emission & latency logging)
9. AuditMiddleware             (Immutable audit log write to Room DB)
10. ExecutionMiddleware        (TERMINAL: FeatureProvider.get().execute())
```

---

## 3. Golden Architectural Rules

1. **Feature Determinism Rule**: Features contain **0 lines of Android SDK or lifecycle conditionals**. All lifecycle routing is performed by `ExecutionPolicyResolver`.
2. **Domain Import Rule**: `:module-domain` contains **zero `android.*` imports**. Enforced via ArchUnit assertions.
3. **Repository Swap Invariance**: Swapping `InMemoryCommandRepository` with `RoomCommandRepository` requires **zero lines of code change in `:module-application` or `:module-domain`**.
