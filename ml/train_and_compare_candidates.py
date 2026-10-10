"""
Cotton Guard - Scientific Model Comparison & Optimization Pipeline.
Compares:
1. Baseline: MobileNetV2 (Standard Linear Head)
2. Proposed Architecture: MobileNetV2 + CBAM Attention
3. Alternative 1: MobileNetV3-Large + CBAM Attention
4. Alternative 2: EfficientNet-B0 (Pretrained)
5. Loss Function Ablation: Standard CrossEntropy vs Class-Weighted vs Focal Loss

Protocol:
- Training on dataset/split/train (1,493 authentic images) with data augmentation
- Model selection and hyperparameter tuning strictly on dataset/split/val (322 images)
- Untouched holdout test set (322 images) evaluated only for final comparison
"""

import os
import sys
import time
import json
import random
from collections import defaultdict
import numpy as np
from PIL import Image
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import torchvision.models as models
import torchvision.transforms.functional as TF
from sklearn.metrics import accuracy_score, balanced_accuracy_score, precision_score, recall_score, f1_score, classification_report

# Ensure project root is in path
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)
from ml.classes import CANONICAL_CLASSES, CLASS_TO_FOLDER, FOLDER_TO_CLASS
from ml.preprocessing import preprocess_image, DEFAULT_IMAGE_SIZE
from ml.cbam import CBAM, MobileNetV2CBAM

# Set random seeds for reproducibility
def set_seed(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

set_seed(42)

# --- 1. MODEL ARCHITECTURES ---

class MobileNetV2Standard(nn.Module):
    def __init__(self, num_classes=7):
        super().__init__()
        base = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)
        self.features = base.features
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(base.last_channel, num_classes)
        )
    def forward(self, x):
        x = self.features(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class MobileNetV3LargeCBAM(nn.Module):
    def __init__(self, num_classes=7):
        super().__init__()
        base = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.DEFAULT)
        self.features = base.features  # output: 960 channels
        self.cbam = CBAM(in_planes=960, ratio=16)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(960, 1280),
            nn.Hardswish(),
            nn.Dropout(p=0.2),
            nn.Linear(1280, num_classes)
        )
    def forward(self, x):
        x = self.features(x)
        x = self.cbam(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class EfficientNetB0Model(nn.Module):
    def __init__(self, num_classes=7):
        super().__init__()
        base = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        self.features = base.features
        self.gap = nn.AdaptiveAvgPool2d(1)
        in_feats = base.classifier[1].in_features  # 1280
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(in_feats, num_classes)
        )
    def forward(self, x):
        x = self.features(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)


# --- 2. FOCAL LOSS & WEIGHTED LOSS ---

class FocalLoss(nn.Module):
    def __init__(self, alpha=None, gamma=2.0):
        super().__init__()
        self.alpha = alpha
        self.gamma = gamma
        self.ce = nn.CrossEntropyLoss(reduction="none")

    def forward(self, inputs, targets):
        ce_loss = self.ce(inputs, targets)
        pt = torch.exp(-ce_loss)
        focal_loss = ((1.0 - pt) ** self.gamma) * ce_loss
        if self.alpha is not None:
            alpha_t = self.alpha[targets]
            focal_loss = alpha_t * focal_loss
        return focal_loss.mean()


# --- 3. IN-MEMORY DATASET WITH DYNAMIC AUGMENTATION ---

def load_split_tensors(split_dir):
    """Loads and pre-caches preprocessed tensors in RAM for rapid CPU experimentation."""
    tensors = []
    labels = []
    paths = []
    
    for c_idx, c_name in enumerate(CANONICAL_CLASSES):
        folder = CLASS_TO_FOLDER[c_name]
        c_dir = os.path.join(split_dir, folder)
        if not os.path.isdir(c_dir):
            continue
        for fname in sorted(os.listdir(c_dir)):
            if fname.lower().endswith(('.jpg', '.jpeg', '.png')):
                p = os.path.join(c_dir, fname)
                try:
                    pil_img = Image.open(p).convert("RGB")
                    # Canonical hybrid CLAHE preprocessing
                    np_t = preprocess_image(pil_img, enable_clahe=True, layout="NCHW")[0]
                    tensors.append(torch.from_numpy(np_t))
                    labels.append(c_idx)
                    paths.append(p)
                except Exception as e:
                    print(f"Error loading {p}: {e}")
                    
    return torch.stack(tensors), torch.tensor(labels, dtype=torch.long), paths


