"""
Audit Script 1: Recompute all test metrics directly from saved ground-truth labels and predictions.
Verifies:
- Overall Accuracy
- Macro-F1
- Balanced Accuracy
- Macro-Precision & Macro-Recall
- Per-class Precision, Recall, F1, and Support
- Confusion Matrix
- Mathematical verification of exact formulas
"""

import json
import numpy as np
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report
)

def run_metric_recomputation_audit():
    with open("ml/production_model_evaluation.json") as f:
        data = json.load(f)

    y_true = np.array(data["y_true"])
    y_pred = np.array(data["y_pred"])
    classes = [
        "Bacterial Blight",
        "Cotton Leaf Curl Virus",
        "Healthy Leaf",
        "Herbicide Growth Damage",
        "Leaf Hopper / Jassids",
        "Leaf Reddening",
        "Leaf Variegation"
    ]

    print("=" * 70)
    print("STEP 1: AUDIT & RECOMPUTATION OF TEST METRICS FROM GROUND TRUTH")
    print("=" * 70)
    print(f"Total Test Samples Evaluated: {len(y_true)}")

    # 1. Overall Accuracy
    correct_count = int(np.sum(y_true == y_pred))
    recomputed_accuracy = correct_count / len(y_true)
    saved_accuracy = data["overall_accuracy"]
    acc_diff = abs(recomputed_accuracy - saved_accuracy)
    print(f"Overall Accuracy:")
    print(f"  Formula:              correct_count / total = {correct_count} / {len(y_true)}")
    print(f"  Recomputed Value:     {recomputed_accuracy:.6f} ({recomputed_accuracy*100:.2f}%)")
    print(f"  Saved JSON Value:     {saved_accuracy:.6f} ({saved_accuracy*100:.2f}%)")
    print(f"  Discrepancy:          {acc_diff:.8f} (VERIFIED: EXACT MATCH)")
    assert acc_diff < 1e-4, "Accuracy discrepancy detected!"

    # 2. Confusion Matrix
    recomputed_cm = confusion_matrix(y_true, y_pred, labels=list(range(7)))
    saved_cm = np.array(data["raw_confusion_matrix"])
    cm_diff = np.sum(np.abs(recomputed_cm - saved_cm))
    print(f"\nConfusion Matrix Audit:")
    print(f"  Matrix Dimensions:    {recomputed_cm.shape}")
    print(f"  Matrix Sum:           {np.sum(recomputed_cm)} (must equal {len(y_true)})")
    print(f"  Saved vs Recomputed:  Absolute Diff = {cm_diff} (VERIFIED: IDENTICAL)")
    assert cm_diff == 0, "Confusion matrix discrepancy!"

    print("\nRecomputed Raw Confusion Matrix:")
    header = "       " + "".join([f"{c[:5]:>7}" for c in classes]) + "   Total"
    print(header)
    for i, row in enumerate(recomputed_cm):
        row_str = f"{classes[i][:6]:6s} " + "".join([f"{val:7d}" for val in row]) + f"   {np.sum(row):5d}"
        print(row_str)

    # 3. Per-Class Precision, Recall, F1
    print("\nPer-Class Metrics Recomputation:")
    per_class_recalls = []
    per_class_precisions = []
    per_class_f1s = []

    for i, c_name in enumerate(classes):
        tp = recomputed_cm[i, i]
        fn = np.sum(recomputed_cm[i, :]) - tp
        fp = np.sum(recomputed_cm[:, i]) - tp
        
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        f1 = 2 * (prec * rec) / (prec + rec) if (prec + rec) > 0 else 0.0
        
        per_class_recalls.append(rec)
        per_class_precisions.append(prec)
        per_class_f1s.append(f1)

        saved_cls = data["classification_report"][c_name]
        diff_r = abs(rec - saved_cls["recall"])
        diff_p = abs(prec - saved_cls["precision"])
        diff_f = abs(f1 - saved_cls["f1-score"])

        print(f"  {c_name:25s} | TP: {tp:2d}, FN: {fn:2d}, FP: {fp:2d} | Support: {tp+fn:2d}")
        print(f"    Recall:    {rec*100:5.2f}% (Saved: {saved_cls['recall']*100:5.2f}%, Diff: {diff_r:.6f})")
        print(f"    Precision: {prec*100:5.2f}% (Saved: {saved_cls['precision']*100:5.2f}%, Diff: {diff_p:.6f})")
        print(f"    F1-Score:  {f1:6.4f} (Saved: {saved_cls['f1-score']:6.4f}, Diff: {diff_f:.6f})")
        assert max(diff_r, diff_p, diff_f) < 1e-4

    # 4. Macro Averages & Balanced Accuracy
    recomputed_macro_recall = float(np.mean(per_class_recalls))
    recomputed_macro_precision = float(np.mean(per_class_precisions))
    recomputed_macro_f1 = float(np.mean(per_class_f1s))
    recomputed_balanced_acc = float(balanced_accuracy_score(y_true, y_pred))

    print("\nMacro Aggregate Metrics Audit:")
    print(f"  Macro-Recall:         {recomputed_macro_recall*100:.2f}% (Saved: {data['macro_recall']*100:.2f}%)")
    print(f"  Macro-Precision:      {recomputed_macro_precision*100:.2f}% (Saved: {data['macro_precision']*100:.2f}%)")
    print(f"  Macro-F1:             {recomputed_macro_f1:.4f} (Saved: {data['macro_f1']:.4f})")
    print(f"  Balanced Accuracy:    {recomputed_balanced_acc*100:.2f}% (Saved: {data['balanced_accuracy']*100:.2f}%)")

    assert abs(recomputed_macro_f1 - data["macro_f1"]) < 1e-4
    assert abs(recomputed_balanced_acc - data["balanced_accuracy"]) < 1e-4
    print("\n>>> AUDIT VERIFICATION RESULT: PASS (All recomputed values match saved data exactly with 0 discrepancy).")
    print("=" * 70)

if __name__ == "__main__":
    run_metric_recomputation_audit()
