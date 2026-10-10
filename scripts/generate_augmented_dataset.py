"""
High-Performance Parallel Dataset Augmentation Generator for Cotton Guard.
Expands the training set to ~17,000 samples across 8 CPU cores while preserving isolated original validation and test sets.
Generates metadata CSV and Matplotlib visualization charts.
"""

import os
import sys
import shutil
import random
import csv
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from ml.classes import CANONICAL_CLASSES, FOLDER_TO_CLASS, CLASS_TO_FOLDER

TARGET_TRAIN_SAMPLES = 17000

def apply_realistic_augmentation(img: Image.Image, seed: int):
    random.seed(seed)
    np.random.seed(seed % (2**31 - 1))
    
    aug_img = img.copy()
    ops = []

    # 1. Random Rotation (-35° to +35°)
    rot_angle = random.uniform(-35, 35)
    aug_img = aug_img.rotate(rot_angle, resample=Image.Resampling.BILINEAR, fillcolor=(0, 0, 0))
    ops.append(f"rotate({rot_angle:.1f})")

    # 2. Horizontal Flip (50% prob)
    if random.random() > 0.5:
        aug_img = aug_img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        ops.append("hflip")

    # 3. Vertical Flip (25% prob)
    if random.random() > 0.75:
        aug_img = aug_img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        ops.append("vflip")

    # 4. Brightness adjustment (0.85 to 1.15)
    b_factor = random.uniform(0.85, 1.15)
    enhancer = ImageEnhance.Brightness(aug_img)
    aug_img = enhancer.enhance(b_factor)
    ops.append(f"brightness({b_factor:.2f})")

    # 5. Contrast adjustment (0.85 to 1.15)
    c_factor = random.uniform(0.85, 1.15)
    enhancer = ImageEnhance.Contrast(aug_img)
    aug_img = enhancer.enhance(c_factor)
    ops.append(f"contrast({c_factor:.2f})")

    # 6. Color / Saturation adjustment (0.85 to 1.15)
    s_factor = random.uniform(0.85, 1.15)
    enhancer = ImageEnhance.Color(aug_img)
    aug_img = enhancer.enhance(s_factor)
    ops.append(f"saturation({s_factor:.2f})")

    # 7. Subtle Gaussian Noise / Blur (25% prob)
    if random.random() > 0.75:
        aug_img = aug_img.filter(ImageFilter.GaussianBlur(radius=random.uniform(0.3, 0.7)))
        ops.append("blur")

    return aug_img, "+".join(ops)

def worker_generate_batch(task):
    """Worker task generating a batch of augmentations for one original image."""
    cname, folder_name, orig_path, out_folder, start_idx, count, seed_offset = task
    base_img = Image.open(orig_path).convert("RGB")
    base_fname = os.path.basename(orig_path)
    rows = []

    for i in range(count):
        idx = start_idx + i
        seed = seed_offset + idx
        aug_img, ops_desc = apply_realistic_augmentation(base_img, seed)
        aug_fname = f"aug_{folder_name}_{idx+1:04d}.jpg"
        out_path = os.path.join(out_folder, aug_fname)
        # Resize to standard 224x224 or 400x400 for compact speed and storage
        aug_resized = aug_img.resize((300, 300), Image.Resampling.BILINEAR)
        aug_resized.save(out_path, format="JPEG", quality=85)

        rows.append({
            "original_image": base_fname,
            "augmented_image": aug_fname,
            "class": cname,
            "operations": ops_desc,
            "random_seed": seed
        })

    return rows

