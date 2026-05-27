import os
import shutil
import random

# ── Configuration ─────────────────────────────────────────────────────────────

RAW_DIR    = "G:\inaturalist_images"   # folder containing one subfolder per herb species
OUTPUT_DIR = r"G:\New Training Data"        # where train/ val/ test/ will be created

TRAIN_RATIO = 0.80
VAL_RATIO   = 0.10
TEST_RATIO  = 0.10

RANDOM_SEED = 42             # keeps the split identical every time you run it

# ── Setup ─────────────────────────────────────────────────────────────────────

random.seed(RANDOM_SEED)

splits = ["train", "val", "test"]

# Get every species (one subfolder = one class)
classes = [
    d for d in os.listdir(RAW_DIR)
    if os.path.isdir(os.path.join(RAW_DIR, d))
]

if not classes:
    raise ValueError(f"No subfolders found in '{RAW_DIR}'. Check your RAW_DIR path.")

print(f"Found {len(classes)} classes: {classes}\n")

# ── Create output folder structure ────────────────────────────────────────────

for split in splits:
    for cls in classes:
        os.makedirs(os.path.join(OUTPUT_DIR, split, cls), exist_ok=True)

# ── Split and copy images ─────────────────────────────────────────────────────

VALID_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")

summary = []

for cls in classes:
    src_folder = os.path.join(RAW_DIR, cls)

    # Collect valid image files only
    images = [
        f for f in os.listdir(src_folder)
        if f.lower().endswith(VALID_EXTENSIONS)
    ]

    if not images:
        print(f"  WARNING: No images found in '{src_folder}', skipping.")
        continue

    random.shuffle(images)

    total      = len(images)
    train_end  = int(total * TRAIN_RATIO)
    val_end    = train_end + int(total * VAL_RATIO)

    splits_map = {
        "train": images[:train_end],
        "val":   images[train_end:val_end],
        "test":  images[val_end:],
    }

    for split, files in splits_map.items():
        for fname in files:
            src  = os.path.join(src_folder, fname)
            dest = os.path.join(OUTPUT_DIR, split, cls, fname)
            shutil.copy2(src, dest)

    summary.append({
        "class": cls,
        "total": total,
        "train": len(splits_map["train"]),
        "val":   len(splits_map["val"]),
        "test":  len(splits_map["test"]),
    })

# ── Print summary ─────────────────────────────────────────────────────────────

print(f"{'Class':<20} {'Total':>6} {'Train':>6} {'Val':>6} {'Test':>6}")
print("-" * 48)
for row in summary:
    print(
        f"{row['class']:<20} {row['total']:>6} "
        f"{row['train']:>6} {row['val']:>6} {row['test']:>6}"
    )

total_images = sum(r["total"] for r in summary)
print("-" * 48)
print(f"{'TOTAL':<20} {total_images:>6}")
print(f"\nDone! Dataset saved to '{OUTPUT_DIR}/'")
