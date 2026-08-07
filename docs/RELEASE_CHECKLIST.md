# Platform Master Release Checklist & Evidence Register
**System**: Ludo Realm / Game Tracker — Enterprise Command Platform  
**Document Version**: 2.0.0-AUDITABLE-RELEASE-CHECKLIST  
**Target Release**: Build RC-0.8.2  
**Audited Date**: 2026-08-07  

---

## 1. Defect Severity & Release Blockers

| Severity Level | Impact & Scope | Release Action |
| :--- | :--- | :---: |
| 🔴 **Critical** | Crash, ANR, Data Loss, Silent Command Loss, Security Issue | **BLOCKS RELEASE** |
| 🟠 **High** | Feature Inoperable, Recovery Failure, Background Service Crash | **BLOCKS RELEASE** |
| 🟡 **Medium** | Minor UI Glitch, Performance Degradation | Conditional Go |
| 🟢 **Low** | Cosmetic Layout Issue, Doc Typo | Non-Blocking |

---

## 2. Automated Verification Quality Gates & Evidence

| Quality Gate | Tool / Verification Command | Status | Evidence Artifact |
| :--- | :--- | :---: | :--- |
| **JVM Unit Test Suite** | `flutter test` / `./gradlew test` | ✅ **PASSED (61/61)** | CI Test Log Artifact |
| **Pipeline Integration Suite** | `PipelineIntegrationTest.kt` | ✅ **PASSED** | CI Test Log Artifact |
| **ArchUnit Boundary Enforcer** | `ArchitectureTest.kt` | ✅ **PASSED** | ArchUnit Compliance Report |
| **Flutter Static Code Analysis** | `flutter analyze --no-fatal-infos` | ✅ **PASSED (0 Issues)** | Static Analysis Artifact |
| **AndroidX Instrumentation Suite** | `./gradlew connectedAndroidTest` | ⏳ **IN PROGRESS** | Android Test Report HTML |
| **Detekt & Ktlint Linter** | `./gradlew detekt ktlintCheck` | ⏳ **IN PROGRESS** | Lint Summary Artifact |
| **Dependency Vulnerability Scan** | `./gradlew dependencyCheckAnalyze` | ⏳ **IN PROGRESS** | OWASP Report Artifact |
| **Release Binary Compilation** | `./gradlew assembleRelease` | ⏳ **PENDING** | APK/AAB (SHA-256 Checksum) |

---

## 3. Real-World Feature Execution Qualification Matrix (RC-0.9 Milestone)

> **Status Key**: ✅ Proven by execution | ❌ Failed (Include stack trace & root cause) | ⚪ Not yet executed

| Lifecycle Scenario | Ping | Remote Screenshot | Still Camera | GPS Location | Upload Engine | WebRTC Stream |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Foreground** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Background FGS** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Screen Locked** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Doze Mode** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Battery Saver** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Airplane Mode** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Network Loss** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **WiFi ↔ Mobile Handoff** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Permission Revocation** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **LMK Process Death** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Reboot Recovery** | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| **Force Stop** | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout |


---

## 4. Release Smoke Test Sequence

- [ ] **Step 1**: Fresh install of release APK on target hardware.
- [ ] **Step 2**: Application launch & user authentication.
- [ ] **Step 3**: Dispatch `PING` command ➔ Verify `PING_PONG_OK`.
- [ ] **Step 4**: Dispatch `SCREENSHOT` command ➔ Verify image generation.
- [ ] **Step 5**: Dispatch `CAMERA` command ➔ Verify frame capture.
- [ ] **Step 6**: Dispatch `LOCATION` command ➔ Verify GPS fix.
- [ ] **Step 7**: Dispatch `UPLOAD` command ➔ Verify Cloudinary URL response.
- [ ] **Step 8**: Dispatch `WEBRTC_STREAM` command ➔ Verify video frame delivery.
- [ ] **Step 9**: Kill app process via `adb shell am kill` ➔ Re-launch app.
- [ ] **Step 10**: Verify `RecoveryEngine` resurrects pending commands.
- [ ] **Step 11**: Reboot physical device ➔ Verify boot recovery.
- [ ] **Step 12**: Uninstall & fresh re-install.

---

## 5. Performance Budget Gates (Targets vs Actuals)

| Performance Metric | Target Budget | Measured Actual | Gate Status | Evidence Artifact |
| :--- | :---: | :---: | :---: | :--- |
| **Ping Command Latency** | < 100 ms | — | ⏳ Pending Profiler | Android Profiler Log |
| **Screenshot Latency** | < 3,000 ms | — | ⏳ Pending Profiler | Latency Log |
| **Camera Capture Latency** | < 2,500 ms | — | ⏳ Pending Profiler | Latency Log |
| **GPS Location Fix Latency** | < 1,500 ms | — | ⏳ Pending Profiler | Latency Log |
| **Upload Retry Window** | < 30 sec | — | ⏳ Pending Profiler | WorkManager Log |
| **Peak Memory Allocation** | < 85 MB | — | ⏳ Pending Profiler | LeakCanary Dump |
| **Battery Drain Rate** | < 1.0% / hr | — | ⏳ Pending Profiler | Battery Historian Dump |

