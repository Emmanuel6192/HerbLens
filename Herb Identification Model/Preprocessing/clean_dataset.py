"""
Dataset Cleaner
---------------
Removes any class that has fewer than MIN_IMAGES images combined across
train, test, and val splits. Prints a summary of deleted classes.
"""

import os
import shutil
from collections import defaultdict

# ── Config ────────────────────────────────────────────────────────────────────

DATASET_DIR = r"C:\Users\King Taylor #8\Desktop\More and More Images\inaturalist_images"
MIN_IMAGES  = 15      # delete class if combined total is below this
DRY_RUN     = False   # set to False to actually delete

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tiff", ".webp"}
SPLITS = ["train", "test", "val"]

# ── Helpers ───────────────────────────────────────────────────────────────────

def count_images(folder):
    """Return the number of image files directly inside `folder`."""
    if not os.path.isdir(folder):
        return 0
    return sum(
        1 for f in os.listdir(folder)
        if os.path.splitext(f)[1].lower() in IMAGE_EXTENSIONS
    )


def gather_class_counts(dataset_dir):
    """
    Returns a dict:  class_name -> {split: image_count, ..., 'total': N}
    Only classes that exist in at least one split are included.
    """
    counts = defaultdict(lambda: defaultdict(int))

    for split in SPLITS:
        split_dir = os.path.join(dataset_dir, split)
        if not os.path.isdir(split_dir):
            print(f"  [warn] split folder not found, skipping: {split_dir}")
            continue
        for cls in os.listdir(split_dir):
            cls_path = os.path.join(split_dir, cls)
            if os.path.isdir(cls_path):
                n = count_images(cls_path)
                counts[cls][split] = n
                counts[cls]["total"] += n

    return counts


def delete_class(dataset_dir, class_name, dry_run):
    """Delete class folders across all splits. Returns list of removed paths."""
    removed = []
    for split in SPLITS:
        cls_path = os.path.join(dataset_dir, split, class_name)
        if os.path.isdir(cls_path):
            if not dry_run:
                shutil.rmtree(cls_path)
            removed.append(cls_path)
    return removed

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    dataset_dir = os.path.abspath(DATASET_DIR)

    if not os.path.isdir(dataset_dir):
        raise FileNotFoundError(f"Dataset directory not found: {dataset_dir}")

    print(f"\n{'='*60}")
    print(f"  Dataset : {dataset_dir}")
    print(f"  Min images required (combined): {MIN_IMAGES}")
    print(f"  Dry run : {DRY_RUN}")
    print(f"{'='*60}\n")

    counts = gather_class_counts(dataset_dir)

    if not counts:
        print("No classes found. Check your dataset structure.")
        return

    # ── Classify ──────────────────────────────────────────────────────────────
    to_delete = {cls: info for cls, info in counts.items() if info["total"] < MIN_IMAGES}
    to_keep   = {cls: info for cls, info in counts.items() if info["total"] >= MIN_IMAGES}

    print(f"Total classes found : {len(counts)}")
    print(f"Classes to KEEP     : {len(to_keep)}")
    print(f"Classes to DELETE   : {len(to_delete)}\n")

    # ── Delete ────────────────────────────────────────────────────────────────
    deleted_classes = []

    if to_delete:
        header = "DRY RUN — folders that WOULD be deleted:" if DRY_RUN else "Deleting under-represented classes..."
        print(header)
        print("-" * 50)

        for cls in sorted(to_delete):
            info   = to_delete[cls]
            detail = "  |  ".join(f"{s}: {info.get(s, 0)}" for s in SPLITS)
            total  = info["total"]
            removed = delete_class(dataset_dir, cls, DRY_RUN)

            prefix = "[DRY RUN] " if DRY_RUN else "DELETED   "
            print(f"  {prefix}{cls:<30}  total={total}   ({detail})")
            for path in removed:
                print(f"             └─ {path}")

            deleted_classes.append(cls)
    else:
        print("Nothing to delete — all classes meet the minimum image threshold.")

    # ── Summary ───────────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    if DRY_RUN:
        print("  DRY RUN complete — no files were removed.")
        print("  To actually delete, set DRY_RUN = False in the script.")
    else:
        print(f"  Done. {len(deleted_classes)} class(es) removed.")
    print(f"{'='*60}\n")

    if deleted_classes:
        print("Deleted classes list:")
        for i, cls in enumerate(sorted(deleted_classes), 1):
            print(f"  {i:>3}. {cls}")
        print()

    # Write the deleted list to a file (only on real runs)
    if deleted_classes and not DRY_RUN:
        log_path = os.path.join(dataset_dir, "deleted_classes.txt")
        with open(log_path, "w") as f:
            f.write(f"Classes removed (combined images < {MIN_IMAGES})\n")
            f.write("=" * 40 + "\n")
            for cls in sorted(deleted_classes):
                f.write(f"{cls}\n")
        print(f"  Log saved to: {log_path}\n")


if __name__ == "__main__":
    main()
