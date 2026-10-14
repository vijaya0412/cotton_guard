"""Lightweight cotton-vs-other leaf classifier using OpenCV HOG + HSV features.

The seven-class disease model remains untouched. Train this separate binary model
with ml/train_cotton_domain_classifier.py before deployment.
"""
from pathlib import Path
from typing import Tuple
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "models" / "cotton_domain_svm.yml"
_HOG = cv2.HOGDescriptor(
    (64, 64), (16, 16), (8, 8), (8, 8), 9
)


def extract_features(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB").resize((64, 64), Image.Resampling.BILINEAR))
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    hog = _HOG.compute(gray).reshape(-1).astype(np.float32)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hist = cv2.calcHist([hsv], [0, 1], None, [12, 4], [0, 180, 0, 256]).reshape(-1)
    hist = hist.astype(np.float32)
    hist /= max(float(hist.sum()), 1.0)
    return np.concatenate([hog, hist]).astype(np.float32).reshape(1, -1)


def load_model():
    if not MODEL_PATH.is_file():
        return None
    try:
        return cv2.ml.SVM_load(str(MODEL_PATH))
    except cv2.error:
        return None


def classify_cotton(image: Image.Image) -> Tuple[bool, str]:
    """Return (is_cotton, reason); None model means not yet trained/deployed."""
    model = load_model()
    if model is None:
        return True, "Binary cotton-domain model is not installed; legacy heuristic used."
    _, result = model.predict(extract_features(image))
    if int(round(float(result[0, 0]))) != 1:
        return False, "This does not appear to be a cotton leaf. Please upload a clear image of a cotton leaf."
    return True, "Cotton-domain classifier passed."
