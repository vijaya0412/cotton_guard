# 13 — Known Issues, Limitations & Technical Debt

This document catalogs all identified limitations, edge cases, external configuration prerequisites, and technical debt in **Cotton Guard**.

---

## 1. Prioritized Issue & Limitation Matrix

| Severity | Issue Summary | Subsystem | Impact | Recommended Resolution |
| :---: | :--- | :--- | :--- | :--- |
| **HIGH** | Google Sign-In SHA-1 Registration Required on Android | Flutter Mobile Client | Google Sign-In throws `ApiException 10` on devices if SHA-1 is unregistered. | Register debug/release keystore SHA-1 fingerprint in Google Cloud Console. |
| **MEDIUM** | Free-Tier Cloud Container Cold Starts (30–50s) | Cloud Deployment (Render) | First diagnostic request after 15m idle experiences latency. | Mitigated by 45s client timeout; permanent fix requires always-on hosting. |
| **MEDIUM** | Ephemeral SQLite Risk on Ephemeral Container Hosts | Database Layer | If `DATABASE_URL` is omitted, user accounts are lost on container restart. | Ensure `DATABASE_URL` (Neon PostgreSQL) is configured in cloud production. |
| **MEDIUM** | Leaf Hopper / Jassids Recall vs Other Conditions | ML Model | Subtle initial nymph feeding symptoms can be misclassified as early blight. | Expand training collection of early-stage jassid hopper burn images. |
| **LOW** | 512 MB Free-Tier Memory Headroom under Concurrent Load | Cloud Deployment (Render) | Multiple simultaneous 15 MB uploads could pressure 512 MB RAM limit. | Rate-limit concurrent inference requests; scale to dedicated 1 GB+ RAM host. |
| **LOW** | On-Device Offline Neural Inference Not Yet Bundled | Flutter Mobile Client | Mobile scanning requires network connectivity to the backend API. | Port ONNX model to TFLite / ONNX Runtime Mobile for on-device inference. |

---

## 2. In-Depth Technical Analysis

### Issue 1: Google Sign-In SHA-1 Fingerprint Prerequisite (High Severity)
- **Root Cause**: The Flutter app integrates `google_sign_in` using the Web Client ID (`647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com`). However, Android enforces that Google Play Services verify the SHA-1 fingerprint of the signing key against the Android OAuth client registered in Google Cloud Console for package `com.cottonguard.app.cottonguard`.
- **Observed Behavior**: Without this registration, tapping "Continue with Google" throws `ApiException 10 (DEVELOPER_ERROR)`.
- **Resolution Steps**:
  1. Extract the SHA-1 fingerprint of your Android debug keystore:
     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
  2. In Google Cloud Console $\rightarrow$ **APIs & Services** $\rightarrow$ **Credentials**, create an **Android Client ID**.
  3. Enter Package Name: `com.cottonguard.app.cottonguard` and paste the SHA-1 fingerprint.
  4. For release APKs, extract and register the release keystore fingerprint similarly.

---

### Issue 2: Free-Tier Cloud Cold Starts (Medium Severity)
- **Root Cause**: Render.com free web services spin down after 15 minutes of inactivity. When a farmer submits an image after an idle period, the container spins up from cold storage, taking 30 to 50 seconds.
- **Implemented Mitigation**:
  - In [`ApiConstants.dart`](file:///E:/project/kushi/lib/constants/api_constants.dart#L41), `connectTimeout` was increased to **45 seconds**.
  - In [`ImagePreviewScreen.dart`](file:///E:/project/kushi/lib/screens/scan/image_preview_screen.dart), if a timeout occurs, the user's selected leaf image is preserved in memory, allowing an immediate one-tap retry without re-capturing the photo.

---

### Issue 3: Ephemeral SQLite Persistence Risk (Medium Severity)
- **Root Cause**: In containerized environments without a persistent volume mount, SQLite writes to an ephemeral container filesystem (`/var/data/advisory.db`). When the container restarts or redeploys, this file is reset.
- **Implemented Resolution**:
  - A dual-engine persistence layer was created in [`database.py`](file:///E:/project/kushi/backend/database.py#L50-L160).
  - When `DATABASE_URL` is set to an external PostgreSQL instance (such as free-tier Neon Serverless PostgreSQL), all user registrations, session tokens, and audit logs persist permanently across container restarts.

---

### Issue 4: Leaf Hopper / Jassids Minority Class Recall (Medium Severity)
- **Root Cause**: On the 322 authentic holdout test images, `Leaf Hopper / Jassids` achieved 92.0% precision, but recall was **67.6%** (23 / 34 identified correctly). Misclassifications occurred primarily as `Cotton Leaf Curl Virus` (5 images) and `Healthy Leaf` (2 images) due to subtle early-stage edge curling before hopper burn necrosis sets in.
- **Implemented Safeguard**:
  - [`CottonDomainGate.evaluate_prediction_uncertainty()`](file:///E:/project/kushi/ml/cotton_gate.py#L224) detects when class probabilities are close ($< 0.12$ margin), triggering an agronomic uncertainty warning that suppresses chemical pesticides and advises in-person extension officer verification.
