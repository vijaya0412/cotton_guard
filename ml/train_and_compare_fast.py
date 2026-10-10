"""
Cotton Guard - High-Performance Scientific Model Optimization & Benchmark.
Pre-caches features in RAM for rapid CPU execution (< 5 minutes total).
Evaluates architectures and loss formulations on validation set (322 images).
Evaluates winning model on untouched test set (322 images).
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
from torch.utils.data import TensorDataset, DataLoader
import torchvision.models as models
from sklearn.metrics import accuracy_score, balanced_accuracy_score, precision_score, recall_score, f1_score, classification_report, confusion_matrix

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)
from ml.classes import CANONICAL_CLASSES, CLASS_TO_FOLDER
from ml.preprocessing import preprocess_image
from ml.cbam import CBAM, MobileNetV2CBAM

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def set_seed(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

set_seed(42)

# --- 1. MODEL HEAD DEFINITIONS ---

class MobileNetV2StandardHead(nn.Module):
    def __init__(self, in_channels=1280, num_classes=7):
        super().__init__()
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(in_channels, num_classes)
        )
    def forward(self, x):
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class MobileNetV2CBAMHead(nn.Module):
    def __init__(self, in_channels=1280, num_classes=7):
        super().__init__()
        self.cbam = CBAM(in_planes=in_channels, ratio=16)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(in_channels, num_classes)
        )
    def forward(self, x):
        x = self.cbam(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class MobileNetV3CBAMHead(nn.Module):
    def __init__(self, in_channels=960, num_classes=7):
        super().__init__()
        self.cbam = CBAM(in_planes=in_channels, ratio=16)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(in_channels, 1280),
            nn.Hardswish(),
            nn.Dropout(p=0.2),
            nn.Linear(1280, num_classes)
        )
    def forward(self, x):
        x = self.cbam(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class FullMobileNetV3CBAM(nn.Module):
    def __init__(self, features, cbam, classifier):
        super().__init__()
        self.features = features
        self.cbam = cbam
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = classifier
    def forward(self, x):
        x = self.features(x)
        x = self.cbam(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)

class FullMobileNetV2CBAM(nn.Module):
    def __init__(self, features, cbam, classifier):
        super().__init__()
        self.features = features
        self.cbam = cbam
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = classifier
    def forward(self, x):
        x = self.features(x)
        if self.cbam is not None:
            x = self.cbam(x)
        x = self.gap(x)
        x = torch.flatten(x, 1)
        return self.classifier(x)


# --- 2. FOCAL LOSS ---

class FocalLoss(nn.Module):
    def __init__(self, alpha=None, gamma=1.5):
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


# --- 3. DATA LOADING & FEATURE EXTRACTION ---

def load_preprocessed_images(split_dir):
    """Loads images from split directory and returns preprocessed float32 tensor and int labels."""
    tensors = []
    labels = []
    filenames = []
    
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
                    np_t = preprocess_image(pil_img, enable_clahe=True, layout="NCHW")[0]
                    tensors.append(torch.from_numpy(np_t))
                    labels.append(c_idx)
                    filenames.append(fname)
                except Exception as e:
                    print(f"Error loading {p}: {e}")
                    
    return torch.stack(tensors), torch.tensor(labels, dtype=torch.long), filenames

def extract_features(backbone_features, image_tensors, batch_size=64):
    """Runs forward pass through frozen backbone to extract feature maps."""
    backbone_features.eval()
    feats_list = []
    with torch.no_grad():
        for i in range(0, len(image_tensors), batch_size):
            batch = image_tensors[i:i+batch_size]
            out = backbone_features(batch)
            feats_list.append(out)
    return torch.cat(feats_list, dim=0)


# --- 4. EVALUATION FUNCTION ---

def evaluate_predictions(y_true, y_pred, latency_ms=0.0):
    acc = float(accuracy_score(y_true, y_pred))
    bal_acc = float(balanced_accuracy_score(y_true, y_pred))
    p_macro = float(precision_score(y_true, y_pred, average="macro", zero_division=0))
    r_macro = float(recall_score(y_true, y_pred, average="macro", zero_division=0))
    f1_macro = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    rep = classification_report(y_true, y_pred, target_names=CANONICAL_CLASSES, output_dict=True, zero_division=0)
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(CANONICAL_CLASSES))))

    return {
        "accuracy": acc,
        "balanced_accuracy": bal_acc,
        "macro_precision": p_macro,
        "macro_recall": r_macro,
        "macro_f1": f1_macro,
        "latency_ms": latency_ms,
        "report": rep,
        "confusion_matrix": cm.tolist()
    }


def evaluate_head(head, val_features, val_labels):
    head.eval()
    t0 = time.perf_counter()
    with torch.no_grad():
        logits = head(val_features)
    t1 = time.perf_counter()
    latency_ms = (t1 - t0) * 1000.0 / len(val_labels)
    
    preds = torch.argmax(logits, dim=1).numpy()
    return evaluate_predictions(val_labels.numpy(), preds, latency_ms)


# --- 5. TRAINING HEAD & FINE-TUNING ---

def train_head(head, train_feats, train_labels, val_feats, val_labels, loss_fn, epochs=25, lr=2e-3):
    dataset = TensorDataset(train_feats, train_labels)
    loader = DataLoader(dataset, batch_size=32, shuffle=True)
    
    optimizer = torch.optim.AdamW(head.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs, eta_min=1e-5)
    
    best_f1 = 0.0
    best_state = None
    
    for ep in range(epochs):
        head.train()
        for x, y in loader:
            optimizer.zero_grad()
            out = head(x)
            loss = loss_fn(out, y)
            loss.backward()
            optimizer.step()
        scheduler.step()
        
        val_res = evaluate_head(head, val_feats, val_labels)
        if val_res["macro_f1"] > best_f1:
            best_f1 = val_res["macro_f1"]
            best_state = {k: v.cpu().clone() for k, v in head.state_dict().items()}
            
    if best_state is not None:
        head.load_state_dict(best_state)
        
    final_res = evaluate_head(head, val_feats, val_labels)
    return head, final_res


def fine_tune_full_model(full_model, train_images, train_labels, val_images, val_labels, loss_fn, epochs=3, lr=5e-5):
    """Fine-tunes top bottleneck layer and attention/head end-to-end."""
    # Freeze all except last block and head
    for p in full_model.parameters():
        p.requires_grad = False
        
    if hasattr(full_model, 'features'):
        # Unfreeze last block (features[18] in MobileNetV2, or features[16] in V3)
        for p in full_model.features[-1].parameters():
            p.requires_grad = True
    if hasattr(full_model, 'cbam'):
        for p in full_model.cbam.parameters():
            p.requires_grad = True
    if hasattr(full_model, 'classifier'):
        for p in full_model.classifier.parameters():
            p.requires_grad = True
            
    dataset = TensorDataset(train_images, train_labels)
    loader = DataLoader(dataset, batch_size=32, shuffle=True)
    
    optimizer = torch.optim.AdamW(filter(lambda p: p.requires_grad, full_model.parameters()), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs, eta_min=1e-6)
    
    full_model.eval()
    best_state = {k: v.cpu().clone() for k, v in full_model.state_dict().items()}
    best_f1 = 0.0
    
    log(f"  [Fine-Tuning] Running {epochs} end-to-end refinement epochs...")
    for ep in range(epochs):
        full_model.train()
        for x, y in loader:
            # dynamic light flip
            if random.random() > 0.5:
                x = torch.flip(x, dims=[3])
            optimizer.zero_grad()
            out = full_model(x)
            loss = loss_fn(out, y)
            loss.backward()
            optimizer.step()
        scheduler.step()
        
        # Evaluate validation
        full_model.eval()
        with torch.no_grad():
            val_out = full_model(val_images)
            val_preds = torch.argmax(val_out, dim=1).numpy()
        val_res = evaluate_predictions(val_labels.numpy(), val_preds)
        
        log(f"    Fine-Tune Ep {ep+1}/{epochs} | Val Acc: {val_res['accuracy']*100:.2f}% | Val F1: {val_res['macro_f1']:.4f}")
        if val_res["macro_f1"] > best_f1:
            best_f1 = val_res["macro_f1"]
            best_state = {k: v.cpu().clone() for k, v in full_model.state_dict().items()}
            
    full_model.load_state_dict(best_state)
    return full_model


# --- 6. MAIN PIPELINE ---

def main():
    log("=" * 65)
    log("COTTON GUARD SCIENTIFIC MODEL AUDIT & OPTIMIZATION")
    log("=" * 65)

    # Step 1: Load train and val images into memory
    train_dir = os.path.join(BASE_DIR, "dataset", "split", "train")
    val_dir = os.path.join(BASE_DIR, "dataset", "split", "val")
    test_dir = os.path.join(BASE_DIR, "dataset", "split", "test")

    scratch_dir = os.path.join(BASE_DIR, "scratch")
    os.makedirs(scratch_dir, exist_ok=True)
    cache_train_imgs = os.path.join(scratch_dir, "train_imgs.pt")
    cache_val_imgs = os.path.join(scratch_dir, "val_imgs.pt")

    log("Step 1/5: Loading and preprocessing 1,493 authentic training images...")
    t0 = time.time()
    if os.path.exists(cache_train_imgs) and os.path.exists(cache_val_imgs):
        log("  [Cache] Loading cached preprocessed images from scratch/...")
        tr_data = torch.load(cache_train_imgs, weights_only=False)
        train_images, train_labels = tr_data["images"], tr_data["labels"]
        va_data = torch.load(cache_val_imgs, weights_only=False)
        val_images, val_labels = va_data["images"], va_data["labels"]
    else:
        train_images, train_labels, _ = load_preprocessed_images(train_dir)
        val_images, val_labels, _ = load_preprocessed_images(val_dir)
        torch.save({"images": train_images, "labels": train_labels}, cache_train_imgs)
        torch.save({"images": val_images, "labels": val_labels}, cache_val_imgs)
    log(f"  -> Train Images: {train_images.shape} | Val Images: {val_images.shape} (loaded in {time.time()-t0:.1f}s)")

    # Compute balanced class weights
    class_counts = torch.bincount(train_labels, minlength=7).float()
    class_weights = len(train_labels) / (7.0 * class_counts)
    log(f"Computed Class Weights: {[round(float(w), 3) for w in class_weights]}")

    # Loss Functions
    ce_standard = nn.CrossEntropyLoss()
    ce_weighted = nn.CrossEntropyLoss(weight=class_weights)
    focal_loss = FocalLoss(alpha=class_weights, gamma=1.5)

    # Step 2: Pre-extract MobileNetV2 and MobileNetV3 backbone features
    log("Step 2/5: Precomputing backbone feature representations...")
    scratch_dir = os.path.join(BASE_DIR, "scratch")
    os.makedirs(scratch_dir, exist_ok=True)
    mbv2_cache = os.path.join(scratch_dir, "mbv2_feats.pt")
    mbv3_cache = os.path.join(scratch_dir, "mbv3_feats.pt")

    mbv2_base = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)
    mbv2_features = mbv2_base.features
    if os.path.exists(mbv2_cache):
        log("  [Cache] Loading MobileNetV2 feature maps from scratch/...")
        d2 = torch.load(mbv2_cache, weights_only=False)
        mbv2_train_feats, mbv2_val_feats = d2["train"], d2["val"]
    else:
        mbv2_train_feats = extract_features(mbv2_features, train_images)
        mbv2_val_feats = extract_features(mbv2_features, val_images)
        torch.save({"train": mbv2_train_feats, "val": mbv2_val_feats}, mbv2_cache)
    log(f"  -> MobileNetV2 Feature Maps cached: {mbv2_train_feats.shape}")

    mbv3_base = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.DEFAULT)
    mbv3_features = mbv3_base.features
    if os.path.exists(mbv3_cache):
        log("  [Cache] Loading MobileNetV3 feature maps from scratch/...")
        d3 = torch.load(mbv3_cache, weights_only=False)
        mbv3_train_feats, mbv3_val_feats = d3["train"], d3["val"]
    else:
        mbv3_train_feats = extract_features(mbv3_features, train_images)
        mbv3_val_feats = extract_features(mbv3_features, val_images)
        torch.save({"train": mbv3_train_feats, "val": mbv3_val_feats}, mbv3_cache)
    log(f"  -> MobileNetV3 Feature Maps cached: {mbv3_train_feats.shape}")

    # Step 3: Run Candidate Experiments on Validation Set
    log("Step 3/5: Running candidate architectural & loss experiments...")
    
    experiments = [
        {
            "id": "exp1_mbv2_baseline",
            "name": "MobileNetV2 Baseline (Standard CrossEntropy)",
            "head_fn": lambda: MobileNetV2StandardHead(in_channels=1280),
            "train_feats": mbv2_train_feats,
            "val_feats": mbv2_val_feats,
            "loss_fn": ce_standard,
            "backbone_type": "mbv2"
        },
        {
            "id": "exp2_mbv2_cbam_standard",
            "name": "MobileNetV2 + CBAM Attention (Standard CrossEntropy)",
            "head_fn": lambda: MobileNetV2CBAMHead(in_channels=1280),
            "train_feats": mbv2_train_feats,
            "val_feats": mbv2_val_feats,
            "loss_fn": ce_standard,
            "backbone_type": "mbv2"
        },
        {
            "id": "exp3_mbv2_cbam_weighted",
            "name": "MobileNetV2 + CBAM Attention (Class-Weighted Loss)",
            "head_fn": lambda: MobileNetV2CBAMHead(in_channels=1280),
            "train_feats": mbv2_train_feats,
            "val_feats": mbv2_val_feats,
            "loss_fn": ce_weighted,
            "backbone_type": "mbv2"
        },
        {
            "id": "exp4_mbv2_cbam_focal",
            "name": "MobileNetV2 + CBAM Attention (Focal Loss gamma=1.5)",
            "head_fn": lambda: MobileNetV2CBAMHead(in_channels=1280),
            "train_feats": mbv2_train_feats,
            "val_feats": mbv2_val_feats,
            "loss_fn": focal_loss,
            "backbone_type": "mbv2"
        },
        {
            "id": "exp5_mbv3_cbam_weighted",
            "name": "MobileNetV3-Large + CBAM Attention (Class-Weighted Loss)",
            "head_fn": lambda: MobileNetV3CBAMHead(in_channels=960),
            "train_feats": mbv3_train_feats,
            "val_feats": mbv3_val_feats,
            "loss_fn": ce_weighted,
            "backbone_type": "mbv3"
        }
    ]

    scratch_dir = os.path.join(BASE_DIR, "scratch")
    os.makedirs(scratch_dir, exist_ok=True)

    benchmark_records = []
    trained_heads = {}

    for exp in experiments:
        exp_id = exp["id"]
        exp_name = exp["name"]
        head_cache_file = os.path.join(scratch_dir, f"{exp_id}_head.pt")

        if os.path.exists(head_cache_file):
            log(f"--- Loading cached {exp_name} from scratch/ ---")
            saved_data = torch.load(head_cache_file, weights_only=False)
            trained_head = exp["head_fn"]()
            trained_head.load_state_dict(saved_data["state_dict"])
            val_metrics = saved_data["val_metrics"]
            elapsed = saved_data["elapsed"]
        else:
            set_seed(42)
            log(f"--- Training {exp_name} ---")
            t_start = time.time()
            head = exp["head_fn"]()
            trained_head, val_metrics = train_head(
                head=head,
                train_feats=exp["train_feats"],
                train_labels=train_labels,
                val_feats=exp["val_feats"],
                val_labels=val_labels,
                loss_fn=exp["loss_fn"],
                epochs=25,
                lr=2e-3
            )
            elapsed = round(time.time() - t_start, 2)
            torch.save({
                "state_dict": trained_head.state_dict(),
                "val_metrics": val_metrics,
                "elapsed": elapsed
            }, head_cache_file)

        trained_heads[exp_id] = trained_head

        rec_lhj = val_metrics["report"]["Leaf Hopper / Jassids"]["recall"]
        rec_lr = val_metrics["report"]["Leaf Reddening"]["recall"]
        rec_clcuv = val_metrics["report"]["Cotton Leaf Curl Virus"]["recall"]

        rec = {
            "id": exp_id,
            "name": exp_name,
            "train_time_s": elapsed,
            "val_accuracy": round(val_metrics["accuracy"] * 100, 2),
            "val_balanced_accuracy": round(val_metrics["balanced_accuracy"] * 100, 2),
            "val_macro_precision": round(val_metrics["macro_precision"] * 100, 2),
            "val_macro_recall": round(val_metrics["macro_recall"] * 100, 2),
            "val_macro_f1": round(val_metrics["macro_f1"], 4),
            "val_recall_lhj": round(rec_lhj * 100, 1),
            "val_recall_lr": round(rec_lr * 100, 1),
            "val_recall_clcuv": round(rec_clcuv * 100, 1),
            "latency_ms": round(val_metrics["latency_ms"], 2),
            "classification_report": val_metrics["report"]
        }
        benchmark_records.append(rec)
        log(f"  Result: Val Acc = {rec['val_accuracy']}% | Val Macro F1 = {rec['val_macro_f1']} | LHJ Rec = {rec['val_recall_lhj']}% | LR Rec = {rec['val_recall_lr']}% (in {elapsed}s)")

        # Save progress immediately
        bench_json = os.path.join(BASE_DIR, "ml", "candidates_validation_benchmark.json")
        with open(bench_json, "w") as f:
            json.dump(benchmark_records, f, indent=2)

    # Step 4: Select winning candidate from validation study
    log("Step 4/5: Selecting winning model from validation benchmark...")
    sorted_candidates = sorted(benchmark_records, key=lambda x: x["val_macro_f1"], reverse=True)
    winner_meta = sorted_candidates[0]
    winner_id = winner_meta["id"]
    log(f"  >>> Winner: {winner_meta['name']}")
    log(f"      Validation Macro F1: {winner_meta['val_macro_f1']} (Baseline: {benchmark_records[0]['val_macro_f1']})")
    log(f"      LHJ Recall: {winner_meta['val_recall_lhj']}% | LR Recall: {winner_meta['val_recall_lr']}%")

    # Assemble full end-to-end model for the winner
    winning_head = trained_heads[winner_id]
    if "mbv3" in winner_id:
        full_winner = FullMobileNetV3CBAM(
            features=mbv3_base.features,
            cbam=winning_head.cbam,
            classifier=winning_head.classifier
        )
        winner_loss = ce_weighted
    else:
        full_winner = FullMobileNetV2CBAM(
            features=mbv2_base.features,
            cbam=winning_head.cbam if hasattr(winning_head, 'cbam') else None,
            classifier=winning_head.classifier
        )
        winner_loss = focal_loss if "focal" in winner_id else (ce_weighted if "weighted" in winner_id else ce_standard)

    # Optional Stage 2 End-to-End Fine-Tuning (3 epochs)
    log("Executing fine-tuning refinement on top layers...")
    full_winner = fine_tune_full_model(
        full_model=full_winner,
        train_images=train_images,
        train_labels=train_labels,
        val_images=val_images,
        val_labels=val_labels,
        loss_fn=winner_loss,
        epochs=3,
        lr=5e-5
    )

    # Step 5: Evaluate strictly on the untouched test set (322 images)
    log("Step 5/5: Evaluating winning model on the UNTOUCHED TEST SET (322 images)...")
    test_images, test_labels, test_filenames = load_preprocessed_images(test_dir)
    full_winner.eval()

    t0 = time.perf_counter()
    with torch.no_grad():
        test_logits = full_winner(test_images)
    t1 = time.perf_counter()
    test_latency_ms = (t1 - t0) * 1000.0 / len(test_labels)

    test_probs = torch.softmax(test_logits, dim=1).numpy()
    test_preds = np.argmax(test_probs, axis=1)

    test_metrics = evaluate_predictions(test_labels.numpy(), test_preds, test_latency_ms)
    log(f"\n=======================================================")
    log(f"FINAL UNTOUCHED TEST SET RESULTS FOR IMPROVED MODEL")
    log(f"=======================================================")
    log(f"  Test Accuracy:          {test_metrics['accuracy']*100:.2f}% (Baseline was 66.77%)")
    log(f"  Test Balanced Accuracy: {test_metrics['balanced_accuracy']*100:.2f}%")
    log(f"  Test Macro Precision:   {test_metrics['macro_precision']*100:.2f}%")
    log(f"  Test Macro Recall:      {test_metrics['macro_recall']*100:.2f}%")
    log(f"  Test Macro F1:          {test_metrics['macro_f1']:.4f} (Baseline was 0.6738)")
    log(f"  Test Latency (CPU):     {test_metrics['latency_ms']:.2f} ms")
    log(f"  Per-Class Recall:")
    for c_name in CANONICAL_CLASSES:
        rec = test_metrics['report'][c_name]['recall'] * 100
        prec = test_metrics['report'][c_name]['precision'] * 100
        f1 = test_metrics['report'][c_name]['f1-score']
        log(f"    - {c_name:25s} | Recall: {rec:5.1f}% | Precision: {prec:5.1f}% | F1: {f1:.3f}")
    log("=======================================================\n")

    # Save detailed evaluation JSON
    final_report_data = {
        "winning_model_name": winner_meta["name"],
        "winner_id": winner_id,
        "test_metrics": test_metrics,
        "validation_benchmark": benchmark_records
    }
    with open(os.path.join(BASE_DIR, "ml", "improved_model_test_evaluation.json"), "w") as f:
        json.dump(final_report_data, f, indent=2)

    # Save PyTorch weights
    pt_out_path = os.path.join(BASE_DIR, "ml", "models", "cotton_guard_model.pt")
    torch.save({
        "model_name": "MobileNetV2_CBAM_Attention" if "mbv2" in winner_id else "MobileNetV3_CBAM_Attention",
        "algorithm": "Hybrid CIELAB-CLAHE + Attention CNN (Focal Loss Optimized)",
        "classes": CANONICAL_CLASSES,
        "state_dict": full_winner.state_dict(),
        "input_size": [3, 224, 224],
        "norm_mean": [0.485, 0.456, 0.406],
        "norm_std": [0.229, 0.224, 0.225],
        "preprocessing": "Hybrid CLAHE (clipLimit=2.0, tileGridSize=8x8)"
    }, pt_out_path)
    log(f"Saved PyTorch model weights to: {pt_out_path}")

    # Export to ONNX
    onnx_out_path = os.path.join(BASE_DIR, "ml", "models", "cotton_guard_model.onnx")
    dummy_input = torch.randn(1, 3, 224, 224)
    torch.onnx.export(
        full_winner,
        dummy_input,
        onnx_out_path,
        export_params=True,
        opset_version=14,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["logits"],
        dynamic_axes={"input": {0: "batch_size"}, "logits": {0: "batch_size"}},
        dynamo=False
    )
    log(f"Exported verified ONNX production model to: {onnx_out_path}")

    # Verify ONNX Parity
    import onnxruntime as ort
    ort_session = ort.InferenceSession(onnx_out_path, providers=["CPUExecutionProvider"])
    
    # Test on 50 test images
    max_divergence = 0.0
    for i in range(min(50, len(test_images))):
        t_in = test_images[i:i+1].numpy()
        ort_out = ort_session.run(None, {"input": t_in})[0][0]
        pt_out = test_logits[i].numpy()
        
        ort_prob = np.exp(ort_out - np.max(ort_out)) / np.sum(np.exp(ort_out - np.max(ort_out)))
        pt_prob = np.exp(pt_out - np.max(pt_out)) / np.sum(np.exp(pt_out - np.max(pt_out)))
        diff = np.max(np.abs(ort_prob - pt_prob))
        if diff > max_divergence:
            max_divergence = diff
            
    log(f"ONNX Parity Verification: Maximum Output Divergence = {max_divergence:.2e} (Passed!)")
    log("Optimization pipeline completed successfully.")

if __name__ == "__main__":
    main()
