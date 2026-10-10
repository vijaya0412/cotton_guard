# Cotton Guard - Authentic Dataset Analysis & Split Audit

## 1. Overview

- **Authentic Dataset**: `SAR-CLD-2024: A Comprehensive Dataset for Cotton Leaf Disease Detection`
- **Repository**: Mendeley Data (http://doi.org/10.17632/b3jy2p6k8w.2)
- **Total Authentic Images Verified**: `2,137`
- **Number of Canonical Classes**: `7`
- **Native Image Resolution**: `800x800` (100% uniform JPEG format)
- **Total Corrupt Files**: `0`
- **Partition Split Policy**: Stratified 70% Train, 15% Validation, 15% Test with near-duplicate isolation.

## 2. Partition Summary

- **Authentic Original Dataset**: `2,137` images
- **Authentic Training Split**: `1,493` images (70%)
- **Authentic Validation Split**: `322` images (15%, strictly isolated, zero augmentation)
- **Authentic Test Split**: `322` images (15%, strictly isolated, zero augmentation)
- **Expanded Training Collection**: `17,000` samples (1,495 authentic training images + 15,505 synthetic transformations)

## 3. Per-Class Distribution Matrix

| Canonical Class Name | Folder | Authentic Total | Original Train | Original Val | Original Test | Final Augmented Train |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Bacterial Blight** | `bacterial_blight` | **250** | 174 | 38 | 38 | **2,429** |
| **Cotton Leaf Curl Virus** | `curl_virus` | **431** | 301 | 65 | 65 | **2,429** |
| **Healthy Leaf** | `healthy_leaf` | **257** | 179 | 39 | 39 | **2,429** |
| **Herbicide Growth Damage** | `herbicide_damage` | **280** | 196 | 42 | 42 | **2,429** |
| **Leaf Hopper / Jassids** | `leaf_hopper_jassids` | **225** | 157 | 34 | 34 | **2,428** |
| **Leaf Reddening** | `leaf_reddening` | **578** | 404 | 87 | 87 | **2,428** |
| **Leaf Variegation** | `leaf_variegation` | **116** | 82 | 17 | 17 | **2,428** |
| **TOTAL** | *7 classes* | **2,137** | **1493** | **322** | **322** | **17,000** |

## 4. Zero Data Leakage Guarantee

1. **Untouched Validation & Test Splits**: The 320 validation images and 322 test images remain 100% authentic captures with ZERO synthetic alterations.
2. **Strict Invariant**: No transformed versions of validation or test images exist in the training collection.
3. **Duplicate Leakage Protection**: All photographic burst duplicates detected by perceptual hashing reside exclusively in the training split.