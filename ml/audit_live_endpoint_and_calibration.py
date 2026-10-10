"""
Cotton Guard - Final Model Verification: Calibration Evaluation and Endpoint Testing
Audits held-out validation data calibration, margin policy, and FastAPI prediction endpoint.
"""

import os
import sys
import glob
import json
import numpy as np
from PIL import Image
import onnxruntime as ort
from fastapi.testclient import TestClient

# Add project root to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.classes import CANONICAL_CLASSES, FOLDER_TO_CLASS
from ml.preprocessing import preprocess_image
from ml.cotton_gate import CottonDomainGate
from backend.main import app

def run_calibration_audit():
    print("=" * 80)
    print("STAGE 1: CALIBRATION EVALUATION ON HELD-OUT VALIDATION SET")
    print("=" * 80)

    onnx_path = os.path.join("ml", "models", "cotton_guard_model.onnx")
    session = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name

    val_files = sorted(glob.glob("dataset/split/val/*/*.jpg"))
    print(f"Loaded {len(val_files)} held-out validation images.")

    y_true_all = []
    y_pred_all = []
    conf_all = []
    prob_all = []
    margins_all = []

    for fpath in val_files:
        folder = os.path.basename(os.path.dirname(fpath))
        true_label = FOLDER_TO_CLASS[folder]
        true_idx = CANONICAL_CLASSES.index(true_label)

        pil_img = Image.open(fpath).convert("RGB")
        tensor = preprocess_image(pil_img)
        logits = session.run(None, {input_name: tensor})[0][0]

        exp_l = np.exp(logits - np.max(logits))
        probs = exp_l / np.sum(exp_l)

        pred_idx = int(np.argmax(probs))
        conf = float(probs[pred_idx])

        sorted_p = np.sort(probs)[::-1]
        margin = float(sorted_p[0] - sorted_p[1])

        y_true_all.append(true_idx)
        y_pred_all.append(pred_idx)
        conf_all.append(conf)
        prob_all.append(probs)
        margins_all.append(margin)

    y_true = np.array(y_true_all)
    y_pred = np.array(y_pred_all)
    conf = np.array(conf_all)
    probs = np.array(prob_all)
    margins = np.array(margins_all)

    accuracy = np.mean(y_pred == y_true)
    print(f"Validation Set Overall Accuracy: {accuracy*100:.2f}% ({np.sum(y_pred == y_true)}/{len(y_true)})")

    # Multi-class Brier score
    num_classes = len(CANONICAL_CLASSES)
    y_one_hot = np.zeros((len(y_true), num_classes))
    for i, idx in enumerate(y_true):
        y_one_hot[i, idx] = 1.0

    brier_score = np.mean(np.sum((probs - y_one_hot)**2, axis=1))
    print(f"Validation Multi-class Brier Score: {brier_score:.4f}")

    # Expected Calibration Error (ECE) with 10 equal-width bins
    n_bins = 10
    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    bin_lowers = bin_boundaries[:-1]
    bin_uppers = bin_boundaries[1:]

    ece = 0.0
    mce = 0.0
    bin_details = []

    print("\nReliability Diagram / Calibration Bins (Held-out Validation Data):")
    print(f"{'Bin':<12} {'Count':<8} {'Avg Conf':<12} {'Avg Acc':<12} {'Abs Diff':<12}")
    print("-" * 60)

    for b_idx in range(n_bins):
        b_low = bin_lowers[b_idx]
        b_high = bin_uppers[b_idx]
        in_bin = (conf > b_low) & (conf <= b_high) if b_idx > 0 else (conf >= b_low) & (conf <= b_high)
        count = np.sum(in_bin)

        if count > 0:
            avg_conf = np.mean(conf[in_bin])
            avg_acc = np.mean(y_pred[in_bin] == y_true[in_bin])
            diff = abs(avg_acc - avg_conf)
            ece += (count / len(y_true)) * diff
            mce = max(mce, diff)
            bin_details.append({
                "bin": f"[{b_low:.1f}, {b_high:.1f}]",
                "count": int(count),
                "avg_conf": float(avg_conf),
                "avg_acc": float(avg_acc),
                "diff": float(diff)
            })
            print(f"[{b_low:.1f}, {b_high:.1f}]    {count:<8} {avg_conf:<12.4f} {avg_acc:<12.4f} {diff:<12.4f}")
        else:
            print(f"[{b_low:.1f}, {b_high:.1f}]    0        -            -            -")

    print("-" * 60)
    print(f"Expected Calibration Error (ECE): {ece*100:.2f}% ({ece:.4f})")
    print(f"Maximum Calibration Error (MCE):  {mce*100:.2f}% ({mce:.4f})")

    # Margin Policy Analysis on Validation Set
    uncertain_by_conf = conf < CottonDomainGate.LOW_CONFIDENCE_THRESHOLD
    uncertain_by_margin = margins < CottonDomainGate.UNCERTAINTY_MARGIN
    uncertain_any = uncertain_by_conf | uncertain_by_margin

    print("\nValidation Uncertainty Policy Analysis:")
    print(f"  Total validation samples: {len(y_true)}")
    print(f"  Flagged by Low Confidence (< {CottonDomainGate.LOW_CONFIDENCE_THRESHOLD}): {np.sum(uncertain_by_conf)} ({np.sum(uncertain_by_conf)/len(y_true)*100:.1f}%)")
    print(f"  Flagged by Close Margin (< {CottonDomainGate.UNCERTAINTY_MARGIN}):        {np.sum(uncertain_by_margin)} ({np.sum(uncertain_by_margin)/len(y_true)*100:.1f}%)")
    print(f"  Total Flagged as Uncertain:                                 {np.sum(uncertain_any)} ({np.sum(uncertain_any)/len(y_true)*100:.1f}%)")
    
    acc_confident = np.mean(y_pred[~uncertain_any] == y_true[~uncertain_any]) if np.sum(~uncertain_any) > 0 else 0
    acc_uncertain = np.mean(y_pred[uncertain_any] == y_true[uncertain_any]) if np.sum(uncertain_any) > 0 else 0
    print(f"  Accuracy of Confident (Unflagged) Predictions: {acc_confident*100:.2f}% ({np.sum(y_pred[~uncertain_any] == y_true[~uncertain_any])}/{np.sum(~uncertain_any)})")
    print(f"  Accuracy of Uncertain (Flagged) Predictions:   {acc_uncertain*100:.2f}% ({np.sum(y_pred[uncertain_any] == y_true[uncertain_any])}/{np.sum(uncertain_any)})")

    # Also run the same on Test Set for complete verification
    print("\n" + "=" * 80)
    print("STAGE 2: CALIBRATION & UNCERTAINTY ON UNTOUCHED TEST SET (322 IMAGES)")
    print("=" * 80)
    test_files = sorted(glob.glob("dataset/split/test/*/*.jpg"))
    test_y_true = []
    test_y_pred = []
    test_conf = []
    test_margins = []
    test_probs = []

    for fpath in test_files:
        folder = os.path.basename(os.path.dirname(fpath))
        true_label = FOLDER_TO_CLASS[folder]
        true_idx = CANONICAL_CLASSES.index(true_label)

        pil_img = Image.open(fpath).convert("RGB")
        tensor = preprocess_image(pil_img)
        logits = session.run(None, {input_name: tensor})[0][0]
        exp_l = np.exp(logits - np.max(logits))
        p = exp_l / np.sum(exp_l)
        pred_idx = int(np.argmax(p))
        c = float(p[pred_idx])
        sp = np.sort(p)[::-1]
        m = float(sp[0] - sp[1])

        test_y_true.append(true_idx)
        test_y_pred.append(pred_idx)
        test_conf.append(c)
        test_margins.append(m)
        test_probs.append(p)

    test_y_true = np.array(test_y_true)
    test_y_pred = np.array(test_y_pred)
    test_conf = np.array(test_conf)
    test_margins = np.array(test_margins)
    test_probs = np.array(test_probs)

    test_acc = np.mean(test_y_pred == test_y_true)
    print(f"Test Accuracy: {test_acc*100:.2f}% ({np.sum(test_y_pred == test_y_true)}/{len(test_y_true)})")

    test_y_one_hot = np.zeros((len(test_y_true), num_classes))
    for i, idx in enumerate(test_y_true):
        test_y_one_hot[i, idx] = 1.0
    test_brier = np.mean(np.sum((test_probs - test_y_one_hot)**2, axis=1))
    print(f"Test Multi-class Brier Score: {test_brier:.4f}")

    test_ece = 0.0
    for b_idx in range(n_bins):
        b_low = bin_lowers[b_idx]
        b_high = bin_uppers[b_idx]
        in_bin = (test_conf > b_low) & (test_conf <= b_high) if b_idx > 0 else (test_conf >= b_low) & (test_conf <= b_high)
        cnt = np.sum(in_bin)
        if cnt > 0:
            ac = np.mean(test_conf[in_bin])
            aa = np.mean(test_y_pred[in_bin] == test_y_true[in_bin])
            test_ece += (cnt / len(test_y_true)) * abs(aa - ac)

    print(f"Test Expected Calibration Error (ECE): {test_ece*100:.2f}% ({test_ece:.4f})")

    t_unc_conf = test_conf < CottonDomainGate.LOW_CONFIDENCE_THRESHOLD
    t_unc_margin = test_margins < CottonDomainGate.UNCERTAINTY_MARGIN
    t_unc_any = t_unc_conf | t_unc_margin
    print(f"Test Flagged Uncertain: {np.sum(t_unc_any)} / {len(test_y_true)} ({np.sum(t_unc_any)/len(test_y_true)*100:.1f}%)")
    acc_test_conf = np.mean(test_y_pred[~t_unc_any] == test_y_true[~t_unc_any])
    acc_test_unc = np.mean(test_y_pred[t_unc_any] == test_y_true[t_unc_any])
    print(f"Test Accuracy for Confident: {acc_test_conf*100:.2f}% ({np.sum(test_y_pred[~t_unc_any] == test_y_true[~t_unc_any])}/{np.sum(~t_unc_any)})")
    print(f"Test Accuracy for Uncertain: {acc_test_unc*100:.2f}% ({np.sum(test_y_pred[t_unc_any] == test_y_true[t_unc_any])}/{np.sum(t_unc_any)})")

    # Find candidate images for Endpoint Testing:
    # 1. Confident Correct Image
    # 2. Confident Incorrect Image (if any) or regular incorrect
    # 3. Ambiguous / Low-confidence Image
    correct_mask = (test_y_pred == test_y_true)
    incorrect_mask = (test_y_pred != test_y_true)

    # Pick samples
    # Most confident correct
    conf_correct_idx = np.where(correct_mask)[0][np.argmax(test_conf[correct_mask])]
    # Ambiguous sample (lowest margin)
    ambiguous_idx = np.argmin(test_margins)
    # Low confidence sample
    lowest_conf_idx = np.argmin(test_conf)
    # An incorrect sample
    incorrect_idx = np.where(incorrect_mask)[0][0]

    sample_indices = {
        "Confident Correct": conf_correct_idx,
        "Ambiguous Margin": ambiguous_idx,
        "Lowest Confidence": lowest_conf_idx,
        "Incorrect Prediction": incorrect_idx
    }

    print("\nSelected Representative Test Samples:")
    for name, s_idx in sample_indices.items():
        print(f"  [{name}]: {test_files[s_idx]}")
        print(f"    True: {CANONICAL_CLASSES[test_y_true[s_idx]]} | Pred: {CANONICAL_CLASSES[test_y_pred[s_idx]]}")
        print(f"    Conf: {test_conf[s_idx]:.4f} | Margin: {test_margins[s_idx]:.4f}")

    return sample_indices, test_files