class InMemoryAugmentedDataset(Dataset):
    def __init__(self, tensors, labels, is_train=True):
        self.tensors = tensors
        self.labels = labels
        self.is_train = is_train

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        x = self.tensors[idx]
        y = self.labels[idx]

        if self.is_train:
            # Random horizontal flip (p=0.5)
            if random.random() > 0.5:
                x = torch.flip(x, dims=[2])
            # Random vertical flip (p=0.3)
            if random.random() > 0.7:
                x = torch.flip(x, dims=[1])
            # Random 90-degree rotation (p=0.5)
            rot_k = random.choice([0, 1, 2, 3])
            if rot_k > 0:
                x = torch.rot90(x, k=rot_k, dims=[1, 2])

        return x, y


# --- 4. EVALUATION HELPER ---

def evaluate_model(model, data_loader):
    model.eval()
    y_true, y_pred = [], []
    latencies = []

    with torch.no_grad():
        for x, y in data_loader:
            t0 = time.perf_counter()
            logits = model(x)
            t1 = time.perf_counter()
            latencies.append((t1 - t0) * 1000.0 / len(y))

            probs = torch.softmax(logits, dim=1).numpy()
            preds = np.argmax(probs, axis=1)
            y_true.extend(y.numpy().tolist())
            y_pred.extend(preds.tolist())

    acc = float(accuracy_score(y_true, y_pred))
    bal_acc = float(balanced_accuracy_score(y_true, y_pred))
    p_macro = float(precision_score(y_true, y_pred, average="macro", zero_division=0))
    r_macro = float(recall_score(y_true, y_pred, average="macro", zero_division=0))
    f1_macro = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    rep = classification_report(y_true, y_pred, target_names=CANONICAL_CLASSES, output_dict=True, zero_division=0)

    return {
        "accuracy": acc,
        "balanced_accuracy": bal_acc,
        "macro_precision": p_macro,
        "macro_recall": r_macro,
        "macro_f1": f1_macro,
        "mean_latency_ms": float(np.mean(latencies)),
        "report": rep,
        "y_true": y_true,
        "y_pred": y_pred
    }


# --- 5. TRAINING RUNNER ---

def train_candidate(
    model,
    train_loader,
    val_loader,
    loss_fn,
    unfreeze_layers_fn=None,
    epochs_stage1=8,
    epochs_stage2=10,
    lr_stage1=1e-3,
    lr_stage2=1e-4,
    weight_decay=1e-4
):
    # Stage 1: Freeze features backbone, train head & attention
    for p in model.parameters():
        p.requires_grad = False

    # Unfreeze head and attention
    if hasattr(model, 'cbam'):
        for p in model.cbam.parameters():
            p.requires_grad = True
    for p in model.classifier.parameters():
        p.requires_grad = True

    opt1 = torch.optim.AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=lr_stage1,
        weight_decay=weight_decay
    )
    sched1 = torch.optim.lr_scheduler.CosineAnnealingLR(opt1, T_max=epochs_stage1, eta_min=1e-5)

    best_val_f1 = 0.0
    best_state = None

    print(f"  [Stage 1] Head & Attention Warmup ({epochs_stage1} epochs)...")
    for ep in range(epochs_stage1):
        model.train()
        train_loss = 0.0
        n_samples = 0
        for x, y in train_loader:
            opt1.zero_grad()
            out = model(x)
            loss = loss_fn(out, y)
            loss.backward()
            opt1.step()
            train_loss += loss.item() * len(y)
            n_samples += len(y)
        sched1.step()

        val_metrics = evaluate_model(model, val_loader)
        if val_metrics["macro_f1"] > best_val_f1:
            best_val_f1 = val_metrics["macro_f1"]
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}

        if (ep + 1) % 2 == 0 or (ep + 1) == epochs_stage1:
            print(f"    Ep {ep+1:2d}/{epochs_stage1} | Loss: {train_loss/n_samples:.4f} | Val Acc: {val_metrics['accuracy']*100:.1f}% | Val F1: {val_metrics['macro_f1']:.4f}")

    # Restore best from stage 1
    if best_state is not None:
        model.load_state_dict(best_state)

    # Stage 2: Fine-Tuning Top Convolutional Layers
    if unfreeze_layers_fn is not None and epochs_stage2 > 0:
        unfreeze_layers_fn(model)
        opt2 = torch.optim.AdamW(
            filter(lambda p: p.requires_grad, model.parameters()),
            lr=lr_stage2,
            weight_decay=weight_decay
        )
        sched2 = torch.optim.lr_scheduler.CosineAnnealingLR(opt2, T_max=epochs_stage2, eta_min=1e-6)

        print(f"  [Stage 2] Top Layers Fine-Tuning ({epochs_stage2} epochs)...")
        for ep in range(epochs_stage2):
            model.train()
            train_loss = 0.0
            n_samples = 0
            for x, y in train_loader:
                opt2.zero_grad()
                out = model(x)
                loss = loss_fn(out, y)
                loss.backward()
                opt2.step()
                train_loss += loss.item() * len(y)
                n_samples += len(y)
            sched2.step()

            val_metrics = evaluate_model(model, val_loader)
            if val_metrics["macro_f1"] > best_val_f1:
                best_val_f1 = val_metrics["macro_f1"]
                best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}

            if (ep + 1) % 2 == 0 or (ep + 1) == epochs_stage2:
                print(f"    Ep {ep+1:2d}/{epochs_stage2} | Loss: {train_loss/n_samples:.4f} | Val Acc: {val_metrics['accuracy']*100:.1f}% | Val F1: {val_metrics['macro_f1']:.4f}")

    if best_state is not None:
        model.load_state_dict(best_state)

    final_val = evaluate_model(model, val_loader)
    return model, final_val


