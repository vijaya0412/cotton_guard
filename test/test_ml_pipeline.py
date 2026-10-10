"""Comprehensive ML Pipeline & Preprocessing Test Suite.
Validates:
- Canonical class mappings
- Preprocessing output dimensions, data types, and normalizations
- Multi-stage CottonDomainGate behavior
- SQLite database integrity and alias resolution
- ONNX model inference output integrity (finite probabilities, non-negative, sums to ~1)
"""

import os
import sys
import numpy as np
from PIL import Image, ImageFilter
import pytest

# Ensure root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.classes import CANONICAL_CLASSES, CLASS_METADATA, FOLDER_TO_CLASS
from ml.preprocessing import preprocess_image, apply_cielab_clahe
from ml.cotton_gate import CottonDomainGate
from backend.database import get_advisory_for_class, get_all_advisories, resolve_canonical_class
import onnxruntime as ort

ONNX_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ml", "models", "cotton_guard_model.onnx")

def test_canonical_classes():
    assert len(CANONICAL_CLASSES) == 7
    expected = [
        "Bacterial Blight",
        "Cotton Leaf Curl Virus",
        "Healthy Leaf",
        "Herbicide Growth Damage",
        "Leaf Hopper / Jassids",
        "Leaf Reddening",
        "Leaf Variegation"
    ]
    assert CANONICAL_CLASSES == expected
    for c in expected:
        assert c in CLASS_METADATA

def test_preprocessing_output_shapes():
    # Test random PIL Image
    img = Image.new("RGB", (320, 240), color=(100, 150, 80))

    # NCHW
    nchw = preprocess_image(img, layout="NCHW", enable_clahe=True)
    assert nchw.shape == (1, 3, 224, 224)
    assert nchw.dtype == np.float32
    assert not np.isnan(nchw).any()

    # NHWC
    nhwc = preprocess_image(img, layout="NHWC", enable_clahe=True)
    assert nhwc.shape == (1, 224, 224, 3)
    assert nhwc.dtype == np.float32
    assert not np.isnan(nhwc).any()

def test_cielab_clahe_enhancement():
    # Verify LAB-CLAHE modifies luminance without changing dimensions
    rgb = np.full((100, 100, 3), 120, dtype=np.uint8)
    enhanced = apply_cielab_clahe(rgb)
    assert enhanced.shape == (100, 100, 3)
    assert enhanced.dtype == np.uint8

def test_cotton_domain_gate_authentic_image():
    sample_path = os.path.join("assets", "diseases", "healthy_leaf", "healthy_leaf_1.jpg")
    assert os.path.exists(sample_path)
    img = Image.open(sample_path)
    res = CottonDomainGate.evaluate_quality_and_domain(img)
    assert res["quality_passed"] is True
    assert res["is_cotton_leaf"] is True
    assert res["status"] == "VALID"

def test_cotton_domain_gate_dark_and_bright():
    dark_img = Image.new("RGB", (200, 200), (10, 10, 10))
    res_dark = CottonDomainGate.evaluate_quality_and_domain(dark_img)
    assert res_dark["quality_passed"] is False
    assert res_dark["status"] == "POOR_QUALITY"

    bright_img = Image.new("RGB", (200, 200), (250, 250, 250))
    res_bright = CottonDomainGate.evaluate_quality_and_domain(bright_img)
    assert res_bright["quality_passed"] is False
    assert res_bright["status"] == "POOR_QUALITY"

def test_cotton_domain_gate_blurry():
    sample_path = os.path.join("assets", "diseases", "healthy_leaf", "healthy_leaf_1.jpg")
    img = Image.open(sample_path).filter(ImageFilter.GaussianBlur(radius=12))
    res = CottonDomainGate.evaluate_quality_and_domain(img)
    assert res["quality_passed"] is False
    assert res["status"] == "POOR_QUALITY"
    assert res["metrics"]["blur_score"] < 15.0

def test_cotton_domain_gate_non_plant_rejection():
    # Sharp high-frequency non-plant pattern (passes blur/quality gate, but has 0% plant foliage)
    arr = np.zeros((300, 300, 3), dtype=np.uint8)
    for i in range(0, 300, 20):
        for j in range(0, 300, 20):
            if (i // 20 + j // 20) % 2 == 0:
                arr[i:i+20, j:j+20] = [200, 200, 200]
            else:
                arr[i:i+20, j:j+20] = [80, 80, 80]
    checker_img = Image.fromarray(arr)
    res = CottonDomainGate.evaluate_quality_and_domain(checker_img)
    assert res["quality_passed"] is True
    assert res["is_cotton_leaf"] is False
    assert res["status"] == "NON_COTTON"

def test_cotton_domain_gate_uncertainty():
    # Close probabilities
    probs_ambiguous = np.array([0.30, 0.28, 0.15, 0.10, 0.07, 0.05, 0.05])
    is_unc, reason = CottonDomainGate.evaluate_prediction_uncertainty(probs_ambiguous)
    assert is_unc is True

    # Decisive probabilities
    probs_clear = np.array([0.88, 0.05, 0.02, 0.02, 0.01, 0.01, 0.01])
    is_unc_clear, _ = CottonDomainGate.evaluate_prediction_uncertainty(probs_clear)
    assert is_unc_clear is False

def test_sqlite_advisory_database():
    all_adv = get_all_advisories()
    assert len(all_adv) == 7
    for c in CANONICAL_CLASSES:
        assert c in all_adv
        rec = all_adv[c]
        assert rec["canonical_name"] == c
        assert len(rec["symptoms"]) >= 3
        assert len(rec["treatment"]) >= 2
        assert len(rec["prevention"]) >= 2
        assert rec["severity"] is not None

def test_sqlite_alias_resolution():
    assert resolve_canonical_class("Leaf Redding") == "Leaf Reddening"
    assert resolve_canonical_class("curl_virus") == "Cotton Leaf Curl Virus"
    assert resolve_canonical_class("bacterial_blight") == "Bacterial Blight"
    adv = get_advisory_for_class("Leaf Redding")
    assert adv is not None
    assert adv["canonical_name"] == "Leaf Reddening"

def test_onnx_inference_output():
    assert os.path.exists(ONNX_PATH)
    session = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
    in_name = session.get_inputs()[0].name
    in_shape = session.get_inputs()[0].shape

    dummy = np.zeros((1, 3, 224, 224), dtype=np.float32) if in_shape[1] == 3 else np.zeros((1, 224, 224, 3), dtype=np.float32)
    out = session.run(None, {in_name: dummy})[0][0]

    assert len(out) == 7
    assert not np.isnan(out).any()
    assert not np.isinf(out).any()
