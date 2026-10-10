---
title: Cotton Guard AI
emoji: 🌿
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# COTTON GUARD 🌿
### AI-Based Smart Cotton Leaf Disease Detection & Agronomic Advisory System

COTTON GUARD is an academic and production-grade agronomy system designed for cotton growers, agricultural extension officers, and plant pathologists. It integrates **Hybrid Preprocessing Optimization (CIELAB-CLAHE)**, **Attention-Based Deep Learning (MobileNetV2 + CBAM)**, and a **SQLite Retrieval-Based Agronomic Advisory Engine** to deliver real-time disease diagnosis, severity assessment, and ICAR-CICR-aligned crop protection protocols.

---

## 🏛 System Architecture & Multi-Stage Inference Pipeline

```
[Leaf Image Upload (Camera / Gallery / Multipart File)]
                         │
                         ▼
[Stage 1: Byte & Payload Validation]
   ├── Max Size: 15 MB | Min Size: 200 bytes
   ├── Formats: JPEG, PNG, WEBP (Safe PIL decode)
   └── Dimension Bounds: 150x150 min, 8192x8192 max
                         │ (Passed)
                         ▼
[Stage 2: Photometric Quality Screening]
   ├── Mean Perceived Luminance: [30.0, 245.0] (Rejects underexposed/washed-out leaves)
   └── Sharpness: Discrete Laplacian Variance >= 15.0 (Rejects sensor defocus / motion blur)
                         │ (Passed)
                         ▼
[Stage 3: Botanical Foliage & Cotton-Domain Gate]
   ├── Multi-Chromatic Foliage Mask: Chlorophyll, Anthocyanin, Necrotic lesion coverage >= 15%
   └── Texture Energy Gate: Std Dev of luminance >= 10.0 (Rejects synthetic/uniform objects)
                         │ (Passed)
                         ▼
[Stage 4: Attention-Based CNN Inference]
   ├── Preprocessing: Bilinear resize (224x224) -> CIELAB CLAHE (L-channel) -> ImageNet normalization
   ├── Architecture: MobileNetV2 Backbone + CBAM (Channel & Spatial Attention)
   ├── Engine: Production ONNX Runtime (CPUExecutionProvider, ~8 ms latency)
   └── Uncertainty Gate: Top confidence < 0.55 or margin < 0.12 triggers low-confidence triage
                         │ (Canonical Class)
                         ▼
[Stage 5: Class-Based Database Retrieval from SQLite]
   ├── Database: `backend/advisory.db` (5 normalized relational tables)
   ├── Query: `SELECT ... FROM diseases WHERE canonical_name = ?`
   └── Agronomic Safety: Suppresses chemical dosages if Stage 4 flags uncertain diagnosis
                         │
                         ▼
[Flutter Mobile Client Presentation]
   ├── Diagnostic Result Screen, Severity Badge, Confidence Meter
   └── Symptoms, Prevention, and Verified Treatment Guidance
```

---

## 🔬 Seven Canonical Cotton Leaf Classes

The system strictly enforces canonical disease terminology across dataset, models, database, APIs, and Flutter screens:

1. **Bacterial Blight** (*Xanthomonas citri pv. malvacearum*) - Angular water-soaked lesions, black arm vein necrosis.
2. **Cotton Leaf Curl Virus** (*Begomovirus* / CLCuV) - Upward/downward curling, vein enations, plant stunting.
3. **Healthy Leaf** (*Gossypium hirsutum L.*) - Uniform green chlorophyll, intact lamina, absence of lesions.
4. **Herbicide Growth Damage** (*Chemical Phytotoxicity*) - Vein strapping, duck-foot deformation, petiole epinasty.
5. **Leaf Hopper / Jassids** (*Amrasca biguttula biguttula*) - Marginal hopper burn, yellowing, downward curling.
6. **Leaf Reddening** (*Physiological Anthocyanosis*) - Bronze/red interveinal discoloration, cold/nutrient stress.
7. **Leaf Variegation** (*Genetic / Physiological Chlorosis*) - Sharp non-pathogenic geometric chlorophyll chimera.

---

## 📊 Dataset & Zero-Leakage Split

- **Authentic Source**: SAR-CLD-2024: A Comprehensive Dataset for Cotton Leaf Disease Detection (Mendeley Data, DOI: 10.17632/b3jy2p6k8w.2).
- **Verified Authentic Dataset**: Exactly **2,137** authentic original 800x800 JPEG images in `dataset/raw/SAR-CLD-2024/Original Dataset`.
- **Partition Methodology**: Stratified 70% Train, 15% Validation, 15% Test with near-duplicate isolation:
  - **Train**: 1,493 authentic originals
  - **Validation**: 322 authentic originals (100% untouched)
  - **Test**: 322 authentic originals (100% untouched)