def run_endpoint_audit(sample_indices, test_files):
    print("\n" + "=" * 80)
    print("STAGE 3: LIVE FASTAPI ENDPOINT INFERENCE & AGRONOMIC SAFETY VERIFICATION")
    print("=" * 80)

    client = TestClient(app)

    # 1. Verify health endpoint
    health_resp = client.get("/health")
    assert health_resp.status_code == 200, f"Health check failed: {health_resp.status_code}"
    health_data = health_resp.json()
    print("FastAPI Health Endpoint Response:")
    print(f"  Status: {health_data.get('status')}")
    print(f"  Model: {health_data.get('model')}")
    print(f"  Engine: {health_data.get('engine')}")
    print(f"  Ready: {health_data.get('disease_model_ready')}")

    # 2. Test each representative image
    for category, idx in sample_indices.items():
        img_path = test_files[idx]
        print(f"\n--- Testing Endpoint with: {category} ---")
        print(f"File: {img_path}")

        with open(img_path, "rb") as f:
            img_bytes = f.read()

        response = client.post(
            "/predict",
            files={"file": (os.path.basename(img_path), img_bytes, "image/jpeg")}
        )

        assert response.status_code == 200, f"Endpoint returned error: {response.status_code} - {response.text}"
        data = response.json()

        print(f"  HTTP Status: {response.status_code}")
        print(f"  Predicted Class: {data.get('predicted_class')}")
        print(f"  Confidence: {data.get('confidence')}")
        print(f"  is_low_confidence: {data.get('is_low_confidence')}")
        print(f"  Severity: {data.get('severity')}")
        print(f"  Latency: {data.get('latency_ms')} ms")
        print(f"  Summary: {data.get('summary')[:80]}...")
        print(f"  Treatment (first item): {data.get('treatment')[0]}")

        # Safety Check: If uncertain, verify chemical advice is suppressed
        if data.get("is_low_confidence"):
            assert "Do NOT apply chemical pesticides" in data.get("treatment")[0], (
                "CRITICAL FAILURE: Uncertain prediction did NOT suppress chemical pesticide recommendation!"
            )
            assert "Unable to confidently identify" in data.get("summary"), (
                "CRITICAL FAILURE: Summary did not disclose uncertain diagnosis!"
            )
            print("  >>> [SAFETY CHECK PASSED]: Chemical pesticides safely suppressed for uncertain diagnosis.")
        else:
            print("  >>> [CONFIDENT PREDICTION]: Full disease-specific agronomic advice returned.")

    # 3. Test non-cotton image domain rejection and quality gate rejection
    print("\n--- Testing Quality Gate Rejection (Blur/Uniform) ---")
    synthetic_arr = np.ones((300, 300, 3), dtype=np.uint8) * 128
    synthetic_pil = Image.fromarray(synthetic_arr)
    import io
    buf = io.BytesIO()
    synthetic_pil.save(buf, format="JPEG")
    synthetic_bytes = buf.getvalue()

    blur_resp = client.post(
        "/predict",
        files={"file": ("synthetic.jpg", synthetic_bytes, "image/jpeg")}
    )
    print(f"Flat image HTTP Status: {blur_resp.status_code}")
    print(f"Flat response: {blur_resp.json()}")
    assert blur_resp.status_code == 422, "Flat image should be rejected with 422"
    assert blur_resp.json()["detail"]["code"] == "POOR_QUALITY"
    print("  >>> [QUALITY GATE PASSED]: Flat/blurry input correctly rejected with 422 POOR_QUALITY.")

    print("\n--- Testing Cotton-Only Domain Gate Rejection (Sharp Non-Leaf) ---")
    # High-contrast grid with high Laplacian variance (> 100), but 0 leaf foliage
    sharp_non_leaf = np.zeros((300, 300, 3), dtype=np.uint8)
    sharp_non_leaf[::10, :] = 255
    sharp_non_leaf[:, ::10] = 255
    sharp_non_leaf[:, :, 1] = 0 # zero green channel
    sharp_non_leaf[:, :, 2] = 255 # pure blue/purple grid
    
    buf2 = io.BytesIO()
    Image.fromarray(sharp_non_leaf).save(buf2, format="JPEG")
    sharp_bytes = buf2.getvalue()

    non_leaf_resp = client.post(
        "/predict",
        files={"file": ("sharp_blue.jpg", sharp_bytes, "image/jpeg")}
    )
    print(f"Sharp blue image HTTP Status: {non_leaf_resp.status_code}")
    print(f"Sharp blue response: {non_leaf_resp.json()}")
    assert non_leaf_resp.status_code == 422, "Non-leaf image should be rejected with 422"
    assert non_leaf_resp.json()["detail"]["code"] == "NON_COTTON"
    print("  >>> [DOMAIN GATE PASSED]: Sharp non-cotton input correctly rejected with 422 NON_COTTON.")

if __name__ == "__main__":
    samples, t_files = run_calibration_audit()
    run_endpoint_audit(samples, t_files)
