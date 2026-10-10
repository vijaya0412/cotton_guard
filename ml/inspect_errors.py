"""Inspect detailed misclassifications by class."""
import json

with open("ml/production_model_evaluation.json") as f:
    data = json.load(f)

gallery = data["misclassified_gallery"]

# Group errors by true class
by_class = {}
for item in gallery:
    c = item["true_class"]
    by_class.setdefault(c, []).append(item)

print(f"Total Misclassified Test Images: {len(gallery)} / 322\n")
for c, items in sorted(by_class.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"=== True Class: {c} ({len(items)} errors) ===")
    pred_counts = {}
    for it in items:
        p = it["predicted_class"]
        pred_counts[p] = pred_counts.get(p, 0) + 1
    print("  Confused with:", pred_counts)
    print("  Sample errors:")
    for it in items[:4]:
        top3_summary = ", ".join([f"{t['class']}: {t['probability']*100:.1f}%" for t in it["top3"]])
        print(f"    {it['filename']:20s} -> Predicted: {it['predicted_class']:24s} (Conf: {it['confidence']*100:.1f}%) | Top3: {top3_summary}")
    print()