- **Augmentation Collection**: Exactly **17,000** training samples in `dataset/augmented/train` synthesized exclusively from the 1,493 training seed images across 13 geometric, photometric, and hybrid transformations. Full provenance saved in `dataset/augmented/augmentation_metadata.csv`.

---

## 🧠 Model Benchmark on 322 Authentic Test Images

Evaluated strictly on the 322 untouched holdout test images with zero augmentation leakage:

| Model Configuration | Preprocessing | Attention | Accuracy | Macro F1 | Balanced Accuracy | Parameters | Model Size | CPU Latency | Selected |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A. MobileNetV2 Baseline** | Standard RGB | None | 61.49% | 0.6082 | 61.20% | 2,232,839 | 8.52 MB | 6.82 ms | No |
| **B. MobileNetV2 + Hybrid CLAHE** | CIELAB-CLAHE | None | 63.66% | 0.6315 | 63.80% | 2,232,839 | 8.52 MB | 7.15 ms | No |
| **C. MobileNetV2 + CBAM** | Standard RGB | CBAM | 64.29% | 0.6450 | 64.92% | 2,437,737 | 9.30 MB | 8.21 ms | No |
| **D. MobileNetV2 + Hybrid CLAHE + CBAM** | CIELAB-CLAHE | CBAM | **66.77%** | **0.6738** | **71.90%** | **2,437,737** | **9.30 MB** | **7.88 ms** | **PRODUCTION** |

### Per-Class Detailed Performance (Production Model)
- **Herbicide Growth Damage**: Precision 84.0%, Recall 100.0%, F1 0.913 (Support: 42)
- **Leaf Variegation**: Precision 76.2%, Recall 94.1%, F1 0.842 (Support: 17)
- **Bacterial Blight**: Precision 44.2%, Recall 89.5%, F1 0.591 (Support: 38)
- **Healthy Leaf**: Precision 59.3%, Recall 82.1%, F1 0.688 (Support: 39)
- **Cotton Leaf Curl Virus**: Precision 67.8%, Recall 61.5%, F1 0.645 (Support: 65)
- **Leaf Reddening**: Precision 85.4%, Recall 47.1%, F1 0.607 (Support: 87)
- **Leaf Hopper / Jassids**: Precision 83.3%, Recall 29.4%, F1 0.435 (Support: 34)

### Reference Model vs ONNX Runtime Parity
- **Evaluated Test Sample**: 100 authentic holdout images.
- **Class Agreement**: **100.0%** (100 / 100).
- **Max Probability Divergence**: `0.00000241`.
- **Mean Probability Divergence**: `0.00000049`.
- **CPU Latency**: 8.73 ms ONNX vs 49.51 ms PyTorch (5.6x speedup).

---

## 🚀 Getting Started & Backend Operations

### Prerequisites
- Python 3.13 (`py -3.13`)
- Installed packages: FastAPI, Uvicorn, ONNX Runtime, OpenCV, Pillow, Pytest, PyTorch, TensorFlow.

### Start the FastAPI Backend Service
```powershell
py -3.13 backend/run_server.py
```
Or directly via Uvicorn:
```powershell
py -3.13 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

### Run Automated Pytest Suite
```powershell
py -3.13 -m pytest test/test_ml_pipeline.py backend/test_api.py -v
```
*(All 21 automated tests pass in ~3.5 seconds)*.

### API Endpoints
- `GET /api/v1/health` - Server health, model state, and engine diagnostics.
- `POST /api/v1/predict` - Multipart image prediction through multi-stage quality/domain gate and ONNX model.
- `GET /api/v1/advisory/all` - Comprehensive 7-condition agronomic advisory catalog from SQLite.
- `GET /api/v1/disease/{class_name}` - Disease profile lookup supporting canonical names and aliases.
- `GET /api/v1/fields` - Regional agro-climatic zones, soil types, and management windows.

---

## 📱 Flutter Mobile Integration

The Flutter frontend communicates with the backend via `ApiService`:
- **Android Emulator**: `http://10.0.2.2:8000/api/v1`
- **Physical Device**: `http://<YOUR_LAN_IP>:8000/api/v1`
- **Configurable**: Configured on-device through the Server Connection Screen in Settings without code modification.
