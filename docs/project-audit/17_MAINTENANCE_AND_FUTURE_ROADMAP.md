# 17 — Maintenance & Future Technical Roadmap

This document outlines ongoing operational maintenance procedures and the prioritized future technical roadmap for **Cotton Guard**.

---

## 1. Routine Operational Maintenance

### 1. Database Indexing & Connection Pool Health
- **Neon PostgreSQL**: Verify connection pool settings in `DATABASE_URL`. Ensure client connections close promptly using context managers to avoid exhausting the 20-connection pool limit on free tiers.
- **SQLite (Development)**: SQLite runs with Write-Ahead Logging (`PRAGMA journal_mode=WAL;`). Periodically execute `PRAGMA wal_checkpoint(TRUNCATE);` if local file size expands.

### 2. Audit Trail Retention
- The `service_audit_logs` table logs administrative start/stop actions.
- Schedule a quarterly maintenance query to archive records older than 90 days:
  ```sql
  DELETE FROM service_audit_logs WHERE timestamp < date('now', '-90 days');
  ```

### 3. Cloud Quota & Resource Monitoring
- **Render.com**: Monitor free-tier usage (750 free instance hours per month). Ensure only one free web service instance is active per account to prevent mid-month suspensions.
- **Neon Serverless**: Monitor database disk usage against the 0.5 GB free limit. The current schema consumes $< 5$ MB.

---

## 2. Prioritized Future Technical Roadmap

```
Phase 1: Security & Identity ──► Phase 2: On-Device Edge AI ──► Phase 3: Vernacular UI
             │                                                          │
             ▼                                                          ▼
Phase 4: Field-Scale Drone Vision ◄── Phase 5: Regional Pest Alerts ◄──┘
```

---

### Priority 1: Google OAuth SHA-1 Registration (Immediate)
- **Objective**: Complete Google Sign-In setup for Android devices.
- **Scope**: Extract debug and release keystore SHA-1 fingerprints and register them in Google Cloud Console under package `com.cottonguard.app.cottonguard`.
- **Target Subsystem**: [`lib/services/google_auth_service.dart`](file:///E:/project/kushi/lib/services/google_auth_service.dart)

---

### Priority 2: On-Device Edge AI Inference (Near-Term)
- **Objective**: Enable 100% offline scanning in rural fields with zero cellular connectivity.
- **Implementation Strategy**:
  1. Quantize `cotton_guard_model.onnx` to INT8 or convert to TensorFlow Lite (`.tflite` with dynamic range quantization).
  2. Integrate `tflite_flutter` or `onnxruntime_flutter` into the Flutter client.
  3. Bundle the 5.4M-parameter model (~5 MB quantized) directly within the APK assets.
  4. Implement an automatic connectivity fallback: run on-device inference when offline; use cloud backend when connected.

---

### Priority 3: Multilingual Vernacular Localization (Near-Term)
- **Objective**: Expand accessibility for smallholder farmers across India's primary cotton belts.
- **Languages to Support**:
  - **Telugu** (Telangana & Andhra Pradesh)
  - **Marathi** (Vidarbha & Marathwada, Maharashtra)
  - **Gujarati** (Saurashtra & Central Gujarat)
  - **Hindi** (North & Central India)
  - **Punjabi** (Northern Cotton Zone)
- **Implementation Strategy**: Use Flutter's `intl` and `.arb` localization files to translate disease names, symptoms, and spray instructions.

---

### Priority 4: Push Notifications & Regional Pest Outbreak Alerts (Mid-Term)
- **Objective**: Provide proactive early warnings when neighboring farms report contagious infestations.
- **Implementation Strategy**:
  1. Aggregate anonymized scan coordinates by district.
  2. If reports of `Cotton Leaf Curl Virus` or `Leaf Hopper / Jassids` in a district increase by $\ge 30\%$ within 72 hours, broadcast a regional alert to farmers in adjacent districts advising prophylactic yellow sticky trap deployment.

---

### Priority 5: Field-Scale Multi-Leaf & Drone Vision (Long-Term)
- **Objective**: Detect disease patches across whole cotton canopies using aerial or tractor-mounted cameras.
- **Implementation Strategy**: Train a YOLOv8-Cotton or RT-DETR object detector to localize individual leaf lesions and estimate field-wide defoliation percentages.
