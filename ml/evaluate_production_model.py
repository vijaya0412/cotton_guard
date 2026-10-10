"""
Cotton Guard - Comprehensive Evaluation of Current Production Model on Untouched Test Set.
Evaluates ml/models/cotton_guard_model.onnx using ml/preprocessing.py.
Outputs:
- Per-sample records (true, pred, top-3 classes/probs, latency, correctness)
- Overall accuracy, balanced accuracy, macro precision, macro recall, macro F1
- Per-class precision, recall, F1, support
- Raw and normalized confusion matrices
- Confidence distributions for correct vs incorrect predictions
- Most frequently confused disease pairs
- Full gallery / catalog of misclassified images
"""

import os
import sys
import time
import json
from collections import defaultdict
import numpy as np
from PIL import Image
import onnxruntime as ort
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    classification_report,
    confusion_matrix
)

# Project imports
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)
from ml.classes import CANONICAL_CLASSES, CLASS_TO_FOLDER, FOLDER_TO_CLASS
from ml.preprocessing import preprocess_image

def evaluate_production_onnx(onnx_path, test_dir, output_json_path=None):
    print(f"[Evaluation] Loading ONNX session from: {onnx_path}")
    session = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    
    # Collect all test images
    records = []
    y_true = []
    y_pred = []
    all_latencies = []
    
    print(f"[Evaluation] Scanning test set in: {test_dir}")
    for class_idx, class_name in enumerate(CANONICAL_CLASSES):
        folder_name = CLASS_TO_FOLDER[class_name]
        class_folder = os.path.join(test_dir, folder_name)
        if not os.path.isdir(class_folder):
            print(f"[Warning] Folder missing: {class_folder}")
            continue
            
        file_list = sorted([
            f for f in os.listdir(class_folder)
            if f.lower().endswith(('.jpg', '.jpeg', '.png'))
        ])
        
        for fname in file_list:
            img_path = os.path.join(class_folder, fname)
            try:
                pil_img = Image.open(img_path).convert("RGB")
                
                # Preprocess with production hybrid CLAHE pipeline
                t0 = time.perf_counter()
                tensor = preprocess_image(pil_img, enable_clahe=True, layout="NCHW")
                
                # Run ONNX inference
                outputs = session.run(None, {input_name: tensor})
                logits = outputs[0][0]
                
                # Calibrate Softmax
                exp_logits = np.exp(logits - np.max(logits))
                probs = exp_logits / np.sum(exp_logits)
                t1 = time.perf_counter()
                latency_ms = (t1 - t0) * 1000.0
                all_latencies.append(latency_ms)
                
                # Top-3 predictions
                top3_indices = np.argsort(probs)[::-1][:3]
                pred_idx = int(top3_indices[0])
                top1_prob = float(probs[pred_idx])
                
                top3_info = [
                    {
                        "class": CANONICAL_CLASSES[idx],
                        "class_index": int(idx),
                        "probability": round(float(probs[idx]), 4)
                    }
                    for idx in top3_indices
                ]
                
                is_correct = (pred_idx == class_idx)
                y_true.append(class_idx)
                y_pred.append(pred_idx)
                
                record = {
                    "filename": fname,
                    "rel_path": os.path.relpath(img_path, BASE_DIR).replace("\\", "/"),
                    "true_class": class_name,
                    "true_index": class_idx,
                    "predicted_class": CANONICAL_CLASSES[pred_idx],
                    "predicted_index": pred_idx,
                    "is_correct": is_correct,
                    "confidence": round(top1_prob, 4),
                    "top3": top3_info,
                    "latency_ms": round(latency_ms, 2)
                }
                records.append(record)
                
            except Exception as e:
                print(f"[Error] Failed to process {img_path}: {e}")
                record = {
                    "filename": fname,
                    "rel_path": os.path.relpath(img_path, BASE_DIR).replace("\\", "/"),
                    "true_class": class_name,
                    "true_index": class_idx,
                    "error": str(e),
                    "is_correct": False
                }
                records.append(record)

    # Calculate overall and per-class metrics
    acc = float(accuracy_score(y_true, y_pred))
    bal_acc = float(balanced_accuracy_score(y_true, y_pred))
    macro_p = float(precision_score(y_true, y_pred, average="macro", zero_division=0))
    macro_r = float(recall_score(y_true, y_pred, average="macro", zero_division=0))
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    weighted_f1 = float(f1_score(y_true, y_pred, average="weighted", zero_division=0))
    
    cls_report = classification_report(
        y_true, y_pred,
        target_names=CANONICAL_CLASSES,
        output_dict=True,
        zero_division=0
    )
    
    raw_cm = confusion_matrix(y_true, y_pred, labels=list(range(len(CANONICAL_CLASSES))))
    norm_cm = raw_cm.astype(float) / raw_cm.sum(axis=1, keepdims=True)
    norm_cm = np.nan_to_num(norm_cm)
    
    # Confidence analysis: correct vs incorrect
    correct_confs = [r["confidence"] for r in records if r.get("is_correct") is True]
    incorrect_confs = [r["confidence"] for r in records if r.get("is_correct") is False]
    
    conf_stats = {
        "correct": {
            "count": len(correct_confs),
            "mean": float(np.mean(correct_confs)) if correct_confs else 0.0,
            "median": float(np.median(correct_confs)) if correct_confs else 0.0,
            "min": float(np.min(correct_confs)) if correct_confs else 0.0,
            "max": float(np.max(correct_confs)) if correct_confs else 0.0,
            "std": float(np.std(correct_confs)) if correct_confs else 0.0,
        },
        "incorrect": {
            "count": len(incorrect_confs),
            "mean": float(np.mean(incorrect_confs)) if incorrect_confs else 0.0,
            "median": float(np.median(incorrect_confs)) if incorrect_confs else 0.0,
            "min": float(np.min(incorrect_confs)) if incorrect_confs else 0.0,
            "max": float(np.max(incorrect_confs)) if incorrect_confs else 0.0,
            "std": float(np.std(incorrect_confs)) if incorrect_confs else 0.0,
        }
    }
    
    # Most frequently confused disease pairs (True -> Pred)
    confusion_pairs = defaultdict(int)
    for r in records:
        if not r.get("is_correct"):
            pair_key = f"{r['true_class']} -> {r['predicted_class']}"
            confusion_pairs[pair_key] += 1
            
    sorted_confusions = sorted(confusion_pairs.items(), key=lambda x: x[1], reverse=True)
    
    # Gallery of misclassified images
    misclassified_gallery = [
        {
            "filename": r["filename"],
            "path": r["rel_path"],
            "true_class": r["true_class"],
            "predicted_class": r["predicted_class"],
            "confidence": r["confidence"],
            "top3": r["top3"]
        }
        for r in records if not r.get("is_correct")
    ]
    
    results = {
        "model_path": onnx_path,
        "evaluation_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_test_images": len(records),
        "overall_accuracy": round(acc, 4),
        "balanced_accuracy": round(bal_acc, 4),
        "macro_precision": round(macro_p, 4),
        "macro_recall": round(macro_r, 4),
        "macro_f1": round(macro_f1, 4),
        "weighted_f1": round(weighted_f1, 4),
        "mean_latency_ms": round(float(np.mean(all_latencies)), 2),
        "classification_report": cls_report,
        "raw_confusion_matrix": raw_cm.tolist(),
        "normalized_confusion_matrix": np.round(norm_cm, 4).tolist(),
        "confidence_statistics": conf_stats,
        "most_frequent_confusions": sorted_confusions[:15],
        "misclassified_count": len(misclassified_gallery),
        "misclassified_gallery": misclassified_gallery,
        "y_true": y_true,
        "y_pred": y_pred,
        "all_records": records
    }
    
    if output_json_path:
        with open(output_json_path, "w") as f:
            json.dump(results, f, indent=2)
        print(f"[Evaluation] Results successfully saved to: {output_json_path}")
        
    return results

