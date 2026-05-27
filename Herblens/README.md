# 🌿 HerbLens — AI Herb Identifier

Flutter app for identifying herbs using an on-device TFLite model.

---

## Project Structure

```
herb_identifier/
├── android/
│   ├── app/
│   │   ├── build.gradle               # App-level Gradle config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml    # Permissions + providers
│   │       ├── kotlin/.../MainActivity.kt
│   │       └── res/
│   │           ├── drawable/launch_background.xml
│   │           ├── values/styles.xml
│   │           └── xml/file_paths.xml
│   ├── build.gradle                   # Project-level Gradle
│   ├── settings.gradle
│   └── gradle.properties
├── assets/
│   ├── herb_model.tflite              # ← Your converted model goes here
│   └── labels.txt                     # One label per line, matches model output
├── lib/
│   ├── main.dart
│   ├── models/herb_result.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── camera_screen.dart
│   │   └── result_screen.dart
│   └── services/
│       ├── classifier.dart            # TFLite inference engine
│       └── image_processor.dart
└── pubspec.yaml
```

---

## Step 1: Convert Your PyTorch Model to TFLite

### 1a. PyTorch → ONNX
```python
import torch

model = YourHerbModel()
model.load_state_dict(torch.load('model.pth', map_location='cpu'))
model.eval()

dummy = torch.randn(1, 3, 224, 224)  # adjust input size if needed

torch.onnx.export(
    model, dummy, 'herb_model.onnx',
    opset_version=11,
    input_names=['input'],
    output_names=['output'],
    dynamic_axes={'input': {0: 'batch'}, 'output': {0: 'batch'}}
)
```

### 1b. ONNX → TensorFlow SavedModel
```bash
pip install onnx onnx-tf tensorflow
onnx-tf convert -i herb_model.onnx -o herb_model_tf
```

### 1c. TF SavedModel → TFLite
```python
import tensorflow as tf

converter = tf.lite.TFLiteConverter.from_saved_model('herb_model_tf')
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # optional: quantize
tflite_model = converter.convert()

with open('herb_model.tflite', 'wb') as f:
    f.write(tflite_model)
print('Model converted! Size:', len(tflite_model) / 1024 / 1024, 'MB')
```

### 1d. Copy model to app
```bash
cp herb_model.tflite herb_identifier/assets/
```

---

## Step 2: Configure the Classifier

Open `lib/services/classifier.dart` and update these constants to match your model:

```dart
static const int inputSize = 224;       // e.g. 224, 299, 320
static const double mean = 127.5;       // 127.5 for [-1,1], 0 for [0,1]
static const double std = 127.5;        // 127.5 for [-1,1], 255 for [0,1]
```

Also update `assets/labels.txt` — one herb name per line, in the **exact order** of your model's output classes.

---

## Step 3: Run the App

```bash
flutter pub get
flutter run
```

### Requirements
- Flutter 3.10+
- Android minSdk 21 (Android 5.0+)
- Physical device recommended for camera

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `tflite_flutter` | Run .tflite model on device |
| `camera` | Live camera viewfinder |
| `image_picker` | Gallery photo selection |
| `image` | Resize + preprocess images |
| `permission_handler` | Camera/storage permissions |
| `flutter_animate` | Smooth animations |
| `percent_indicator` | Confidence circle chart |

---

## Demo Mode

If no `herb_model.tflite` is found in assets, the app enters **demo mode** and returns a mock Rosemary result. This lets you test the UI before the model is ready.

---

## Troubleshooting

**`aaptOptions` error** — make sure `build.gradle` has:
```gradle
aaptOptions { noCompress 'tflite' }
```

**Camera black screen on emulator** — use a physical Android device for camera testing.

**Model input shape mismatch** — check your model's expected input with:
```python
import onnx
model = onnx.load('herb_model.onnx')
print(model.graph.input)
```
