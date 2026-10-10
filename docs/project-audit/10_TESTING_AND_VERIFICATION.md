# 10 — Testing, Verification & QA Report

This document records the empirical results of all automated tests, static analysis checks, and live network verifications executed against the **Cotton Guard** codebase.

---

## 1. Quality Assurance Summary

```
================================================================================
COTTON GUARD QUALITY ASSURANCE & VERIFICATION SUMMARY
================================================================================
Python Backend Tests (pytest)       : 37 / 37 PASSED (100%) in 21.77s
Python ML Pipeline Tests (pytest)   : 11 / 11 PASSED (100%) in 1.37s
TOTAL PYTHON TESTS                  : 48 / 48 PASSED (100%)
Flutter Unit & Widget Tests         : 20 / 20 PASSED (100%) in 5.80s
Flutter Static Code Analysis        : 0 ERRORS, 0 WARNINGS, 0 LINTS (Clean)
Live Cloud Service Verification     : HTTP 200 OK (https://cotton-guard.onrender.com)
Production ONNX Model Parity        : 100% Agreement with PyTorch Reference
================================================================================
```

---

## 2. Python Backend Pytest Suite (37 Tests)

Executed via `py -3.13 -m pytest backend/ -v`. Result: **37 passed in 21.77s**.

### Test File Breakdown

