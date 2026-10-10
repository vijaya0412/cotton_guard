# Cotton Guard — Disease Misclassification & Model Error Analysis Report

**Date & Time:** October 10, 2026  
**Auditor:** Senior Computer Vision & ML Research Team  
**Dataset:** SAR-CLD-2024: Cotton Leaf Disease Dataset (Mendeley Data DOI: 10.17632/b3jy2p6k8w.2)  
**Evaluation Scope:** 322 Authentic Holdout Test Images (Statistically Isolated, Zero-Leakage)  
**Baseline Model Artifact:** `ml/models/cotton_guard_model.onnx` (Pre-upgrade MobileNetV2 + CBAM)  

---

## 1. Executive Summary

A comprehensive diagnostic audit of the Cotton Guard disease classification pipeline was performed on the authentic **322-image holdout test split** to uncover why certain cotton leaves were frequently assigned incorrect disease labels.

### Key Audit Findings:
1. **The baseline production model misclassified 107 out of 322 test images (33.23% error rate)**, achieving only **66.77% overall accuracy** and a **macro-F1 score of 0.6738**.
2. **The two weakest disease categories were `Leaf Hopper / Jassids` (Recall: 29.4%) and `Leaf Reddening` (Recall: 47.1%)**.
3. **The most prevalent failure mode was `Leaf Reddening` being misdiagnosed as `Bacterial Blight` (27 occurrences)**, followed by `Leaf Reddening` mistaken for `Cotton Leaf Curl Virus` (15 occurrences), and `Leaf Hopper / Jassids` mistaken for `Healthy Leaf` (11 occurrences).
4. **Primary Root Causes Identified:**
   - **Severe Model Under-Training:** The initial training script only ran for 3 linear warmup epochs and 3 fine-tuning epochs (total 6 epochs) on an aggressively downsampled cohort of only 250 images per class (1,750 images total), preventing deep convolutional filters from converging on subtle discriminative features.
   - **Luminance Distortion & Double CLAHE:** Offline augmented images had CLAHE pre-applied; re-applying CIELAB-CLAHE during inference doubled contrast stretching, accentuating reddish anthocyanin pigments in `Leaf Reddening` to look visually identical to dark necrotic lesions of `Bacterial Blight`.
   - **Unweighted Loss Function on Subtle Symptoms:** `Leaf Hopper / Jassids` induces subtle marginal chlorosis and hopperburn. Without class-weighted loss, the network prioritized large structural distortions over subtle marginal color variations, defaulting to `Healthy Leaf`.
   - **Arbitrary Early Stopping:** The previous script saved weights at the final epoch without validation checkpointing, missing peak generalization checkpoints.

---

## 2. Baseline Model Performance Metrics (322 Untouched Test Images)

| Metric | Baseline Score | Evaluation Notes |
|---|---|---|
| **Overall Accuracy** | **66.77%** | 215 correct, 107 misclassified |
| **Balanced Accuracy** | **71.96%** | Macro average of per-class recalls |
| **Macro Precision** | **71.37%** | Heavily penalized by Bacterial Blight false positives |
| **Macro Recall** | **71.96%** | Degraded by poor LHJ and Leaf Reddening sensitivity |
| **Macro F1-Score** | **0.6738** | Baseline benchmark |
| **Weighted F1-Score** | **0.6560** | Weighted by authentic test support distribution |
| **Mean Inference Latency** | **8.73 ms** | ONNX Runtime CPU Execution Provider |

---

## 3. Baseline Per-Class Diagnostic Breakdown

| Canonical Class Name | Precision | Recall | F1-Score | Support | Primary Confusion Mode |
|---|---|---|---|---|---|
| **Bacterial Blight** | 43.6% | 89.5% | 0.586 | 38 | False Positives from Leaf Reddening (27) & LHJ (8) |
| **Cotton Leaf Curl Virus** | 67.8% | 61.5% | 0.645 | 65 | Mistaken for Healthy Leaf (8) & Herbicide (8) |
| **Healthy Leaf** | 59.3% | 82.1% | 0.688 | 39 | Mistaken for Bacterial Blight (6) |
| **Herbicide Growth Damage** | 84.0% | **100.0%** | 0.913 | 42 | No false negatives (strong morphological cues) |
| **Leaf Hopper / Jassids** | 83.3% | **29.4%** | **0.435** | 34 | **Severe failure: 70.6% missed** (mistaken for HL) |
| **Leaf Reddening** | 85.4% | **47.1%** | **0.607** | 87 | **Severe failure: 52.9% missed** (mistaken for BB & CLCuV) |
| **Leaf Variegation** | 76.2% | 94.1% | 0.842 | 17 | Robust white/cream mosaic patterns |

---

## 4. Baseline Confusion Matrix (Untouched Test Set)

```
                            PREDICTED CLASS
True Class       BB   CLCuV   HL   HGD   LHJ   LR   LV   Total
--------------------------------------------------------------
Bacterial Blight [ 34     1     2     0     0    1    0 ]   38
Curl Virus       [  3    40     8     8     1    4    1 ]   65
Healthy Leaf     [  6     0    32     0     1    0    0 ]   39
Herbicide Damage [  0     0     0    42     0    0    0 ]   42
LHJ (Jassids)    [  8     2    11     0    10    2    1 ]   34
Leaf Reddening   [ 27    15     1     0     0   41    3 ]   87
Leaf Variegation [  0     1     0     0     0    0   16 ]   17
--------------------------------------------------------------
Total Predicted:   78    59    54    50    12   48   21    322
```

