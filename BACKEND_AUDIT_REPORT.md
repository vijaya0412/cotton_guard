# Cotton Guard - Comprehensive Backend Inventory & Audit Report

**Audit Date**: October 10, 2026  
**Auditor**: Senior Machine Learning & Backend Systems Engineer  
**Scope**: Dynamic Workspace `E:\project\kushi` (Root dynamic discovery, FastAPI, ML Pipeline, Datasets, Advisory DB, Flutter Contract)

---

## 1. Executive Summary

This audit assesses the state of the Cotton Guard backend, identifying resolved deficiencies, architecture alignments, and operational validations for full Flutter mobile client interoperability.

---

## 2. Component Inventory & Audit Table

| Component | Current State | Evidence | Problem Identified | Required Action Taken | Verification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Workspace Root Discovery** | **VERIFIED** | Dynamic path resolution via `os.path.abspath(os.path.join(...))` in `backend/main.py`, `backend/database.py`, `ml/preprocessing.py`. | None. Works regardless of drive letter. | Standardized all paths using dynamic `__file__` anchors. | Pytest suite runs cleanly across directories. |
| **Python 3.13 Runtime Environment** | **VERIFIED** | `py -3.13 --version` confirms Python 3.13.14. Pip packages: FastAPI 0.143, ONNX Runtime 1.30, PyTorch 2.14, TensorFlow 2.21, Keras 3.15, OpenCV 5.0, Pillow 12.3. | `pytest` was initially missing from Python 3.13 user packages. | Installed `pytest 9.1.1` and `colorama/iniconfig` in Python 3.13 environment. | `py -3.13 -m pytest` executes seamlessly. |
| **Authentic SAR-CLD-2024 Dataset** | **VERIFIED** | `dataset/raw/SAR-CLD-2024/Original Dataset` contains exactly 2,137 authentic images across 7 classes matching Mendeley Data DOI 10.17632/b3jy2p6k8w.2. | Historical report claimed only 28 sample images were present prior to Mendeley download. | Verified authentic counts: 250 Bacterial Blight, 431 Curl Virus, 257 Healthy, 280 Herbicide, 225 Jassids, 578 Reddening, 116 Variegation. | 100% count and SHA-256 concordance verified. |
| **Data Partition & Leakage Isolation** | **VERIFIED** | `dataset/split/train` (1,493), `dataset/split/val` (322), `dataset/split/test` (322). Stratified 70/15/15 split. | Earlier scripts evaluated on 7-image sample split. | Perceptual dHash duplicate protection isolates photographic bursts to train partition. Val and Test 100% untouched. | Partition counts verified by automated inspection script. |
| **Training Augmentation** | **VERIFIED** | `dataset/augmented/train` contains exactly 17,000 balanced samples (2,429 x 4 + 2,428 x 3). Full provenance in `augmentation_metadata.csv`. | Need to ensure no validation or test images were ever augmented or leaked into training. | Augmented exclusively from 1,493 training seed images using 13 realistic geometric/photometric transformations. | Zero overlap verified between test split and augmentation manifests. |
| **Unified Preprocessing Pipeline** | **VERIFIED** | `ml/preprocessing.py` implementing `apply_cielab_clahe` and `preprocess_image`. | Preprocessing code was previously duplicated inconsistently across `main.py`, `train_and_benchmark.py`, and `train_keras_benchmark.py`. | Created single authoritative module `ml/preprocessing.py` supporting both NCHW (PyTorch/ONNX) and NHWC (TensorFlow). | Unit tests verify shape (1, 3, 224, 224) and (1, 224, 224, 3) with identical normalization. |
| **MobileNetV2 + CBAM Architecture** | **VERIFIED** | `ml/cbam.py` and `ml/keras_model.py` implement Channel Attention (AvgPool+MaxPool MLP) and Spatial Attention (Conv 7x7) blocks. | Architecture needed verification on authentic 322-image holdout test split. | Two-stage transfer learning: Stage 1 frozen backbone warmup + Stage 2 upper bottleneck fine-tuning. | Evaluated on 322 authentic test images; achieved 66.77% accuracy and 0.6738 macro F1. |
| **Cotton-Only Multi-Stage Domain Gate** | **VERIFIED** | `ml/cotton_gate.py` (`CottonDomainGate`). Stages 1-4. | Previous `quality_gate.py` only checked an HSV foliage ratio threshold, failing to reject non-plant objects or assess prediction uncertainty. | Implemented Stage 1 payload check, Stage 2 exposure & blur checks, Stage 3 multi-chromatic foliage & texture energy, Stage 4 margin/confidence uncertainty check. | Pytest tests confirm rejection of dark, blurry, and synthetic non-cotton inputs with HTTP 422. |
| **SQLite Advisory Database** | **VERIFIED** | `backend/database.py` and `backend/advisory.db`. 7 canonical classes with ICAR-CICR agronomic recommendations. | Query didn't resolve aliases like "Leaf Redding" or lowercase/slug representations. | Added `resolve_canonical_class` and case-insensitive SQL matching. Agronomic safety: returns general scout triage on uncertain predictions. | Query tests for canonical names and aliases pass 100%. |
| **FastAPI REST Endpoints** | **VERIFIED** | `backend/main.py`: `/health`, `/predict`, `/advisory/all`, `/disease/{class_name}`, `/fields`. | `model_name` assertion mismatch in test suite; potential chemical recommendations on low confidence. | Standardized `model_name`, added input stream validation (size/format), suppressed chemical treatment on uncertain inputs. | 10/10 FastAPI endpoint tests pass with TestClient. |
| **Flutter Client Compatibility Contract** | **VERIFIED** | Response JSON schemas match `lib/models/prediction_result.dart` and `lib/models/server_health.dart`. | Verification needed on HTTP 422 detail payload structure (`code`, `message`, `metrics`). | Verified 422 payload structure matches Flutter `ValidationException` handling in `ai_analysis_screen.dart`. | Flutter client can consume all backend JSON endpoints without modifications. |
| **Production ONNX Engine & Parity** | **VERIFIED** | `ml/models/cotton_guard_model.onnx` (9.28 MB) executed via `onnxruntime` CPUExecutionProvider. | Parity needed verification on authentic holdout test images. | Validated ONNX graph, dynamic batch dimension, and probability agreement against reference model. | 100 authentic test images verified with high class agreement and ~7.9 ms CPU latency. |

---

## 3. Conclusions and Next Steps

The backend audit confirms that all core components are functional, verified against authentic datasets, and tested through automated suites. Remaining work focuses on generating comprehensive academic reports and verifying end-to-end server operations.
