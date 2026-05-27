

import torch
import torch.nn as nn
from torchvision.models import efficientnet_b4, EfficientNet_B4_Weights
from torchvision import transforms
from PIL import Image
import numpy as np
import os

PTH_PATH    = r"C:\Users\King Taylor #8\Desktop\Herb Identification Model\best_herb_model_5.pth"
ONNX_PATH   = "herb_model.onnx"
TFLITE_PATH = "herb_model.tflite"
NUM_CLASSES = 501

# ── Step 1: Rebuild exact model architecture ──────────────────────────────────
print("[1/5] Building model architecture...")
weights = EfficientNet_B4_Weights.IMAGENET1K_V1
model = efficientnet_b4(weights=None)  # no pretrained weights, we load our own

in_features = model.classifier[1].in_features  
model.classifier = nn.Sequential(
    nn.Dropout(p=0.2),
    nn.Linear(in_features, 512),
    nn.ReLU(),
    nn.Dropout(p=0.3),
    nn.Linear(512, NUM_CLASSES),
)

# ── Step 2: Load your trained weights ────────────────────────────────────────
print(f"[2/5] Loading weights from {PTH_PATH}...")
state_dict = torch.load(PTH_PATH, map_location="cpu")
model.load_state_dict(state_dict)
model.eval()
print("      Weights loaded successfully!")

# ── Step 3: Quick sanity check before conversion ─────────────────────────────
print("[3/5] Sanity check — running dummy inference...")
dummy = torch.randn(1, 3, 380, 380)
with torch.no_grad():
    out = model(dummy)
import torch.nn.functional as F
probs = F.softmax(out, dim=1)
top5 = torch.topk(probs, 5)
print(f"      Top prob: {top5.values[0][0].item()*100:.2f}%  (should be >> 0.5% for a good model)")
print(f"      If top prob is ~0.5%, your .pth file may be corrupted or wrong architecture")

# ── Step 4: Export to ONNX ────────────────────────────────────────────────────
print(f"[4/5] Exporting to ONNX...")
torch.onnx.export(
    model,
    dummy,
    ONNX_PATH,
    opset_version=13,
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
)
print(f"      Saved → {ONNX_PATH}")

# ── Step 5: ONNX → TFLite via onnx2tf ────────────────────────────────────────
print(f"[5/5] Converting ONNX → TFLite...")
print("      This may take a few minutes...")
try:
    import onnx2tf
    onnx2tf.convert(
        input_onnx_file_path=ONNX_PATH,
        output_folder_path="herb_model_tf",
        output_signaturedefs=True,
        non_verbose=True,
    )

    # Convert SavedModel → TFLite
    import tensorflow as tf
    converter = tf.lite.TFLiteConverter.from_saved_model("herb_model_tf")
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(TFLITE_PATH, "wb") as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / 1024 / 1024
    print(f"      Saved → {TFLITE_PATH}  ({size_mb:.1f} MB)")

except ImportError:
    print("      onnx2tf not found. Installing...")
    os.system("pip install onnx2tf")
    print("      Re-run this script after install completes.")

print("\n" + "="*50)
print("  Copy herb_model.tflite → herb_identifier/assets/")
print("="*50)
