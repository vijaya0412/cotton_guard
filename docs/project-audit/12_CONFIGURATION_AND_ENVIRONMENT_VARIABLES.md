# 12 — Configuration & Environment Variables

This document provides a sanitized configuration reference for all environment variables, compile-time flags, and platform settings across the **Cotton Guard** backend and Flutter mobile client.

> [!NOTE]
> All credentials shown below are strictly sanitized placeholders. Real production credentials must never be committed to Git.

---

## 1. Backend Environment Variables Reference

The backend loads configuration from system environment variables and local `.env` files via `python-dotenv`:

| Variable Name | Required in Prod? | Default Value (Dev) | Description & Constraints |
| :--- | :---: | :--- | :--- |
| `ENVIRONMENT` | Recommended | `development` | Operating mode: `production` or `development`. When set to `production`, enforces strict secret key validation. |
| `PORT` | Required (Cloud) | `7860` | Network port for Uvicorn server binding. 7860 is required for Hugging Face Spaces and Render container ingress. |
| `HOST` | Optional | `0.0.0.0` | IP binding address. `0.0.0.0` allows connections from emulators, LAN, and cloud ingress. |
| `DATABASE_URL` | **Required (Cloud)** | *None (Unset)* | External PostgreSQL connection string. Enables persistent cloud storage. If unset, falls back to SQLite. |
| `SQLITE_DB_PATH` | Optional | `backend/advisory.db` | Local SQLite database file path. Set to `/var/data/advisory.db` inside Docker. |
| `ONNX_MODEL_PATH` | Optional | `ml/models/cotton_guard_model.onnx` | Absolute or relative filesystem path to the production ONNX neural network model. |
| `COTTON_GUARD_SECRET_KEY` | **Required (Prod)** | *Ephemeral random token* | Cryptographic signing secret for HMAC-SHA256 session tokens. In production, must be $\ge 32$ characters. |
| `ADMIN_EMAIL` | Optional | *None (Unset)* | Email address of the designated system administrator for RBAC verification. |
| `ADMIN_INITIAL_PASSWORD` | Optional | *None (Unset)* | Initial password used during first-time administrator auto-provisioning. |
| `ADMIN_API_KEY` | Optional | *None (Unset)* | Pre-shared administrative secret token accepted via the `X-Admin-Key` request header. |
| `GOOGLE_CLIENT_ID` | Optional | *None (Unset)* | Google OAuth 2.0 Web Client ID used by the backend to verify the `aud` claim in incoming ID tokens. |
| `MAX_UPLOAD_SIZE_MB` | Optional | `15` | Maximum allowable image upload payload size in megabytes. |

---

## 2. Sanitized `.env.example` Template

Use this template to create your production or local `.env` file:

```bash
# ==============================================================================
# Cotton Guard Backend Configuration Template (.env.example)
# ==============================================================================

# 1. Environment & Server Networking
ENVIRONMENT=production
HOST=0.0.0.0
PORT=7860

# 2. Database Persistence
# For Production: Connect to Neon PostgreSQL (Serverless)
DATABASE_URL=postgresql://USER:PASSWORD@ep-sample-pool.neon.tech/neondb?sslmode=require

# For Local Development / Ephemeral Mode (Leave DATABASE_URL commented out):
# SQLITE_DB_PATH=backend/advisory.db

# 3. Model & Inference Path
ONNX_MODEL_PATH=ml/models/cotton_guard_model.onnx
MAX_UPLOAD_SIZE_MB=15

# 4. Cryptographic Secrets (Min 32 random characters for production)
# Generate via: python -c "import secrets; print(secrets.token_hex(32))"
COTTON_GUARD_SECRET_KEY=replace_with_a_secure_random_32_character_string_here

# 5. First-Admin Provisioning & Management
ADMIN_EMAIL=admin@cottonguard.org
ADMIN_INITIAL_PASSWORD=replace_with_a_strong_initial_password
ADMIN_API_KEY=replace_with_a_secure_admin_api_key

# 6. Google OAuth 2.0 Verification (Web Client ID)
GOOGLE_CLIENT_ID=647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com
```

---

## 3. Flutter Client Configuration & Compile-Time Flags

Configured in [`lib/constants/api_constants.dart`](file:///E:/project/kushi/lib/constants/api_constants.dart):

### Compile-Time Dart Defines (`--dart-define`)
The mobile app defaults to the cloud production backend URL (`https://cotton-guard.onrender.com/api/v1`), but can be overridden at compile time:

```bash
# Point build to local Android Emulator host:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Point build to local LAN development host:
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000/api/v1

# Point build to production cloud backend:
flutter run --dart-define=API_BASE_URL=https://cotton-guard.onrender.com/api/v1
```

### Key Client Constants
- `googleServerClientId`: `"647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com"` (Web Client ID passed to `GoogleSignIn(serverClientId: ...)`).
- `connectTimeout`: `45` seconds (tuned to accommodate cloud free-tier cold starts).
- `requestTimeout`: `60` seconds.

---

## 4. Android Platform Settings

Declared in [`android/app/build.gradle.kts`](file:///E:/project/kushi/android/app/build.gradle.kts):
- **Application ID / Namespace**: `com.cottonguard.app.cottonguard`
- **Java Compatibility**: `JavaVersion.VERSION_17`
- **Kotlin Target**: `JVM_17`
- **Cleartext Network Config**: Enabled exclusively for local loopback addresses (`10.0.2.2`, `127.0.0.1`, `localhost`) in [`network_security_config.xml`](file:///E:/project/kushi/android/app/src/main/res/xml/network_security_config.xml).
