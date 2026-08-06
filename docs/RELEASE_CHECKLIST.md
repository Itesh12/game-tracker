# Platform Master Release Checklist
**System**: Ludo Realm / Game Tracker — Enterprise Command Platform  
**Document Version**: 1.0.0-RELEASE-CHECKLIST  
**Target Release**: Build RC-0.8.2  

---

## 1. Automated Verification Quality Gates
- [x] **JVM Unit Test Suite**: `flutter test` / `./gradlew test` (60/60 Tests Passing).
- [x] **Pipeline Integration Tests**: `PipelineIntegrationTest.kt` PASS.
- [x] **ArchUnit Boundary Enforcement**: `ArchitectureTest.kt` PASS (0 `android.*` imports in domain).
- [x] **Flutter Static Code Analysis**: `flutter analyze` PASS (0 issues).
- [ ] **AndroidX Instrumentation Suite**: `./gradlew connectedAndroidTest`.
- [ ] **Detekt & Ktlint Linter**: `./gradlew detekt ktlintCheck`.
- [ ] **Gradle Vulnerability Scan**: `./gradlew dependencyCheckAnalyze`.
- [ ] **Release Binary Build**: `./gradlew assembleRelease`.

---

## 2. Production Target Hardware & OS Matrix
- [ ] API 26 (Android 8.0) Emulator Test
- [ ] API 31 (Android 12.0) Emulator Test
- [ ] API 34 (Android 14.0) Emulator Test
- [ ] API 35 (Android 15.0) Emulator Test
- [ ] Samsung OneUI Hardware Test
- [ ] Xiaomi HyperOS Hardware Test
- [ ] Pixel Physical Device Test

---

## 3. Real-World Feature Qualification Matrix (RC-0.9 Milestone)

| Lifecycle Scenario | Ping | Remote Screenshot | Still Camera | GPS Location | Upload Engine | WebRTC Stream |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Foreground** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Background FGS** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Screen Locked** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Doze Mode** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Battery Saver** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **LMK Process Death** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Reboot Recovery** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Force Stop** | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout | ⚠️ OS Lockout |
| **API 26–35 Matrix** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Samsung OneUI** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Xiaomi HyperOS** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Oppo ColorOS** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| **Vivo Funtouch** | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