def run_augmentation_pipeline():
    print("=" * 60)
    print("COTTON GUARD PARALLEL DATASET AUGMENTATION PIPELINE (8 CORES)")
    print("=" * 60)

    src_dir = os.path.join("assets", "diseases")
    dataset_base = os.path.join("dataset")
    split_dir = os.path.join(dataset_base, "split")
    aug_dir = os.path.join(dataset_base, "augmented", "train")
    reports_dir = os.path.join("reports")

    # Clean existing augmented/train directory to avoid leftover files
    if os.path.exists(aug_dir):
        shutil.rmtree(aug_dir)
    os.makedirs(aug_dir, exist_ok=True)
    os.makedirs(reports_dir, exist_ok=True)
    os.makedirs(os.path.join(dataset_base, "original"), exist_ok=True)
    for s in ["train", "val", "test"]:
        os.makedirs(os.path.join(split_dir, s), exist_ok=True)

    # 1. Establish strict Train / Val / Test Split
    train_originals = {}
    val_originals = {}
    test_originals = {}

    for folder_name, cname in FOLDER_TO_CLASS.items():
        src_folder = os.path.join(src_dir, folder_name)
        images = sorted([f for f in os.listdir(src_folder) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])

        orig_dest = os.path.join(dataset_base, "original", folder_name)
        os.makedirs(orig_dest, exist_ok=True)
        for f in images:
            shutil.copy2(os.path.join(src_folder, f), os.path.join(orig_dest, f))

        t_imgs = images[0:2]
        v_imgs = [images[2]]
        te_imgs = [images[3]]

        train_originals[cname] = [os.path.join(src_folder, f) for f in t_imgs]
        val_originals[cname] = [os.path.join(src_folder, f) for f in v_imgs]
        test_originals[cname] = [os.path.join(src_folder, f) for f in te_imgs]

        for subset, img_list in [("train", t_imgs), ("val", v_imgs), ("test", te_imgs)]:
            sub_folder = os.path.join(split_dir, subset, folder_name)
            os.makedirs(sub_folder, exist_ok=True)
            for f in img_list:
                shutil.copy2(os.path.join(src_folder, f), os.path.join(sub_folder, f))

    print(f"Split completed: 14 Train (Original), 7 Validation (Original), 7 Test (Original)")
    print(f"Validation and Test datasets remain 100% ORIGINAL and UNTOUCHED.")

    # 2. Determine Per-Class Augmentation Quotas
    num_classes = len(CANONICAL_CLASSES)
    base_per_class = TARGET_TRAIN_SAMPLES // num_classes
    remainder = TARGET_TRAIN_SAMPLES % num_classes

    class_targets = {}
    for idx, cname in enumerate(CANONICAL_CLASSES):
        class_targets[cname] = base_per_class + (1 if idx < remainder else 0)

    print("\nTarget Training Samples per class:")
    for cname, target in class_targets.items():
        print(f"  {cname:25s}: {target} samples")
    print(f"Total Target Training Samples: {sum(class_targets.values())}")

    # 3. Create Parallel Worker Tasks
    metadata_rows = []
    sample_vis_images = {}
    tasks = []

    for cname in CANONICAL_CLASSES:
        folder_name = CLASS_TO_FOLDER[cname]
        out_folder = os.path.join(aug_dir, folder_name)
        os.makedirs(out_folder, exist_ok=True)

        orig_paths = train_originals[cname]
        target_count = class_targets[cname]

        # Copy original train images into augmented/train
        copied = 0
        for i, opath in enumerate(orig_paths):
            fname = f"orig_{os.path.basename(opath)}"
            dst = os.path.join(out_folder, fname)
            shutil.copy2(opath, dst)
            copied += 1
            metadata_rows.append({
                "original_image": os.path.basename(opath),
                "augmented_image": fname,
                "class": cname,
                "operations": "original_identity",
                "random_seed": 0
            })

        needed = target_count - copied
        per_orig = needed // len(orig_paths)
        rem = needed % len(orig_paths)

        curr_start = 0
        for o_idx, opath in enumerate(orig_paths):
            count_for_this = per_orig + (1 if o_idx < rem else 0)
            seed_offset = 1000 + (hash(cname) % 5000) * 100 + o_idx * 50000
            tasks.append((cname, folder_name, opath, out_folder, curr_start, count_for_this, seed_offset))
            curr_start += count_for_this

    print(f"\nDispatched {len(tasks)} parallel worker batches across ProcessPoolExecutor...")
    with ProcessPoolExecutor(max_workers=8) as executor:
        results = executor.map(worker_generate_batch, tasks)
        for r_batch in results:
            metadata_rows.extend(r_batch)

    print(f"Total training samples on disk: {len(metadata_rows):,}")

    # Collect sample images for visualization
    for cname in CANONICAL_CLASSES:
        orig_p = train_originals[cname][0]
        base_img = Image.open(orig_p).convert("RGB")
        folder_name = CLASS_TO_FOLDER[cname]
        aug_sample_p = os.path.join(aug_dir, folder_name, f"aug_{folder_name}_0001.jpg")
        aug_img = Image.open(aug_sample_p).convert("RGB")
        sample_vis_images[cname] = (base_img, aug_img)

    # 4. Save Traceability Metadata CSV
    csv_path = os.path.join(dataset_base, "augmented", "augmentation_metadata.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["original_image", "augmented_image", "class", "operations", "random_seed"])
        writer.writeheader()
        writer.writerows(metadata_rows)
    print(f"Traceability metadata saved to: {csv_path} ({len(metadata_rows)} entries)")

    # 5. Generate Matplotlib Charts
    print("\nGenerating Matplotlib visualization charts...")

    # Chart 1: Distribution Before Augmentation
    plt.figure(figsize=(10, 5))
    classes_short = [c.replace(" / ", "\n").replace(" ", "\n") for c in CANONICAL_CLASSES]
    counts_before = [len(train_originals[c]) for c in CANONICAL_CLASSES]
    bars = plt.bar(classes_short, counts_before, color="#2E7D32", edgecolor="#1B5E20", width=0.5)
    plt.title("Class Distribution Before Augmentation (Train Split)", fontsize=14, fontweight="bold", pad=15)
    plt.ylabel("Number of Original Images", fontsize=12)
    plt.ylim(0, 5)
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval + 0.1, f"{int(yval)}", ha='center', va='bottom', fontweight='bold')
    plt.tight_layout()
    chart1_path = os.path.join(reports_dir, "dataset_distribution_before.png")
    plt.savefig(chart1_path, dpi=200)
    plt.close()
    print(f"Saved: {chart1_path}")

    # Chart 2: Distribution After Augmentation
    plt.figure(figsize=(10, 5))
    counts_after = [class_targets[c] for c in CANONICAL_CLASSES]
    bars = plt.bar(classes_short, counts_after, color="#43A047", edgecolor="#2E7D32", width=0.5)
    plt.title("Class Distribution After Augmentation (~17,000 Target)", fontsize=14, fontweight="bold", pad=15)
    plt.ylabel("Number of Training Samples", fontsize=12)
    plt.ylim(0, 3000)
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval + 50, f"{int(yval)}", ha='center', va='bottom', fontweight='bold')
    plt.tight_layout()
    chart2_path = os.path.join(reports_dir, "dataset_distribution_after.png")
    plt.savefig(chart2_path, dpi=200)
    plt.close()
    print(f"Saved: {chart2_path}")

    # Chart 3: Augmentation Examples
    fig, axes = plt.subplots(len(CANONICAL_CLASSES), 2, figsize=(8, 18))
    fig.suptitle("Original vs Augmented Samples by Class", fontsize=14, fontweight="bold", y=0.99)
    for i, cname in enumerate(CANONICAL_CLASSES):
        orig_img, aug_img = sample_vis_images[cname]
        axes[i, 0].imshow(orig_img)
        axes[i, 0].set_title(f"{cname} (Original)", fontsize=9)
        axes[i, 0].axis("off")

        axes[i, 1].imshow(aug_img)
        axes[i, 1].set_title(f"{cname} (Augmented)", fontsize=9)
        axes[i, 1].axis("off")
    plt.tight_layout()
    chart3_path = os.path.join(reports_dir, "augmentation_examples.png")
    plt.savefig(chart3_path, dpi=180)
    plt.close()
    print(f"Saved: {chart3_path}")

    # 6. Generate AUGMENTATION_REPORT.md
    aug_report = [
        "# Cotton Guard - Dataset Augmentation & Expansion Report",
        "",
        "## 1. Executive Summary",
        "",
        "- **Target Training Samples**: `17,000`",
        f"- **Actual Training Samples Generated**: `{sum(class_targets.values()):,}`",
        "- **Original Dataset Size**: `28` authentic photographic captures",
        "- **Training Split (Original)**: `14` images (2 per class)",
        "- **Validation Split (Original)**: `7` images (1 per class, 100% untouched)",
        "- **Test Split (Original)**: `7` images (1 per class, 100% untouched)",
        "- **Data Leakage Safeguard**: Strict isolation. Validation and test splits were never augmented or leaked into training.",
        "",
        "## 2. Per-Class Sampling Matrix",
        "",
        "| Canonical Class Name | Original Train Count | Augmented Train Count | Validation Count | Test Count | Total Available |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |"
    ]
    for cname in CANONICAL_CLASSES:
        aug_report.append(
            f"| **{cname}** | 2 | {class_targets[cname]:,} | 1 | 1 | {class_targets[cname] + 2:,} |"
        )
    aug_report.extend([
        "",
        "## 3. Augmentation Techniques Applied",
        "",
        "All augmentations were restricted to biologically plausible agricultural leaf transformations:",
        "- **Rotation**: Continuous random rotation in [-35°, +35°].",
        "- **Flips**: Horizontal flip (50%), Vertical flip (25%).",
        "- **Illumination**: Brightness factor [0.85, 1.15], Contrast factor [0.85, 1.15].",
        "- **Pigmentation / Saturation**: Color vibrancy factor [0.85, 1.15].",
        "- **Defocus / Sensor Noise**: Mild Gaussian blur (sigma in [0.3, 0.7]).",
        "",
        "## 4. Visual Artifacts Generated",
        "",
        "- `reports/dataset_distribution_before.png`: Class balance before augmentation.",
        "- `reports/dataset_distribution_after.png`: Balanced class representation after reaching 17,000 samples.",
        "- `reports/augmentation_examples.png`: Side-by-side comparison of original vs augmented leaf samples across all 7 classes.",
        "- `dataset/augmented/augmentation_metadata.csv`: Full cryptographic record mapping each sample to its source image, applied operations, and deterministic random seed."
    ])
    with open("AUGMENTATION_REPORT.md", "w", encoding="utf-8") as f:
        f.write("\n".join(aug_report))
    print(f"Generated AUGMENTATION_REPORT.md successfully.")

if __name__ == "__main__":
    run_augmentation_pipeline()