# --- 6. MAIN EXPERIMENT CONTROLLER ---

def unfreeze_mobilenetv2_top(model):
    # Unfreeze last 4 bottleneck blocks (features[14:])
    for block in model.features[14:]:
        for p in block.parameters():
            p.requires_grad = True

def unfreeze_mobilenetv3_top(model):
    # Unfreeze last 4 blocks (features[12:])
    for block in model.features[12:]:
        for p in block.parameters():
            p.requires_grad = True

def unfreeze_efficientnet_top(model):
    # Unfreeze last 2 stages (features[6:])
    for block in model.features[6:]:
        for p in block.parameters():
            p.requires_grad = True


def main():
    print("=" * 70)
    print("COTTON GUARD - ARCHITECTURAL COMPARISON & ABLATION STUDY")
    print("=" * 70)

    # 1. Load authentic datasets into RAM
    train_dir = os.path.join(BASE_DIR, "dataset", "split", "train")
    val_dir = os.path.join(BASE_DIR, "dataset", "split", "val")
    test_dir = os.path.join(BASE_DIR, "dataset", "split", "test")

    print("[Data Loading] Caching 1,493 authentic training images into RAM...")
    train_tensors, train_labels, _ = load_split_tensors(train_dir)
    print(f"  -> Train Tensor Shape: {train_tensors.shape}")

    print("[Data Loading] Caching 322 authentic validation images into RAM...")
    val_tensors, val_labels, _ = load_split_tensors(val_dir)
    print(f"  -> Val Tensor Shape: {val_tensors.shape}")

    # Compute balanced class weights for loss function
    class_counts = torch.bincount(train_labels, minlength=7).float()
    total_samples = len(train_labels)
    class_weights = total_samples / (7.0 * class_counts)
    print(f"[Class Weights] { {CANONICAL_CLASSES[i]: round(float(class_weights[i]), 3) for i in range(7)} }")

    train_ds = InMemoryAugmentedDataset(train_tensors, train_labels, is_train=True)
    val_ds = InMemoryAugmentedDataset(val_tensors, val_labels, is_train=False)

    train_loader = DataLoader(train_ds, batch_size=32, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=32, shuffle=False)

    # Loss Functions
    standard_ce = nn.CrossEntropyLoss()
    weighted_ce = nn.CrossEntropyLoss(weight=class_weights)
    focal_loss = FocalLoss(alpha=class_weights, gamma=1.5)

    candidates = [
        {
            "id": "exp1_mobilenetv2_baseline",
            "name": "MobileNetV2 Baseline (Standard CrossEntropy)",
            "model_builder": lambda: MobileNetV2Standard(num_classes=7),
            "loss_fn": standard_ce,
            "unfreeze_fn": unfreeze_mobilenetv2_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        },
        {
            "id": "exp2_mobilenetv2_cbam_standard_loss",
            "name": "MobileNetV2 + CBAM (Standard CrossEntropy)",
            "model_builder": lambda: MobileNetV2CBAM(num_classes=7, pretrained=True),
            "loss_fn": standard_ce,
            "unfreeze_fn": unfreeze_mobilenetv2_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        },
        {
            "id": "exp3_mobilenetv2_cbam_weighted_loss",
            "name": "MobileNetV2 + CBAM (Class-Weighted Loss)",
            "model_builder": lambda: MobileNetV2CBAM(num_classes=7, pretrained=True),
            "loss_fn": weighted_ce,
            "unfreeze_fn": unfreeze_mobilenetv2_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        },
        {
            "id": "exp4_mobilenetv2_cbam_focal_loss",
            "name": "MobileNetV2 + CBAM (Focal Loss gamma=1.5)",
            "model_builder": lambda: MobileNetV2CBAM(num_classes=7, pretrained=True),
            "loss_fn": focal_loss,
            "unfreeze_fn": unfreeze_mobilenetv2_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        },
        {
            "id": "exp5_mobilenetv3_large_cbam",
            "name": "MobileNetV3-Large + CBAM (Class-Weighted Loss)",
            "model_builder": lambda: MobileNetV3LargeCBAM(num_classes=7),
            "loss_fn": weighted_ce,
            "unfreeze_fn": unfreeze_mobilenetv3_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        },
        {
            "id": "exp6_efficientnet_b0",
            "name": "EfficientNet-B0 (Class-Weighted Loss)",
            "model_builder": lambda: EfficientNetB0Model(num_classes=7),
            "loss_fn": weighted_ce,
            "unfreeze_fn": unfreeze_efficientnet_top,
            "epochs_s1": 8,
            "epochs_s2": 8
        }
    ]

    experiment_results = []
    trained_models = {}

    for cand in candidates:
        cand_name = cand["name"]
        print(f"\n" + "-" * 60)
        print(f"RUNNING EXPERIMENT: {cand_name}")
        print("-" * 60)

        set_seed(42)
        model = cand["model_builder"]()
        n_params = sum(p.numel() for p in model.parameters())

        t_start = time.time()
        trained_model, val_metrics = train_candidate(
            model=model,
            train_loader=train_loader,
            val_loader=val_loader,
            loss_fn=cand["loss_fn"],
            unfreeze_layers_fn=cand["unfreeze_fn"],
            epochs_stage1=cand["epochs_s1"],
            epochs_stage2=cand["epochs_s2"],
            lr_stage1=1e-3,
            lr_stage2=1e-4
        )
        elapsed = time.time() - t_start

        trained_models[cand["id"]] = trained_model

        rec_lhj = val_metrics["report"]["Leaf Hopper / Jassids"]["recall"]
        rec_lr = val_metrics["report"]["Leaf Reddening"]["recall"]
        rec_clcuv = val_metrics["report"]["Cotton Leaf Curl Virus"]["recall"]

        res_entry = {
            "id": cand["id"],
            "name": cand_name,
            "parameters": n_params,
            "training_time_s": round(elapsed, 1),
            "val_accuracy": round(val_metrics["accuracy"] * 100, 2),
            "val_balanced_accuracy": round(val_metrics["balanced_accuracy"] * 100, 2),
            "val_macro_precision": round(val_metrics["macro_precision"] * 100, 2),
            "val_macro_recall": round(val_metrics["macro_recall"] * 100, 2),
            "val_macro_f1": round(val_metrics["macro_f1"], 4),
            "val_latency_ms": round(val_metrics["mean_latency_ms"], 2),
            "val_recall_lhj": round(rec_lhj * 100, 1),
            "val_recall_lr": round(rec_lr * 100, 1),
            "val_recall_clcuv": round(rec_clcuv * 100, 1),
            "per_class_report": val_metrics["report"]
        }
        experiment_results.append(res_entry)

        print(f"\n  >>> RESULT for {cand_name}:")
        print(f"      Val Acc: {res_entry['val_accuracy']}% | Val Macro F1: {res_entry['val_macro_f1']} | Latency: {res_entry['val_latency_ms']} ms")
        print(f"      Weak Classes Recall -> LHJ: {res_entry['val_recall_lhj']}% | LR: {res_entry['val_recall_lr']}% | CLCuV: {res_entry['val_recall_clcuv']}%")

    # Save validation comparison log
    results_json_path = os.path.join(BASE_DIR, "ml", "candidates_validation_benchmark.json")
    with open(results_json_path, "w") as f:
        json.dump(experiment_results, f, indent=2)
    print(f"\n[Validation Benchmark] All experiment results saved to: {results_json_path}")

    # Rank and select best candidate based on validation Macro F1
    sorted_by_f1 = sorted(experiment_results, key=lambda x: x["val_macro_f1"], reverse=True)
    winner_info = sorted_by_f1[0]
    winner_id = winner_info["id"]
    winning_model = trained_models[winner_id]

    print("\n" + "=" * 70)
    print(f"WINNING CANDIDATE ON VALIDATION SET: {winner_info['name']}")
    print(f"Validation Macro F1: {winner_info['val_macro_f1']} | Validation Accuracy: {winner_info['val_accuracy']}%")
    print(f"LHJ Recall: {winner_info['val_recall_lhj']}% | LR Recall: {winner_info['val_recall_lr']}%")
    print("=" * 70)

    # Save winning PyTorch weights temporarily
    candidate_pt_path = os.path.join(BASE_DIR, "ml", "models", "best_candidate_model.pt")
    torch.save({
        "winner_id": winner_id,
        "name": winner_info["name"],
        "classes": CANONICAL_CLASSES,
        "state_dict": winning_model.state_dict(),
        "val_metrics": winner_info
    }, candidate_pt_path)
    print(f"Saved winning candidate model checkpoint: {candidate_pt_path}")


if __name__ == "__main__":
    main()
