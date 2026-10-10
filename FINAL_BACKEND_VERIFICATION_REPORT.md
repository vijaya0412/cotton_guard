# Cotton Guard - Final Master Backend Verification & Release Report

**Project Title**: AI-Based Smart Plant Disease Detection & Agronomic Advisory System  
**Product Name**: **COTTON GUARD**  
**Audit & Verification Date**: October 10, 2026  
**Auditor**: Senior Machine Learning Engineer, Computer Vision Researcher & Backend Systems Architect  
**Workspace**: Dynamically discovered root `E:\project\kushi`  
**Execution Environment**: Windows 11, Python 3.13.14, FastAPI 0.143, Pytest 9.1.1, ONNX Runtime 1.30, PyTorch 2.14, TensorFlow 2.21  

---

## 1. Verified Facts

1. **Authentic Dataset**:
   - Mendeley Data source: SAR-CLD-2024 (DOI: 10.17632/b3jy2p6k8w.2).
   - Exactly **2,137** authentic original 800x800 JPEG images verified in `dataset/raw/SAR-CLD-2024/Original Dataset`.
   - Verified per-class count:
     - Bacterial Blight: 250
     - Cotton Leaf Curl Virus: 431
     - Healthy Leaf: 257
     - Herbicide Growth Damage: 280
     - Leaf Hopper / Jassids: 225
     - Leaf Reddening: 578
     - Leaf Variegation: 116
   - 0 corrupted files.

2. **Stratified Split & Leakage Isolation**:
   - Stratified partition:
     - Training: **1,493** original images (70%)
     - Validation: **322** original images (15%)
     - Test: **322** original images (15%)
   - Near-duplicate photographic bursts were clustered via dHash and confined strictly to the training split.
   - Zero data leakage: Validation and test partitions remain 100% untouched authentic captures with zero synthetic alterations.

3. **Augmentation Target**:
   - Target reached: Exactly **17,000** training samples in `dataset/augmented/train`.
   - Generated exclusively from the 1,493 authentic training seeds across 13 geometric, photometric, and hybrid transformations.
   - Complete record provenance saved in `dataset/augmented/augmentation_metadata.csv` (17,000 rows).

4. **Academic Architecture Implementation**:
   - Pretrained `MobileNetV2` backbone with transfer learning.
   - `CBAM` (Convolutional Block Attention Module) sequentially applying Channel Attention (AvgPool+MaxPool shared MLP) and Spatial Attention (7x7 Conv).
   - Hybrid `CIELAB-CLAHE` contrast optimization on Luminance channel (`clipLimit=2.0`, `tileGridSize=(8, 8)`).
   - Two-stage training: Stage 1 classification head warmup + Stage 2 upper bottleneck fine-tuning.

5. **Measured Real Test Performance on 322 Authentic Images**:
   - Evaluated on all 322 untouched holdout test images.
   - Real Test Accuracy: **66.77%**
   - Macro Precision: **71.4%**
   - Macro Recall: **71.9%**
   - Macro F1-Score: **0.6738**
   - Balanced Accuracy: **71.90%**
   - Herbicide Growth Damage recall: 100.0% (42/42)
   - Leaf Variegation recall: 94.1% (16/17)
   - Bacterial Blight recall: 89.5% (34/38)
   - Healthy Leaf recall: 82.1% (32/39)

6. **Production ONNX Parity on 100 Authentic Test Images**:
   - Tested sample: 100 authentic holdout images.
   - Class Agreement: **100.0%** (100 / 100 matches).
   - Maximum Output Probability Divergence: `0.00000241` (2.41e-6).
   - Mean Output Probability Divergence: `0.00000049` (4.90e-7).
   - Inference Latency: **8.73 ms** ONNX CPU vs 49.51 ms PyTorch CPU (5.6x acceleration).

7. **Multi-Stage Cotton-Only Gating**:
   - Stage 1: Payload and dimension limits (rejects files <200B, >15MB, <150x150, corrupt).
   - Stage 2: Photometric limits (rejects brightness <30 or >245; blur <15.0).
   - Stage 3: Botanical foliage and texture energy check (rejects non-plant, uniform, or non-chlorophyll inputs).
   - Stage 4: Prediction uncertainty analysis (margin < 0.12 or top confidence < 0.55 triggers low-confidence triage, suppressing chemical recommendations).

8. **SQLite Advisory Database**:
   - Relational database `backend/advisory.db` with 5 normalized tables.
   - Complete scientific, symptom, prevention, treatment, and severity data for all 7 canonical classes.
   - Class-based retrieval using parameterized queries (`WHERE canonical_name = ?`).
   - Alias and typo resolution (`Leaf Redding`, `curl_virus`, `bacterial_blight` all map cleanly).

9. **FastAPI & Flutter API Contract**:
   - 100% endpoint compatibility verified with existing Flutter client (`lib/services/api_service.dart`, `DiagnosisResultScreen`, `ServerHealth`).
   - Zero frontend UI modifications required.

---

## 2. Test Results

- **Automated Pytest Results**:
  - `backend/test_api.py`: 10 passed, 0 failed.
  - `test/test_ml_pipeline.py`: 11 passed, 0 failed.
  - **Total**: **21 passed, 0 failed (100% pass rate)**.
- Real model execution evaluated; zero artificial mocks used for inference claims.

---

## 3. Estimates

- **Cold Startup Latency**: Approximately 800 - 1,200 ms (initial Python process spawn, ONNX session initialization, SQLite connection test).
- **Warm API Response Time**: ~12 - 25 ms total roundtrip per prediction request on local CPU.
- **RAM Footprint**: ~180 - 240 MB peak memory during active inference.

---

## 4. Assumptions

- Field users take leaf photographs with smartphone camera resolution >= 800x800 under daytime diffuse sunlight.
- Network routing for Android emulator is configured to `http://10.0.2.2:8000/api/v1` and physical devices connect via local Wi-Fi IP `http://<LAN_IP>:8000/api/v1`.
- The SQLite database remains local to the backend service.

---

## 5. Remaining Limitations

1. **Botanical Specificity Gating**:
   - The multi-stage gate rejects synthetic objects, sky, skin, metal, paper, and non-plant textures.
   - However, distinguishing arbitrary non-cotton leaves (e.g. green tomato or potato leaves) from cotton leaves without a dedicated botanical multi-species herbarium dataset relies on texture energy and Stage 4 uncertainty rejection. This botanical limitation is acknowledged transparently.
2. **Visual Overlap in Leaf Reddening and Blight**:
   - Late-season leaf reddening co-occurs with necrotic bacterial lesions in field conditions, leading to 27 misclassifications in the confusion matrix. Future models could benefit from multi-label segmentation.

---

## 6. Blocked Work

- **None**. All requested backend audit, training validation, preprocessing unification, domain gating, advisory integration, and automated testing tasks are complete.
