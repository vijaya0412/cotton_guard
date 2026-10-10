# Cotton Guard - Academic Model Comparison Report on Authentic SAR-CLD-2024

## 1. Specification & Proposed Algorithm

- **Dataset**: `SAR-CLD-2024: A Comprehensive Dataset for Cotton Leaf Disease Detection` (Mendeley Data, DOI: 10.17632/b3jy2p6k8w.2)
- **Total Authentic Original Dataset**: `2,137` images across 7 canonical classes
- **Partition Methodology**: Stratified 70% Train (1,493), 15% Validation (322), 15% Test (322) with near-duplicate isolation
- **Untouched Holdout Test Set**: `322` authentic images (statistically valid zero-leakage evaluation)
- **Augmented Training Collection**: `17,000` samples synthesized strictly from the 1,493 training seeds
- **Proposed Academic Architecture**: `MobileNetV2 + Hybrid Preprocessing (CIELAB-CLAHE) + CBAM Attention`
- **Base Feature Extractor**: `MobileNetV2` (Pretrained on ImageNet-1k, fine-tuned on SAR-CLD-2024)
- **Attention Modules**: `CBAM` (Sequential Channel Attention via AvgPool+MaxPool Shared MLP, followed by Spatial Attention via 7x7 Conv)
- **Hybrid Preprocessing**: `CIELAB-CLAHE` (Contrast-Limited Adaptive Histogram Equalization on Luminance channel, clipLimit=2.0, tileGridSize=8x8)
- **Training Strategy**: Two-stage transfer learning (Stage 1 Linear Warmup on classification head + Stage 2 Top Bottleneck Fine-Tuning)
- **Inference Engine**: `ONNX Runtime` CPU Execution Provider with dynamic batch dimensions

---

## 2. Model Comparison Matrix (Evaluated on 322 Authentic Test Images)

| Model Configuration | Preprocessing | Attention Module | Accuracy | Macro F1 | Balanced Accuracy | Precision | Recall | Parameters | Model Size | CPU Latency | Selected |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A. MobileNetV2 Baseline** | Pipeline A (Standard RGB) | None | 61.49% | 0.6082 | 61.20% | 63.85% | 61.20% | 2,232,839 | 8.52 MB | 6.82 ms | No |
| **B. MobileNetV2 + Hybrid Preprocessing** | Pipeline B (CIELAB-CLAHE) | None | 63.66% | 0.6315 | 63.80% | 66.12% | 63.80% | 2,232,839 | 8.52 MB | 7.15 ms | No |
| **C. MobileNetV2 + CBAM Attention** | Pipeline A (Standard RGB) | CBAM | 64.29% | 0.6450 | 64.92% | 68.30% | 64.92% | 2,437,737 | 9.30 MB | 8.21 ms | No |
| **D. MobileNetV2 + Hybrid CLAHE + CBAM (Proposed)** | Pipeline B (CIELAB-CLAHE) | CBAM | **66.77%** | **0.6738** | **71.90%** | **71.40%** | **71.90%** | 2,437,737 | 9.30 MB | 7.88 ms | **YES (Production)** |

> [!NOTE]
> The proposed architecture (D) achieves the highest Macro F1 (0.6738) and balanced accuracy (71.90%), confirming that the combination of CIELAB-CLAHE contrast normalization on the luminance channel and CBAM spatial/channel attention provides superior feature representation across variable field lighting.

---

## 3. Per-Class Detailed Performance for Proposed Model (`MobileNetV2 + Hybrid CLAHE + CBAM`)

Evaluated strictly on the 322 authentic holdout test images with zero augmentation leakage:

| Canonical Class Name | Precision | Recall | F1-Score | Support (Authentic Test Images) |
| :--- | :--- | :--- | :--- | :--- |
| **Bacterial Blight** | 44.2% | 89.5% | 0.591 | 38 |
| **Cotton Leaf Curl Virus** | 67.8% | 61.5% | 0.645 | 65 |
| **Healthy Leaf** | 59.3% | 82.1% | 0.688 | 39 |
| **Herbicide Growth Damage** | 84.0% | 100.0% | 0.913 | 42 |
| **Leaf Hopper / Jassids** | 83.3% | 29.4% | 0.435 | 34 |
| **Leaf Reddening** | 85.4% | 47.1% | 0.607 | 87 |
| **Leaf Variegation** | 76.2% | 94.1% | 0.842 | 17 |
| **Macro Average** | **71.4%** | **71.9%** | **0.674** | **322** |
| **Weighted Average** | **73.2%** | **66.8%** | **0.663** | **322** |

---

## 4. Confusion Matrix (`MobileNetV2 + Hybrid CLAHE + CBAM`)

```
                          Predicted Classes
               BB   CLCuV   HL   HGD   LHJ   LR   LV
BB   (38)   [[ 34     1     2     0     0    1    0 ]
CLCuV(65)    [  3    40     8     8     1    4    1 ]
HL   (39)    [  6     0    32     0     1    0    0 ]
HGD  (42)    [  0     0     0    42     0    0    0 ]
LHJ  (34)    [  8     2    11     0    10    2    1 ]
LR   (87)    [ 27    15     1     0     0   41    3 ]
LV   (17)    [  0     1     0     0     0    0   16 ]]
```

### Agronomic Analysis of Errors:
1. **Herbicide Growth Damage**: Achieved perfect recall (42/42, 100%) due to distinctive epinasty and strap-like venation deformities.
2. **Leaf Variegation**: High recall (16/17, 94.1%) due to sharp chimeric plastid pigment boundaries.
3. **Leaf Reddening vs Bacterial Blight**: 27 reddened leaves were confused with bacterial blight spots where late-season reddening co-occurred with necrotic angular lesions.
4. **Leaf Hopper / Jassids**: Marginal hopper burn chlorosis overlaps visually with early-stage bacterial leaf edge necrosis and healthy foliage.

---

## 5. Reference Model vs Production ONNX Parity

- **Tested Images**: 100 authentic holdout test images from SAR-CLD-2024
- **Class Prediction Agreement**: **100.0%** (100 / 100 exact matches)
- **Maximum Output Probability Divergence**: `0.00000241` (2.41e-6)
- **Mean Output Probability Divergence**: `0.00000049` (4.90e-7)
- **Reference PyTorch CPU Latency**: 49.51 ms
- **Production ONNX Runtime CPU Latency**: **8.73 ms** (5.6x speedup)
- **Status**: Production deployment fully validated.