---

## 6. Recommended Engineering Execution Order

1. **AndroidX Instrumentation Testing**: Run `./gradlew connectedAndroidTest` and resolve any native execution or lifecycle failures.
2. **Real Device Qualification**: Test all reference features on physical hardware under Foreground, FGS, Screen Locked, Doze, Battery Saver, LMK, Reboot, and Network handoff.
3. **Runtime Defect Resolution**: Fix any OEM-specific bugs or hardware edge cases uncovered during qualification.
4. **Release Binary Compilation & Validation**: Execute `./gradlew assembleRelease` and verify R8/ProGuard obfuscation rules and release signing.
5. **OEM Compatibility Matrix Sign-off**: Validate release builds on Samsung OneUI, Xiaomi HyperOS, ColorOS, and Pixel devices.
6. **Production Go/No-Go Review**: Review reproducible execution evidence; tag `v1.0` only when all acceptance criteria are satisfied.

---

## 7. Production Rollback Strategy & Contingency

- **Previous Stable Release**: Build `RC-0.8.1`
- **Rollback Procedure**: Revert app binary via Play Store staged rollout halt / rollback APK deployment.
- **Data Migration Compatibility**: Room DB Schema v1 retains backwards compatibility.
- **Recovery Procedure**: Force `RecoveryEngine` db re-sync via cloud configuration toggle.
- **Rollback Owner**: Release Engineering Lead / DevOps Team.

---

---

## 9. Release APK Functional Validation (Blocker #9)

| Functional Validation Gate | Target Execution Status | Evidence Artifact |
| :--- | :---: | :--- |
| **Release Binary Build** | `./gradlew assembleRelease` | Release APK/AAB SHA-256 Checksum |
| **Release Package Install** | `adb install -r release.apk` | Installation Log |
| **Launch & Startup Verification** | Fresh Cold Start | Cold Start Latency Profile |
| **MethodChannel IPC Execution** | IPC Method Calls | Logcat IPC Evidence |
| **Room Database Migration/CRUD** | Persistent Command Log | Room Database Query Log |
| **WorkManager Job Resumption** | Scheduled Upload Worker | WorkManager Logcat Dump |
| **Foreground Service Notifications** | FGS Active Notifications | FGS Notification Log |
| **R8 / ProGuard Obfuscation Audit** | Serialization & Reflection | ProGuard Mapping & Rules |

---

## 10. Release Evidence Pack Index Register

| Blocker ID | Gate Status | Evidence File Path | Execution Notes |
| :--- | :---: | :--- | :--- |
| **Blocker #1** | 🟡 In Progress | `android/app/build/reports/androidTests/connected/index.html` | AndroidX Instrumentation Report |
| **Blocker #2** | 🟡 Partially Verified | `test/command_platform_service_test.dart` | 61 Green Unit/Widget Tests |
| **Blocker #3** | 🟡 Code Reviewed | `android/app/src/main/AndroidManifest.xml` | FGS & Permission Declarations |
| **Blocker #4** | 🟡 Not Executed | `test/stress_test_log.txt` | Concurrent Payload Dispatch Log |
| **Blocker #5** | ⚪ Pending | `android/app/build/outputs/apk/release/app-release.apk` | Release APK Binary |
| **Blocker #6** | ⚪ Pending | `docs/performance_profile_report.txt` | Profiler & Memory Dumps |
| **Blocker #7** | ⚪ Pending | `docs/oem_compatibility_matrix.txt` | Samsung/Xiaomi Hardware Log |
| **Blocker #8** | 🔴 No-Go | `docs/RELEASE_CHECKLIST.md` | Formal Signature Block |
| **Blocker #9** | ⚪ Pending | `docs/release_functional_validation_log.txt` | Release Binary Functional Log |

---

## 11. Official Production Release Sign-off Block

```
====================================================================
PRODUCTION RELEASE SIGN-OFF BLOCK
====================================================================
Target Version:     RC-0.8.2
Build Number:       Build-8201
Git Commit Hash:    [HEAD]
Audit Date:         2026-08-07

Signatures & Approvals:
QA Lead Signature:            ___________________  [ Pending Evidence ]
Android Lead Signature:       ___________________  [ Pending Evidence ]
Release Engineering Signature: ___________________  [ Pending Evidence ]

FINAL DECISION:
[ ] GO  (Ship Release Build)
[X] NO-GO (Execute connectedAndroidTest & Real Device Matrix First)
====================================================================
```

---

> **Golden Release Qualification Rule**: A feature is considered production-ready only when it is implemented, verified by automated tests, validated on supported Android runtime environments, and supported by reproducible execution evidence. Passing unit tests alone is not sufficient for production qualification.

