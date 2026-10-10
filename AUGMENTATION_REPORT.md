# Cotton Guard - Training Augmentation Report

## 1. Executive Summary

- **Authentic Source**: SAR-CLD-2024 Mendeley Data (http://doi.org/10.17632/b3jy2p6k8w.2)
- **Seed Training Images**: `1,495` authentic training leaf captures
- **Total Generated Training Samples**: `17,000` samples
- **Synthetic Samples Produced**: `15,505` samples
- **Validation & Test Sets**: 100% authentic (320 validation, 322 test); ZERO synthetic transformations applied.
- **Metadata Provenance**: Complete log saved in `dataset/augmented/augmentation_metadata.csv`.

## 2. Transformation Taxonomy

All transforms are biologically and photographically consistent with cotton field conditions:
1. **Rotation**: CW / CCW random rotations within [-35°, +35°].
2. **Flipping**: Horizontal and vertical reflections.
3. **Illumination Factor**: Brightness scaling [0.75, 1.25] to simulate variable sun/cloud conditions.
4. **Contrast & Saturation**: Factor [1.1, 1.35] modeling morning vs midday sunlight.
5. **Sensor Defocus**: Gaussian blurring (radius 0.5-1.0 px) modeling hand jitter.
6. **CIELAB-CLAHE**: Histogram equalization simulating automated hybrid camera ISP preprocessing.
7. **Perspective Warp**: Simulating varied phone capture pitch and roll angles in the field.
8. **Sensor Thermal Noise**: Zero-mean Gaussian noise modeling low-light CMOS sensor gain.

## 3. Per-Class Sampling Breakdown

| Canonical Class Name | Folder | Authentic Train Seeds | Generated Synthetic | Final Total Training Samples |
| :--- | :--- | :--- | :--- | :--- |
| **Bacterial Blight** | `bacterial_blight` | 174 | 2255 | **2,429** |
| **Cotton Leaf Curl Virus** | `curl_virus` | 301 | 2128 | **2,429** |
| **Healthy Leaf** | `healthy_leaf` | 179 | 2250 | **2,429** |
| **Herbicide Growth Damage** | `herbicide_damage` | 196 | 2233 | **2,429** |
| **Leaf Hopper / Jassids** | `leaf_hopper_jassids` | 157 | 2271 | **2,428** |
| **Leaf Reddening** | `leaf_reddening` | 404 | 2024 | **2,428** |
| **Leaf Variegation** | `leaf_variegation` | 82 | 2346 | **2,428** |
| **TOTAL** | *7 classes* | **1493** | **15507** | **17,000** |