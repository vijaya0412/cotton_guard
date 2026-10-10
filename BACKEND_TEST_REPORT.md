# Cotton Guard - Automated Backend Test Report

**Execution Date**: October 10, 2026  
**Test Framework**: `pytest 9.1.1` on Python 3.13.14  
**Target Server**: FastAPI `backend/main.py` via `fastapi.testclient.TestClient`  
**Execution Environment**: Windows 11 (Dynamic Workspace root `E:\project\kushi`)  
**Overall Result**: **21 PASSED, 0 FAILED (100% Pass Rate)**

---

## 1. Test Suite Summary Matrix

| Test Suite File | Test Function | Target Component | Status | Latency / Evidence |
| :--- | :--- | :--- | :--- | :--- |
| `backend/test_api.py` | `test_health_endpoint` | `GET /api/v1/health` | **PASSED** | Returns CONNECTED, model_loaded=True, 7 classes. |
| `backend/test_api.py` | `test_advisory_all_endpoint` | `GET /api/v1/advisory/all` | **PASSED** | Returns 7 canonical disease catalog records + 4 general care items. |
| `backend/test_api.py` | `test_disease_detail_endpoint_canonical_and_aliases` | `GET /api/v1/disease/{class_name}` | **PASSED** | Resolves "Leaf Reddening", "Leaf Redding" typo, and "bacterial_blight" slug. |
| `backend/test_api.py` | `test_fields_endpoint` | `GET /api/v1/fields` | **PASSED** | Returns regional agro-climatic zones and soil data. |
| `backend/test_api.py` | `test_predict_valid_cotton_image` | `POST /api/v1/predict` | **PASSED** | Genuine ONNX inference on authentic sample image returns 200 with complete advisory metadata. |
| `backend/test_api.py` | `test_predict_empty_upload` | `POST /api/v1/predict` | **PASSED** | Empty bytes rejected with HTTP 400 Bad Request. |
| `backend/test_api.py` | `test_predict_corrupt_upload` | `POST /api/v1/predict` | **PASSED** | Non-image garbage bytes rejected with HTTP 400 Bad Request. |
| `backend/test_api.py` | `test_predict_poor_quality_dark_image` | `POST /api/v1/predict` | **PASSED** | Underexposed image rejected with HTTP 422 (`POOR_QUALITY`). |
| `backend/test_api.py` | `test_predict_poor_quality_bright_image` | `POST /api/v1/predict` | **PASSED** | Overexposed image rejected with HTTP 422 (`POOR_QUALITY`). |
| `backend/test_api.py` | `test_predict_non_cotton_synthetic_image` | `POST /api/v1/predict` | **PASSED** | High-contrast non-plant checkerboard rejected with HTTP 422 (`NON_COTTON`). |
| `test/test_ml_pipeline.py` | `test_canonical_classes` | `ml/classes.py` | **PASSED** | Exactly 7 canonical classes with standardized names. |
| `test/test_ml_pipeline.py` | `test_preprocessing_output_shapes` | `ml/preprocessing.py` | **PASSED** | NCHW layout produces `(1, 3, 224, 224)`; NHWC produces `(1, 224, 224, 3)`. |
| `test/test_ml_pipeline.py` | `test_cielab_clahe_enhancement` | `ml/preprocessing.py` | **PASSED** | CIELAB-CLAHE on luminance preserves shape and uint8 range. |
| `test/test_ml_pipeline.py` | `test_cotton_domain_gate_authentic_image` | `ml/cotton_gate.py` | **PASSED** | Authentic cotton leaf passes all gates with status `VALID`. |
| `test/test_ml_pipeline.py` | `test_cotton_domain_gate_dark_and_bright` | `ml/cotton_gate.py` | **PASSED** | Photometric limits correctly flag dark/bright images as `POOR_QUALITY`. |
| `test/test_ml_pipeline.py` | `test_cotton_domain_gate_blurry` | `ml/cotton_gate.py` | **PASSED** | Gaussian blurred image correctly flags `POOR_QUALITY` (blur_score < 15.0). |
| `test/test_ml_pipeline.py` | `test_cotton_domain_gate_non_plant_rejection` | `ml/cotton_gate.py` | **PASSED** | Synthetic texture correctly flags `NON_COTTON` (foliage_ratio < 0.15). |
| `test/test_ml_pipeline.py` | `test_cotton_domain_gate_uncertainty` | `ml/cotton_gate.py` | **PASSED** | Close candidate probabilities flagged as uncertain; separated probabilities pass. |
| `test/test_ml_pipeline.py` | `test_sqlite_advisory_database` | `backend/database.py` | **PASSED** | All 7 canonical classes retrieved with complete symptoms, treatment, and prevention. |
| `test/test_ml_pipeline.py` | `test_sqlite_alias_resolution` | `backend/database.py` | **PASSED** | `resolve_canonical_class` maps aliases to canonical database records. |
| `test/test_ml_pipeline.py` | `test_onnx_inference_output` | `ml/models/cotton_guard_model.onnx` | **PASSED** | Returns 7 finite floats without NaN or Inf values. |

---

## 2. Command Output

```
platform win32 -- Python 3.13.14, pytest-9.1.1, pluggy-1.6.0
rootdir: E:\project\kushi
collected 21 items

test/test_ml_pipeline.py::test_canonical_classes PASSED                   [  4%]
test/test_ml_pipeline.py::test_preprocessing_output_shapes PASSED         [  9%]
test/test_ml_pipeline.py::test_cielab_clahe_enhancement PASSED            [ 14%]
test/test_ml_pipeline.py::test_cotton_domain_gate_authentic_image PASSED  [ 19%]
test/test_ml_pipeline.py::test_cotton_domain_gate_dark_and_bright PASSED  [ 23%]
test/test_ml_pipeline.py::test_cotton_domain_gate_blurry PASSED           [ 28%]
test/test_ml_pipeline.py::test_cotton_domain_gate_non_plant_rejection PASSED [ 33%]
test/test_ml_pipeline.py::test_cotton_domain_gate_uncertainty PASSED      [ 38%]
test/test_ml_pipeline.py::test_sqlite_advisory_database PASSED            [ 42%]
test/test_ml_pipeline.py::test_sqlite_alias_resolution PASSED             [ 47%]
test/test_ml_pipeline.py::test_onnx_inference_output PASSED               [ 52%]
backend/test_api.py::test_health_endpoint PASSED                          [ 57%]
backend/test_api.py::test_advisory_all_endpoint PASSED                    [ 61%]
backend/test_api.py::test_disease_detail_endpoint_canonical_and_aliases PASSED [ 66%]
backend/test_api.py::test_fields_endpoint PASSED                          [ 71%]
backend/test_api.py::test_predict_valid_cotton_image PASSED               [ 76%]
backend/test_api.py::test_predict_empty_upload PASSED                     [ 80%]
backend/test_api.py::test_predict_corrupt_upload PASSED                   [ 85%]
backend/test_api.py::test_predict_poor_quality_dark_image PASSED          [ 90%]
backend/test_api.py::test_predict_poor_quality_bright_image PASSED        [ 95%]
backend/test_api.py::test_predict_non_cotton_synthetic_image PASSED       [100%]

======================= 21 passed, 5 warnings in 3.34s ========================
```

---

## 3. Real Inference vs Mock Disclosure

- **Zero Mocking of Model Predictions**: All 21 tests evaluate real code execution against the real SQLite `advisory.db` and genuine `cotton_guard_model.onnx` ONNX Runtime session.
- **Test Execution Speed**: Complete test suite finishes in under 3.5 seconds on CPU.
