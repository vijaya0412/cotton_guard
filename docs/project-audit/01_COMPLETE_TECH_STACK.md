# 01 — Complete Tech Stack & Dependency Matrix

This document provides an exhaustive, ground-truth inventory of every programming language, runtime, library, framework, driver, and system dependency utilized in Cotton Guard across the mobile client, backend API, machine learning pipeline, database infrastructure, and DevOps deployment.

---

## 1. Programming Languages & Runtimes

| Layer | Language / Runtime | Specification / Version | Runtime Role & Location |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | **Dart** | `^3.13.4` (SDK constraint in [`pubspec.yaml`](file:///E:/project/kushi/pubspec.yaml#L21-L22)) | Core language for Flutter mobile application widgets, controllers, models, and network services. |
| **Mobile Platform** | **Kotlin / Java** | Kotlin 1.9+, Java 17 (`JVM_17` in [`build.gradle.kts`](file:///E:/project/kushi/android/app/build.gradle.kts#L13-L15)) | Android native compilation target, Gradle build scripts, Android platform embedding. |
| **Backend API** | **Python** | Python 3.12 (Container) / Python 3.13 (Local verified: `Python 3.13.14`) | High-performance asynchronous REST API server, ML preprocessing, and database connector. |
| **DevOps / Infra** | **Bash / POSIX Shell** | Debian GNU/Linux 12 (bookworm) / Windows PowerShell 5.1/7.x | Docker container entrypoint, test runner scripts, and deployment automation. |

---

## 2. Mobile Client Dependencies (Flutter / Android)

All mobile dependencies are declared in [`pubspec.yaml`](file:///E:/project/kushi/pubspec.yaml) and locked in [`pubspec.lock`](file:///E:/project/kushi/pubspec.lock):

### Production Dependencies

| Package Name | Declared Version | Resolved Version | Architectural Responsibility |
| :--- | :--- | :--- | :--- |
| [`flutter`](file:///E:/project/kushi/pubspec.yaml#L31-L32) | SDK | Flutter 3.x | UI layout engine, Material 3 design system, gesture recognition, animation controllers. |
| [`http`](file:///E:/project/kushi/pubspec.yaml#L37) | `^1.6.0` | `1.6.0` | Client HTTP transport in [`ApiService`](file:///E:/project/kushi/lib/services/api_service.dart#L28); multipart file uploading for disease scan images. |
| [`image_picker`](file:///E:/project/kushi/pubspec.yaml#L38) | `^1.2.4` | `1.2.4` | Camera capture and gallery image selection bridge on Android and iOS platforms. |
| [`shared_preferences`](file:///E:/project/kushi/pubspec.yaml#L39) | `^2.5.6` | `2.5.6` | Key-value persistent local storage for user profile, authentication token, scan history JSON, and server URLs in [`StorageService`](file:///E:/project/kushi/lib/services/storage_service.dart). |
| [`intl`](file:///E:/project/kushi/pubspec.yaml#L40) | `^0.20.3` | `0.20.3` | Date formatting, time-of-day greetings for Indian Standard Time in [`IndianTimeService`](file:///E:/project/kushi/lib/services/indian_time_service.dart). |
| [`path_provider`](file:///E:/project/kushi/pubspec.yaml#L41) | `^2.1.6` | `2.1.6` | Locating application cache and document directories for persisting profile avatars and cropped scans. |
| [`path`](file:///E:/project/kushi/pubspec.yaml#L42) | `^1.9.1` | `1.9.1` | Cross-platform file path manipulation and extension parsing. |
| [`google_sign_in`](file:///E:/project/kushi/pubspec.yaml#L43) | `^6.2.2` | `6.2.2` | Google OAuth 2.0 integration on Android using Google Play Services; provides OAuth ID token. |
| [`cupertino_icons`](file:///E:/project/kushi/pubspec.yaml#L36) | `^1.0.8` | `1.0.8` | Fallback iOS-style icon assets. |

### Development Dependencies

| Package Name | Declared Version | Resolved Version | Architectural Responsibility |
| :--- | :--- | :--- | :--- |
| [`flutter_test`](file:///E:/project/kushi/pubspec.yaml#L46-L47) | SDK | Flutter Test | Unit and widget test execution framework for Flutter. |
| [`flutter_lints`](file:///E:/project/kushi/pubspec.yaml#L54) | `^6.0.0` | `6.0.0` | Static analysis rule set enforcing clean Dart practices via [`analysis_options.yaml`](file:///E:/project/kushi/analysis_options.yaml). |
| [`flutter_launcher_icons`](file:///E:/project/kushi/pubspec.yaml#L55) | `^0.14.4` | `0.14.4` | Automated asset pipeline for generating adaptive Android launcher icons. |

---

## 3. Backend & Machine Learning Dependencies (Python)

All backend dependencies are defined in [`backend/requirements.txt`](file:///E:/project/kushi/backend/requirements.txt):

| Package Name | Pinned Version | Architectural Role | Module Location |
| :--- | :--- | :--- | :--- |
| **`fastapi`** | `0.143.0` | Asynchronous web framework exposing REST API endpoints, routing, error handling, and dependency injection. | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L16) |
| **`uvicorn[standard]`** | `0.54.0` | ASGI web server handling HTTP requests and keep-alive connections on port 7860/8000. | [`backend/run_server.py`](file:///E:/project/kushi/backend/run_server.py#L8) |
| **`python-multipart`** | `0.0.32` | Streaming multipart/form-data parser for processing raw binary image uploads in `UploadFile`. | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L16) |
| **`python-dotenv`** | `1.2.4` | Environment variable management loading `.env` files from root and backend directories. | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L30) |
| **`pydantic`** | `2.13.5` | Data validation, request payload schemas, and response serialization models. | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L18) |
| **`pillow`** | `12.3.0` | Image decoding, format verification (JPEG/PNG/WEBP), dimension validation, and color space conversion (RGB/HSV). | [`ml/cotton_gate.py`](file:///E:/project/kushi/ml/cotton_gate.py#L11) |
| **`numpy`** | `2.5.3` | High-performance tensor manipulation, pixel arrays, luminance computation, and softmax probability normalization. | [`ml/preprocessing.py`](file:///E:/project/kushi/ml/preprocessing.py#L7) |
| **`opencv-python-headless`** | `5.0.0.93` | Headless computer vision library: CIELAB color space transformation and CLAHE luminance equalization. | [`ml/preprocessing.py`](file:///E:/project/kushi/ml/preprocessing.py#L6) |
| **`onnxruntime`** | `1.30.0` | Optimized neural network execution engine running `cotton_guard_model.onnx` via CPUExecutionProvider. | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L22) |
| **`psycopg2-binary`** | `2.9.13` | PostgreSQL database adapter enabling cloud persistence with connection string support for Neon PostgreSQL. | [`backend/database.py`](file:///E:/project/kushi/backend/database.py#L89) |
| **`httpx`** | `0.28.1` | Asynchronous and synchronous HTTP client used by FastAPI TestClient during automated integration tests. | [`backend/test_api.py`](file:///E:/project/kushi/backend/test_api.py#L14) |
| **`pytest`** | `9.1.1` | Unit, integration, and security regression test runner. | Test files in `backend/` and `test/` |

---

## 4. Database & Storage Layer

| Engine | Driver / Library | Deployment Scope | Storage Strategy |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | `psycopg2-binary` (v2.9.13) via [`DatabaseConnection`](file:///E:/project/kushi/backend/database.py#L76-L160) | **Production Cloud** (Neon Serverless PostgreSQL) | Fully persistent; enabled when `DATABASE_URL` is configured. Handles users, audit logs, and advisories. |
| **SQLite 3** | Python Standard Library `sqlite3` (`advisory.db`) | **Local Development & Offline Testing** | File-based relational storage with Write-Ahead Logging (`PRAGMA journal_mode=WAL`). |
| **SharedPreferences** | Android `SharedPreferences` via `shared_preferences` plugin | **Mobile Device (Client-Side)** | Stores user session tokens, login state, offline scan history list, and server connection URLs. |

---

## 5. Security & Cryptographic Libraries

| Functionality | Standard / Algorithm | Implementation Method | Location in Code |
| :--- | :--- | :--- | :--- |
| **Password Hashing** | PBKDF2-HMAC-SHA256 (100,000 iterations) | Python `hashlib.pbkdf2_hmac` with 128-bit random salt (`secrets.token_hex(16)`) | [`backend/database.py`](file:///E:/project/kushi/backend/database.py#L697-L707) |
| **Password Verification** | Constant-time string comparison | Python `secrets.compare_digest` (prevents timing attacks) | [`backend/database.py`](file:///E:/project/kushi/backend/database.py#L709-L713) |
| **Session Authentication** | Cryptographic HMAC-SHA256 Token | Base64 URL-safe JSON payload + HMAC-SHA256 signature using `COTTON_GUARD_SECRET_KEY` | [`backend/database.py`](file:///E:/project/kushi/backend/database.py#L714-L743) |
| **OAuth Verification** | Google ID Token Public Validation | Standard HTTPS GET to Google's public endpoint `https://oauth2.googleapis.com/tokeninfo?id_token=...` | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L590-L654) |
| **Admin Authorization** | Secret Key Digest or Bearer Token | `secrets.compare_digest` against `ADMIN_API_KEY` or role inspection on session payload | [`backend/main.py`](file:///E:/project/kushi/backend/main.py#L755-L788) |

---

## 6. External Third-Party APIs

| Service Name | Endpoint Root | Purpose | Authentication / Cost |
| :--- | :--- | :--- | :--- |
| **Open-Meteo Weather API** | `https://api.open-meteo.com/v1/forecast` | Current temperature, relative humidity, wind speed, precipitation probability, and weather codes. | Completely Free, No API Key Required, Zero Cost. |
| **Google OAuth 2.0 Tokeninfo** | `https://oauth2.googleapis.com/tokeninfo` | Cryptographic signature and claim verification of client-side Google Sign-In tokens. | Completely Free, Public Verification Endpoint. |
| **Neon PostgreSQL** | Cloud PostgreSQL (`ep-*.neon.tech`) | Serverless relational database for persistent farmer accounts and audit logs. | Free-Tier Compatible (0.5 GB storage, pooled connections). |
| **Render Web Services** | `https://cotton-guard.onrender.com` | Cloud hosting platform executing containerized FastAPI backend. | Free-Tier Compatible (512 MB RAM, ephemeral storage supplemented by Neon). |