if __name__ == "__main__":
    onnx_file = os.path.join(BASE_DIR, "ml", "models", "cotton_guard_model.onnx")
    test_split_dir = os.path.join(BASE_DIR, "dataset", "split", "test")
    out_json = os.path.join(BASE_DIR, "ml", "production_model_evaluation.json")
    
    res = evaluate_production_onnx(onnx_file, test_split_dir, out_json)
    
    print("\n" + "=" * 60)
    print("PRODUCTION MODEL EVALUATION SUMMARY (UNTOUCHED TEST SET)")
    print("=" * 60)
    print(f"Total Test Images:    {res['total_test_images']}")
    print(f"Accuracy:            {res['overall_accuracy']*100:.2f}%")
    print(f"Balanced Accuracy:   {res['balanced_accuracy']*100:.2f}%")
    print(f"Macro Precision:     {res['macro_precision']*100:.2f}%")
    print(f"Macro Recall:        {res['macro_recall']*100:.2f}%")
    print(f"Macro F1-Score:      {res['macro_f1']:.4f}")
    print(f"Misclassified Count: {res['misclassified_count']} / {res['total_test_images']}")
    print("\nTop 5 Most Frequent Confusions:")
    for pair, count in res["most_frequent_confusions"][:5]:
        print(f"  - {pair}: {count} occurrences")
    print("=" * 60)
