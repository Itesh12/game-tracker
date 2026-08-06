# Known Android Platform Restrictions & Mitigations
**System**: Ludo Realm / Game Tracker — Enterprise Command Platform  
**Document Version**: 1.0.0-KNOWN-ISSUES  

---

## 1. Documented Platform Limitations & Mitigations

| Feature / System Area | Platform Restriction | Mitigation Strategy | OS Version Target |
| :--- | :--- | :--- | :---: |
| **Remote Screenshot** | User MediaProjection consent token invalidation after process death | Return `BLOCKED_BY_PERMISSION` + `PlatformRestriction.MediaProjectionConsentRequired`; prompt user for re-consent | Android 10+ (API 29+) |
| **Still Camera Capture** | `android.permission.CAMERA` required for frame capture | Check permission in `CapabilityMiddleware`; return `BLOCKED_BY_PERMISSION` | All APIs |
| **GPS Location Ping** | Background location access restricted | Execute via Native Location FGS (`FOREGROUND_SERVICE_TYPE_LOCATION`) | Android 10+ (API 29+) |
| **Live WebRTC Stream** | Background Activity Launch (BAL) restricted | Enforce dual FGS (`MEDIA_PROJECTION` + `CAMERA`) | Android 12+ (API 31+) |
| **Application Force-Stop** | App placed in `FLAG_STOPPED` state | Documented OS limitation; application cannot run work until re-launched by user | All APIs |
