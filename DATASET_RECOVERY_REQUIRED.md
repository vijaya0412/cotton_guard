# Cotton Guard - Dataset Recovery Required Report

**Status**: **AUTHENTIC SAR-CLD-2024 DATASET NOT FOUND IN CURRENT WORKSPACE**  
**Audit Date**: October 8, 2026  
**Auditor**: Independent Engineering & ML Dataset Audit  

---

## 1. Executive Summary & Critical Deficiency Statement

A comprehensive recursive audit of the entire workspace (`E:\project\kushi`) and accessible parent/drive directories (`E:\project`, `E:\Download`) confirmed that the full authentic **SAR-CLD-2024** dataset (reportedly containing 14,000+ authentic field images) **is not present locally** in any uncompressed directory or archive file.

The workspace contains exclusively **28 original authentic images** (4 sample images per class across 7 canonical classes), located in `assets/diseases/`.

---

## 2. Verified Dataset Inventory

| Dataset Metric | Verified Count | Details |
| :--- | :--- | :--- |
| **Original Dataset Available** | **28 images** | 800x800 JPEG images (4 per class across 7 classes) |
| **Original Training Seed Images** | **14 images** | 2 original images per class |
| **Original Validation Images** | **7 images** | Exactly 1 original image per class (7 images total) |
| **Original Test Images** | **7 images** | Exactly 1 original image per class (7 images total) |
| **Augmented Training Collection** | **17,000 images** | Synthesized via 14 geometric/photometric transformations |
| **Total Authentic Dataset Found** | **28 images** | Only 28 authentic images exist in the workspace |

---

## 3. Per-Class Image Availability Matrix

| Canonical Class Name | Folder Name | Authentic Originals Total | Training Originals | Validation Originals (Total Images) | Test Originals (Total Images) | Augmented Training Samples |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Bacterial Blight** | `bacterial_blight` | 4 | 2 | 1 | 1 | 2,429 |
| **Cotton Leaf Curl Virus** | `curl_virus` | 4 | 2 | 1 | 1 | 2,429 |
| **Healthy Leaf** | `healthy_leaf` | 4 | 2 | 1 | 1 | 2,429 |
| **Herbicide Growth Damage** | `herbicide_damage` | 4 | 2 | 1 | 1 | 2,429 |
| **Leaf Hopper / Jassids** | `leaf_hopper_jassids` | 4 | 2 | 1 | 1 | 2,428 |
| **Leaf Reddening** | `leaf_reddening` | 4 | 2 | 1 | 1 | 2,428 |
| **Leaf Variegation** | `leaf_variegation` | 4 | 2 | 1 | 1 | 2,428 |
| **TOTAL** | *7 classes* | **28** | **14** | **7** | **7** | **17,000** |

---

## 4. Methodological & Evaluation Consequences

1. **Heavy Augmentation from 14 Seed Samples**:
   The 17,000 training images in `dataset/augmented/train` were synthesized through automated data augmentation (rotation, CLAHE, color jitter, blurring, perspective shifts) derived from **only 14 distinct real-world leaf captures** (2 seed images per class). They cannot introduce authentic real-world biological variance, diverse growth stages, distinct cultivars, or varied field lighting.

2. **Evaluation Sample Size Limitation**:
   The validation split consists of **only 7 images total** (1 image per class).  
   The test split consists of **only 7 images total** (1 image per class).  
   Therefore, each test classification represents **14.28% (1 / 7)** of the total score.

3. **Correction of Accuracy Claims**:
   The benchmark score of **57.14%** must strictly be reported as:  
   > **"57.14% accuracy on a 7-image test split."**  
   It must **never** be cited as "57.14% SAR-CLD-2024 accuracy", because the authentic SAR-CLD-2024 dataset was not available for training or evaluation.

---

## 5. Documentation & Download Source Findings

- **Text Search Scope**: All markdown (`.md`), python (`.py`), text (`.txt`), YAML (`.yaml`), JSON (`.json`), and Dart (`.dart`) files in `E:\project\kushi`.
- **References Found**:
  - The phrase `SAR-CLD-2024` was cited only in the architecture docstrings based on the user's project prompt.
  - **No external download URL, Kaggle dataset slug, Zenodo DOI, HuggingFace repository link, or cloud storage bucket link** is documented anywhere in the workspace.
- **Archive Search Scope**: Scanned for `.zip`, `.7z`, `.rar`, `.tar`, `.gz`, `.tgz`. Zero dataset archives exist (only Android Gradle native symbols and lint caches).

---

## 6. Recommended Next Actions for Authentic Dataset Recovery

1. **User Provisioning of Authentic SAR-CLD-2024 Dataset**:
   The user / project owner must copy or download the authentic SAR-CLD-2024 dataset (or provide its official download URL / archive) into the project workspace (e.g. `dataset/raw/SAR-CLD-2024/`).
2. **Re-Execution of Preprocessing & Split**:
   Once the true collection of ~14,000+ authentic images is placed in the workspace:
   - Perform class-stratified Train / Val / Test splitting (e.g. 70% / 15% / 15%).
   - Validate image integrity, resolutions, and ground-truth labels.
3. **Model Re-Training & Honest Academic Evaluation**:
   Re-train the Hybrid CLAHE + CBAM MobileNetV2 architecture on authentic training data and evaluate on hundreds or thousands of authentic holdout test images to establish statistically valid performance metrics.