| Test File | Test Count | Scope & Verifications |
| :--- | :---: | :--- |
| [`backend/test_api.py`](file:///E:/project/kushi/backend/test_api.py) | **13** | Validates root status, `/api/v1/health` response schema, `/api/v1/predict` with authentic leaf image, 15 MB upload limit rejection (413), corrupt image handling (400), underexposed leaf rejection (422), overexposed leaf rejection (422), blurry leaf rejection (422), synthetic non-plant rejection (422), low-confidence fallback, `/advisory/all` catalog, `/disease/{class_name}` path lookup, and `/fields` agricultural zones. |
| [`backend/test_auth.py`](file:///E:/project/kushi/backend/test_auth.py) | **5** | Validates user registration, duplicate email rejection (409), login authentication, invalid password rejection (401), and `/auth/me` profile retrieval using Bearer tokens. |
| [`backend/test_database_persistence.py`](file:///E:/project/kushi/backend/test_database_persistence.py) | **8** | Validates dual-engine connection switching, SQLite CRUD operations, PostgreSQL placeholder conversion (`?` to `%s`), `INSERT ... RETURNING id`, idempotent knowledge base seeding, disease alias resolution, salted PBKDF2 password hashing, and session token HMAC verification. |
| [`backend/test_security_regression.py`](file:///E:/project/kushi/backend/test_security_regression.py) | **5** | Tests security invariants: self-assigned admin role rejection (403), unauthenticated admin access rejection (403), fail-closed invalid admin credentials, production secret key enforcement (raises `RuntimeError` on insecure defaults), and idempotent admin provisioning. |
| [`backend/test_service_state.py`](file:///E:/project/kushi/backend/test_service_state.py) | **6** | Validates service start/stop state machine, model unloading from RAM via `gc.collect()`, rejection of `/predict` requests with HTTP 503 when service is stopped, service resumption, and administrative audit logging. |

---

## 3. Python ML Pipeline Pytest Suite (11 Tests)

Executed via `py -3.13 -m pytest test/test_ml_pipeline.py -v`. Result: **11 passed in 1.37s**.

| Test Name | Verification Target | Status |
| :--- | :--- | :---: |
| `test_canonical_classes` | Exactly 7 canonical classes defined without typographical errors. | **PASS** |
| `test_preprocessing_output_shapes` | Output tensor shape is $(1, 3, 224, 224)$ for NCHW and $(1, 224, 224, 3)$ for NHWC; no NaN values. | **PASS** |
| `test_cielab_clahe_enhancement` | CLAHE enhances luminance channel without altering tensor dimensions. | **PASS** |
| `test_cotton_domain_gate_authentic_image` | Authentic sample passes quality and foliage checks (`VALID`). | **PASS** |
| `test_cotton_domain_gate_dark_and_bright` | Underexposed ($<30$) and overexposed ($>245$) inputs rejected as `POOR_QUALITY`. | **PASS** |
| `test_cotton_domain_gate_blurry` | Gaussian blurred image (blur score $< 15.0$) rejected as `POOR_QUALITY`. | **PASS** |
| `test_cotton_domain_gate_non_plant_rejection` | High-frequency non-plant checkerboard rejected as `NON_COTTON`. | **PASS** |
| `test_cotton_domain_gate_uncertainty` | Ambiguous probability distributions correctly trigger uncertainty flag. | **PASS** |
| `test_sqlite_advisory_database` | Knowledge base contains 7 complete records with symptoms, treatments, prevention. | **PASS** |
| `test_sqlite_alias_resolution` | Disease slugs (e.g. `Leaf Redding`, `curl_virus`) resolve to canonical names. | **PASS** |
| `test_onnx_inference_output` | ONNX model executes via CPU, produces 7 finite, non-NaN logits. | **PASS** |

---

## 4. Flutter Unit & Widget Test Suite (20 Tests)

Executed via `flutter test`. Result: **20 passed in 5.80s**.

| # | Test Name | Target Subsystem | Status |
| :---: | :--- | :--- | :---: |
| 1 | `Canonical Classes list has exactly 7 conditions without typos` | [`CanonicalClasses`](file:///E:/project/kushi/lib/constants/canonical_classes.dart) | **PASS** |
| 2 | `All canonical classes have verified asset paths and details` | [`CanonicalClasses`](file:///E:/project/kushi/lib/constants/canonical_classes.dart) | **PASS** |
| 3 | `PredictionResult parses JSON response correctly` | [`PredictionResult`](file:///E:/project/kushi/lib/models/prediction_result.dart) | **PASS** |
| 4 | `ServerHealth handles connected and disconnected states` | [`ServerHealth`](file:///E:/project/kushi/lib/models/server_health.dart) | **PASS** |
| 5 | `HistoryController accurately computes statistics` | [`HistoryController`](file:///E:/project/kushi/lib/controllers/history_controller.dart) | **PASS** |
| 6 | `ApiConstants normalizes cloud domains to HTTPS and preserves local dev HTTP` | [`ApiConstants`](file:///E:/project/kushi/lib/constants/api_constants.dart) | **PASS** |
| 7 | `StatusBadge renders server status and severity properly` | [`StatusBadge`](file:///E:/project/kushi/lib/widgets/status_badge.dart) | **PASS** |
| 8 | `CustomButton renders and triggers callback` | [`CustomButton`](file:///E:/project/kushi/lib/widgets/custom_button.dart) | **PASS** |
| 9 | `GlassCard renders child content` | [`GlassCard`](file:///E:/project/kushi/lib/widgets/glass_card.dart) | **PASS** |
| 10 | `CottonGuardApp boots with splash screen branding` | [`CottonGuardApp`](file:///E:/project/kushi/lib/main.dart) | **PASS** |
| 11 | `IndianTimeService produces accurate greetings across all IST periods` | [`IndianTimeService`](file:///E:/project/kushi/lib/services/indian_time_service.dart) | **PASS** |
| 12 | `IndianLocations database provides 780+ districts with coordinates` | [`IndianLocations`](file:///E:/project/kushi/lib/data/indian_locations.dart) | **PASS** |
| 13 | `WeatherData formats units, tracks observation time, handles caching` | [`WeatherData`](file:///E:/project/kushi/lib/models/weather_data.dart) | **PASS** |
| 14 | `UserProfile persists profileImagePath, coordinates, and copyWith` | [`UserProfile`](file:///E:/project/kushi/lib/models/user_profile.dart) | **PASS** |
| 15 | `MainNavigationShell displays exactly 4 destinations without central Scan button` | [`MainNavigationShell`](file:///E:/project/kushi/lib/screens/main_navigation_shell.dart) | **PASS** |
| 16 | `DiseaseLibraryScreen lists 7 conditions without any severity badges on cards` | [`DiseaseLibraryScreen`](file:///E:/project/kushi/lib/screens/disease_library/disease_library_screen.dart) | **PASS** |
| 17 | `GoogleAuthService extracts numeric status codes accurately` | [`GoogleAuthService`](file:///E:/project/kushi/lib/services/google_auth_service.dart) | **PASS** |
| 18 | `GoogleAuthException stores message, code, and status code` | [`GoogleAuthService`](file:///E:/project/kushi/lib/services/google_auth_service.dart) | **PASS** |
| 19 | `ScanScreen renders camera viewfinder, instruction overlay, action buttons without overflow` | [`ScanScreen`](file:///E:/project/kushi/lib/screens/scan/scan_screen.dart) | **PASS** |
| 20 | `App navigation integrity test across root routes` | [`lib/main.dart`](file:///E:/project/kushi/lib/main.dart) | **PASS** |

---

## 5. Flutter Static Analysis (`flutter analyze`)

Executed via `flutter analyze`. Result:
```
Analyzing kushi...
No issues found! (ran in 83.7s)
```
- **0 Errors**: Zero compile-time or syntax errors.
- **0 Warnings**: All imports, deprecations, and null-safety contracts resolved.
- **0 Lints**: Complete compliance with `package:flutter_lints/flutter.yaml`.

---

## 6. Live Network & Cloud Verification

### 1. Cloud Health Endpoint
- **Target URL**: `https://cotton-guard.onrender.com/api/v1/health`
- **HTTP Status**: **200 OK**
- **Verified Payload**:
  ```json
  {
    "status": "CONNECTED",
    "version": "1.0.0",
    "model_loaded": true,
    "model_name": "MobileNetV3-Large + CBAM Attention (Hybrid CLAHE)",
    "inference_engine": "ONNX Runtime",
    "cotton_validation_ready": true,
    "disease_model_ready": true,
    "supported_classes": [
      "Bacterial Blight",
      "Cotton Leaf Curl Virus",
      "Healthy Leaf",
      "Herbicide Growth Damage",
      "Leaf Hopper / Jassids",
      "Leaf Reddening",
      "Leaf Variegation"
    ]
  }
  ```

### 2. Live Cloud Inference Prediction
- **Target URL**: `https://cotton-guard.onrender.com/api/v1/predict`
- **Input**: Authentic leaf sample `bacterial_blight_1.jpg`
- **HTTP Status**: **200 OK**
- **Verified Response**:
  - `predicted_class`: `"Bacterial Blight"`
  - `confidence`: `1.0` (100%)
  - `is_healthy`: `false`
  - `severity`: `"Moderate to High"`
  - `treatment`: Contains *Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L*
  - `latency_ms`: ~18 ms