---

## 5. Most Frequent Misclassification Pairs

| Rank | True Condition | Misclassified As | Count | Root Cause & Visual Pathology |
|---|---|---|---|---|
| **#1** | **Leaf Reddening** | **Bacterial Blight** | **27** | CIELAB-CLAHE contrast stretching darkened reddish anthocyanin leaf veins, creating high-contrast patches that closely mimicked angular necrotic lesions of Bacterial Blight. |
| **#2** | **Leaf Reddening** | **Cotton Leaf Curl Virus** | **15** | Late-stage reddening often accompanies leaf cupping and edge curling, triggering Begomovirus feature activations in under-trained models. |
| **#3** | **Leaf Hopper / Jassids** | **Healthy Leaf** | **11** | Nymph feeding causes marginal leaf edge hopperburn; when the bulk of the blade remains green, an unweighted classifier prioritizes the dominant green surface. |
| **#4** | **Cotton Leaf Curl Virus** | **Healthy Leaf** | **8** | Mild upward cupping in early-stage begomovirus lacks the severe vein thickening of late-stage disease, appearing largely green. |
| **#5** | **Cotton Leaf Curl Virus** | **Herbicide Growth Damage** | **8** | Both conditions cause severe leaf warping, downward epinasty, and strap-like leaf distortions, confusing linear decision boundaries. |
| **#6** | **Leaf Hopper / Jassids** | **Bacterial Blight** | **8** | Advanced hopperburn produces necrotic brown leaf margins that the network confused with vein blight. |
| **#7** | **Healthy Leaf** | **Bacterial Blight** | **6** | Normal shadow gradients and soil specks on healthy leaves were amplified by CLAHE into pseudo-necrotic spots. |

---

## 6. Representative Misclassified Image Gallery

The table below documents specific authentic test images from `dataset/split/test` that failed under the baseline model:

| Image File | True Label | Baseline Prediction | Confidence | Top-3 Ranked Candidates | Agronomic Cause |
|---|---|---|---|---|---|
| `LR00001.jpg` | Leaf Reddening | Cotton Leaf Curl Virus | 75.9% | CLCuV: 75.9%, LV: 14.8%, LR: 8.0% | Upward leaf edge curling overshadowed anthocyanin reddening. |
| `LR00002.jpg` | Leaf Reddening | Bacterial Blight | 34.4% | BB: 34.4%, LV: 33.9%, CLCuV: 25.0% | Necrotic-looking CLAHE vein contrast; ambiguous probability spread. |
| `LR00003.jpg` | Leaf Reddening | Leaf Variegation | 36.9% | LV: 36.9%, LR: 31.4%, BB: 19.6% | Pale red-yellow discoloration resembled genetic variegation patches. |
| `LR00006.jpg` | Leaf Reddening | Cotton Leaf Curl Virus | 41.1% | CLCuV: 41.1%, HL: 30.8%, LR: 11.3% | Margin leaf rolling confused with viral enation. |
| `LHJ00001.jpg` | Leaf Hopper / Jassids | Cotton Leaf Curl Virus | 77.8% | CLCuV: 77.8%, LV: 12.4%, HL: 6.4% | Marginal hopperburn induced leaf curling, triggering curl virus filters. |
| `LHJ00010.jpg` | Leaf Hopper / Jassids | Healthy Leaf | 99.6% | HL: 99.6%, LHJ: 0.2%, LR: 0.1% | Early hopperburn with subtle yellowing; classifier focused on green blade. |
| `LHJ00017.jpg` | Leaf Hopper / Jassids | Leaf Variegation | 58.9% | LV: 58.9%, CLCuV: 32.5%, LHJ: 3.0% | Bleached margin hopperburn mistaken for variegation chimera. |
| `CV00003.jpg` | Cotton Leaf Curl Virus | Healthy Leaf | 90.0% | HL: 90.0%, LR: 6.4%, CLCuV: 2.7% | Early upward cupping without thick veins; high green leaf percentage. |
| `CV00015.jpg` | Cotton Leaf Curl Virus | Healthy Leaf | 99.3% | HL: 99.3%, CLCuV: 0.4%, LHJ: 0.2% | Flat leaf appearance under overhead lighting. |
| `HL00163.jpg` | Healthy Leaf | Bacterial Blight | 82.9% | BB: 82.9%, HGD: 8.8%, HL: 4.5% | Dust particles and shadow artifacts accentuated by CLAHE filter. |

---

## 7. Confidence Calibration Analysis (Correct vs Misclassified)

To evaluate whether low confidence could be used to reject bad predictions, confidence distributions were calculated across all 322 test images:

| Category | Sample Count | Mean Confidence | Median Confidence | Min Conf | Max Conf | Std Dev |
|---|---|---|---|---|---|---|
| **Correct Predictions** | 215 | **89.08%** | **96.22%** | 33.07% | 100.0% | 0.1476 |
| **Incorrect Predictions** | 107 | **75.09%** | **80.31%** | 28.10% | 99.98% | 0.2096 |

### Observations:
- In the baseline model, many incorrect predictions still exhibited over 80% confidence (overconfident errors due to soft cross-entropy without focal modulation or class weighting).
- Rejecting at arbitrary thresholds like 50% only caught 1 error, while thresholding at 75% caught only 12 errors while discarding numerous valid predictions.
- **Conclusion:** Rejection thresholds alone cannot repair a fundamentally under-trained model. Improving the feature representation, balancing loss weights, and increasing training convergence was mandatory.
