# Cotton Guard - Authentic SAR-CLD-2024 Dataset Audit Report

**Dataset Title**: SAR-CLD-2024: A Comprehensive Dataset for Cotton Leaf Disease Detection  
**Official Source**: Mendeley Data (http://doi.org/10.17632/b3jy2p6k8w.2)  
**Authors**: Prayma Bishshash, Md Asraful Sharker Nirob, Md. Habibur Shikder, Afjal Sarower  
**Institution**: Daffodil International University & National Cotton Research Institute field in Gazipur, Bangladesh  
**Hardware Used for Acquisition**: Redmi Note 11s Smartphone (October 2023 – January 2024)  
**Archive Checksum**: SHA-256 `cb4f662985a33831e92d37644fe6092e76be321dd6b4bf443e65f9ae130d137a` (Verified)  
**Audit Date**: October 8, 2026  

---

## 1. Verified Inventory Metrics

- **Total Authentic Original Images**: **2,137**
- **Expected Published Count**: `2,137`
- **Count Concordance**: **100% Match (2,137 / 2,137)**
- **Corrupted / Invalid Files**: **0** (100% valid images)
- **Primary Image Formats**: {'JPEG': 2137}
- **Minimum Resolution**: `800x800`
- **Maximum Resolution**: `800x800`
- **Average Resolution**: `800x800`
- **Exact Cryptographic Duplicates**: `5` clusters
- **Perceptual Near-Duplicates**: `5` clusters

---

## 2. Canonical Class Mapping & Distribution

| Canonical Class Name | Raw Dataset Folder | Original Count | Share (%) | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Bacterial Blight** | `Bacterial Blight` | **250** | 11.7% | Verified Authentic |
| **Cotton Leaf Curl Virus** | `Curl Virus` | **431** | 20.2% | Verified Authentic |
| **Healthy Leaf** | `Healthy Leaf` | **257** | 12.0% | Verified Authentic |
| **Herbicide Growth Damage** | `Herbicide Growth Damage` | **280** | 13.1% | Verified Authentic |
| **Leaf Hopper / Jassids** | `Leaf Hopper Jassids` | **225** | 10.5% | Verified Authentic |
| **Leaf Reddening** | `Leaf Redding` | **578** | 27.0% | Verified Authentic |
| **Leaf Variegation** | `Leaf Variegation` | **116** | 5.4% | Verified Authentic |

---

## 3. Data Integrity & Leakage Prevention Rules

1. **Untouched Ground-Truth Preservation**: The raw files in `dataset/raw/SAR-CLD-2024/` remain completely untouched as an immutable ground-truth repository.
2. **Near-Duplicate Cross-Split Isolation**: Perceptually identical captures from the same photo burst are assigned to the same split group to prevent train-test data leakage.
3. **Partition Stratification**: Splitting maintains identical class proportions across Train (70%), Validation (15%), and Test (15%).
