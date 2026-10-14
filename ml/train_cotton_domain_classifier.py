"""Train a separate cotton-vs-non-cotton gate; does not alter the disease model.
Run from repository root: .venv-1/bin/python ml/train_cotton_domain_classifier.py
"""
from pathlib import Path
import random
import sys
import cv2
import numpy as np
from PIL import Image, UnidentifiedImageError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from ml.cotton_domain_classifier import extract_features, MODEL_PATH

COTTON_DIR = ROOT / "dataset" / "split" / "train"
NON_COTTON_DIR = ROOT / "dataset" / "non_cotton_external" / "selected" / "raw" / "color"
MAX_PER_NON_COTTON_CLASS = 60
SEED = 42


def collect_images():
    if not COTTON_DIR.is_dir():
        raise SystemExit(f"Missing cotton training data: {COTTON_DIR}")
    if not NON_COTTON_DIR.is_dir():
        raise SystemExit(f"Missing non-cotton data: {NON_COTTON_DIR}")
    rows = []
    for class_dir in sorted(p for p in COTTON_DIR.iterdir() if p.is_dir()):
        paths = [p for p in class_dir.rglob('*') if p.suffix.lower() in {'.jpg','.jpeg','.png','.webp'}]
        rows.extend((p, 1) for p in paths)
    rng = random.Random(SEED)
    for class_dir in sorted(p for p in NON_COTTON_DIR.iterdir() if p.is_dir()):
        paths = [p for p in class_dir.rglob('*') if p.suffix.lower() in {'.jpg','.jpeg','.png','.webp'}]
        rng.shuffle(paths)
        rows.extend((p, -1) for p in paths[:MAX_PER_NON_COTTON_CLASS])
    rng.shuffle(rows)
    return rows


def main():
    rows = collect_images()
    features, labels = [], []
    skipped = 0
    print(f"Extracting features from {len(rows)} images...", flush=True)
    for i, (path, label) in enumerate(rows, 1):
        try:
            with Image.open(path) as im:
                features.append(extract_features(im.copy())[0])
            labels.append(label)
        except (OSError, ValueError, UnidentifiedImageError, cv2.error):
            skipped += 1
        if i % 250 == 0:
            print(f"  {i}/{len(rows)}", flush=True)
    X = np.asarray(features, dtype=np.float32)
    y = np.asarray(labels, dtype=np.int32)
    if len(set(y.tolist())) != 2 or len(y) < 100:
        raise SystemExit("Not enough usable images from both cotton and non-cotton datasets.")
    # Holdout evaluation before fitting final model.
    rng = np.random.default_rng(SEED)
    indices = rng.permutation(len(y))
    cut = int(len(indices) * 0.8)
    train_idx, test_idx = indices[:cut], indices[cut:]
    svm = cv2.ml.SVM_create()
    svm.setType(cv2.ml.SVM_C_SVC)
    svm.setKernel(cv2.ml.SVM_LINEAR)
    svm.setC(0.5)
    svm.train(X[train_idx], cv2.ml.ROW_SAMPLE, y[train_idx])
    _, pred = svm.predict(X[test_idx])
    pred = pred.reshape(-1).astype(np.int32)
    actual = y[test_idx]
    accuracy = float(np.mean(pred == actual))
    cotton_recall = float(np.mean(pred[actual == 1] == 1)) if np.any(actual == 1) else 0.0
    noncotton_recall = float(np.mean(pred[actual == -1] == -1)) if np.any(actual == -1) else 0.0
    print(f"Holdout accuracy: {accuracy:.3f}; cotton recall: {cotton_recall:.3f}; non-cotton rejection recall: {noncotton_recall:.3f}; skipped: {skipped}")
    # Train final model on all samples.
    final = cv2.ml.SVM_create()
    final.setType(cv2.ml.SVM_C_SVC)
    final.setKernel(cv2.ml.SVM_LINEAR)
    final.setC(0.5)
    final.train(X, cv2.ml.ROW_SAMPLE, y)
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    final.save(str(MODEL_PATH))
    print(f"Saved binary gate: {MODEL_PATH}")
    if accuracy < 0.85 or cotton_recall < 0.85 or noncotton_recall < 0.85:
        print("WARNING: Holdout metric below 0.85. Do not deploy until you improve data/features and retest.")

if __name__ == '__main__':
    main()
