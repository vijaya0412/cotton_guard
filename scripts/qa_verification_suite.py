"""Comprehensive QA Verification Script for Cotton Guard ML & Backend."""

import os
import sys
import io
import time
import json

# Ensure project root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import numpy as np
from PIL import Image, ImageFilter
import onnxruntime as ort

from ml.classes import CANONICAL_CLASSES, CLASS_METADATA, FOLDER_TO_CLASS
from ml.quality_gate import ImageQualityGate
import torchvision.models as models
import torch.nn as nn
from torchvision import transforms

def main():
    print("=" * 60)
    print("COTTON GUARD QA VERIFICATION SUITE")
    print("=" * 60)

    # 1. Models and Classes
    pt_path = os.path.join("ml", "models", "cotton_guard_model.pt")
    onnx_path = os.path.join("ml", "models", "cotton_guard_model.onnx")

    assert os.path.exists(pt_path), f"Missing PyTorch model at {pt_path}"
    assert os.path.exists(onnx_path), f"Missing ONNX model at {onnx_path}"

    pt_size_mb = os.path.getsize(pt_path) / (1024 * 1024)
    onnx_size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"[Model Files] PyTorch: {pt_size_mb:.2f} MB | ONNX: {onnx_size_mb:.2f} MB")

    # Load PyTorch Model
    pt_model = models.mobilenet_v2(weights=None)
    pt_model.classifier[1] = nn.Linear(pt_model.last_channel, len(CANONICAL_CLASSES))
    checkpoint = torch.load(pt_path, map_location="cpu")
    pt_model.load_state_dict(checkpoint["state_dict"])
    pt_model.eval()

    # Load ONNX Session
    ort_session = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    ort_input_name = ort_session.get_inputs()[0].name

    # Preprocessing
    torch_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])

    def preprocess_numpy(pil_img):
        resized = pil_img.convert("RGB").resize((224, 224), Image.Resampling.BILINEAR)
        arr = np.array(resized, dtype=np.float32) / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
        norm = (arr - mean) / std
        transposed = np.transpose(norm, (2, 0, 1))
        return np.expand_dims(transposed, axis=0)

    # Collect all 28 authentic images
    dataset_dir = os.path.join("assets", "diseases")
    all_images = []
    for folder in os.listdir(dataset_dir):
        folder_path = os.path.join(dataset_dir, folder)
        if os.path.isdir(folder_path):
            expected_class = FOLDER_TO_CLASS.get(folder)
            for fname in os.listdir(folder_path):
                if fname.lower().endswith((".jpg", ".jpeg", ".png")):
                    all_images.append({
                        "path": os.path.join(folder_path, fname),
                        "folder": folder,
                        "expected_class": expected_class,
                        "filename": fname
                    })

    print(f"\n[Dataset] Total authentic test images collected: {len(all_images)}")

    # 2. PyTorch vs ONNX Parity Test
    parity_matches = 0
    max_prob_diff = 0.0
    sum_prob_diff = 0.0
    pt_latencies = []
    onnx_latencies = []

    print("\n--- 4. PYTORCH / ONNX PARITY EVALUATION ---")
    for item in all_images:
        pil_img = Image.open(item["path"]).convert("RGB")
        
        # PyTorch Inference
        t0 = time.perf_counter()
        pt_input = torch_transform(pil_img).unsqueeze(0)
        with torch.no_grad():
            pt_out = pt_model(pt_input)
            pt_probs = torch.softmax(pt_out, dim=1).numpy()[0]
        pt_lat = (time.perf_counter() - t0) * 1000.0
        pt_latencies.append(pt_lat)

        # ONNX Inference
        t0 = time.perf_counter()
        onnx_input = preprocess_numpy(pil_img)
        onnx_out = ort_session.run(None, {ort_input_name: onnx_input})[0][0]
        exp_logits = np.exp(onnx_out - np.max(onnx_out))
        onnx_probs = exp_logits / np.sum(exp_logits)
        onnx_lat = (time.perf_counter() - t0) * 1000.0
        onnx_latencies.append(onnx_lat)

        pt_pred = int(np.argmax(pt_probs))
        onnx_pred = int(np.argmax(onnx_probs))

        if pt_pred == onnx_pred:
            parity_matches += 1

        prob_diff = np.max(np.abs(pt_probs - onnx_probs))
        sum_prob_diff += np.mean(np.abs(pt_probs - onnx_probs))
        if prob_diff > max_prob_diff:
            max_prob_diff = prob_diff

    agreement_pct = (parity_matches / len(all_images)) * 100.0
    avg_prob_diff = sum_prob_diff / len(all_images)
    avg_pt_lat = np.mean(pt_latencies)
    avg_onnx_lat = np.mean(onnx_latencies)

    print(f"Tested Images: {len(all_images)}")
    print(f"Class Agreement: {agreement_pct:.2f}% ({parity_matches}/{len(all_images)})")
    print(f"Max Probability Difference: {max_prob_diff:.8f}")
    print(f"Average Probability Difference: {avg_prob_diff:.8f}")
    print(f"Average PyTorch Latency: {avg_pt_lat:.2f} ms")
    print(f"Average ONNX Latency: {avg_onnx_lat:.2f} ms")

    # 3. Real Disease Images Evaluation
    print("\n--- 5. REAL DISEASE IMAGES EVALUATION ---")
    class_results = {cls_name: {"total": 0, "correct": 0} for cls_name in CANONICAL_CLASSES}
    sample_records = []

    for item in all_images:
        pil_img = Image.open(item["path"]).convert("RGB")
        onnx_input = preprocess_numpy(pil_img)
        onnx_out = ort_session.run(None, {ort_input_name: onnx_input})[0][0]
        exp_logits = np.exp(onnx_out - np.max(onnx_out))
        onnx_probs = exp_logits / np.sum(exp_logits)
        pred_idx = int(np.argmax(onnx_probs))
        pred_class = CANONICAL_CLASSES[pred_idx]
        conf = float(onnx_probs[pred_idx])

        is_correct = (pred_class == item["expected_class"])
        class_results[item["expected_class"]]["total"] += 1
        if is_correct:
            class_results[item["expected_class"]]["correct"] += 1

        sample_records.append({
            "image": item["filename"],
            "folder": item["folder"],
            "expected_class": item["expected_class"],
            "predicted_class": pred_class,
            "confidence": f"{conf * 100:.2f}%",
            "correct": is_correct
        })

    for r in sample_records:
        status = "CORRECT" if r["correct"] else "INCORRECT"
        print(f"[{status:9s}] {r['folder']}/{r['image']:20s} | Exp: {r['expected_class']:24s} | Pred: {r['predicted_class']:24s} | Conf: {r['confidence']}")

    print("\nPer-Class Accuracy Breakdown across the 28 authentic images:")
    for cls_name, counts in class_results.items():
        acc = (counts["correct"] / counts["total"] * 100) if counts["total"] > 0 else 0
        print(f"  {cls_name:24s}: {counts['correct']}/{counts['total']} ({acc:.1f}%)")

    # 4. Gatekeeper Testing
    print("\n--- 6. IMAGE GATEKEEPER VERIFICATION ---")
    gate_cases = []

    # Case 1: Valid cotton leaf
    valid_img = Image.open(all_images[0]["path"])
    gate_cases.append(("Valid cotton leaf", valid_img, "VALID"))

    # Case 2: Blurry image
    blurry_img = valid_img.filter(ImageFilter.GaussianBlur(radius=15))
    gate_cases.append(("Blurry image", blurry_img, "POOR_QUALITY"))

    # Case 3: Very dark image
    dark_img = Image.new("RGB", (250, 250), color=(10, 10, 10))
    gate_cases.append(("Very dark image (brightness < 30)", dark_img, "POOR_QUALITY"))

    # Case 4: Very bright image
    bright_img = Image.new("RGB", (250, 250), color=(250, 250, 250))
    gate_cases.append(("Very bright image (brightness > 245)", bright_img, "POOR_QUALITY"))

    # Case 5: Low-resolution image
    low_res_img = Image.new("RGB", (100, 100), color=(50, 120, 50))
    gate_cases.append(("Low-resolution image (< 150x150)", low_res_img, "POOR_QUALITY"))

    # Case 6: Non-plant image (blue square / concrete noise)
    non_plant_img = Image.new("RGB", (250, 250), color=(30, 80, 200))
    gate_cases.append(("Non-plant synthetic blue image", non_plant_img, "NON_COTTON"))

    # Case 7: Non-leaf monochrome grey texture
    grey_noise = np.random.randint(100, 150, (250, 250, 3), dtype=np.uint8)
    grey_noise_img = Image.fromarray(grey_noise)
    gate_cases.append(("Non-plant grey noise texture", grey_noise_img, "NON_COTTON"))

    # Run evaluations
    for name, img, expected_status in gate_cases:
        res = ImageQualityGate.evaluate_image(img)
        actual_status = res["status"]
        matched = (actual_status == expected_status)
        print(f"[{'PASS' if matched else 'FAIL'}] {name:38s} -> Status: {actual_status:12s} | Exp: {expected_status:12s} | Msg: {res['message'][:50]}...")

    print("\nVerification suite completed.")

if __name__ == "__main__":
    main()
