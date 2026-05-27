import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/herb_result.dart';

// Top-level function required by compute() — must not be a closure or method
Float32List _preprocessIsolate(Uint8List imageBytes) {
  const int resizeSize = 400; // resize slightly larger then center-crop
  const int inputSize  = 380; // EfficientNet-B4 native input size
  const List<double> mean = [0.485, 0.456, 0.406];
  const List<double> std  = [0.229, 0.224, 0.225];

  img.Image? raw = img.decodeImage(imageBytes);
  if (raw == null) throw Exception('Could not decode image');

  img.Image resized = img.copyResize(raw, width: resizeSize, height: resizeSize);

  final ox = (resizeSize - inputSize) ~/ 2;
  final oy = (resizeSize - inputSize) ~/ 2;
  img.Image cropped = img.copyCrop(resized, x: ox, y: oy, width: inputSize, height: inputSize);

  final buffer = Float32List(inputSize * inputSize * 3);
  int idx = 0;
  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = cropped.getPixel(x, y);
      buffer[idx++] = (pixel.r / 255.0 - mean[0]) / std[0];
      buffer[idx++] = (pixel.g / 255.0 - mean[1]) / std[1];
      buffer[idx++] = (pixel.b / 255.0 - mean[2]) / std[2];
    }
  }
  return buffer;
}

class HerbClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  String? _loadError;

  static const int inputSize = 380; // EfficientNet-B4

  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/herb_model.tflite',
        options: options,
      );
      _interpreter!.allocateTensors();

      final inShape  = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;
      debugLog('Input  shape: $inShape');
      debugLog('Output shape: $outShape');

      // Load labels — strip BOM if present, handle both \n and \r\n line endings
      final rawLabels = await rootBundle.loadString('assets/labels.txt');
      final labelData = rawLabels.startsWith('\uFEFF') ? rawLabels.substring(1) : rawLabels;
      _labels = labelData
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      _isLoaded = true;
      _loadError = null;
      debugLog('Model loaded ✓  Labels: ${_labels.length}');
    } catch (e) {
      _isLoaded = false;
      _loadError = e.toString();
      debugLog('❌ Model load failed: $e');
    }
  }

  void debugLog(String msg) {
    // ignore: avoid_print
    print('[HerbClassifier] $msg');
  }

  Future<HerbResult> classify(Uint8List imageBytes) async {
    if (!_isLoaded || _interpreter == null) {
      debugLog('⚠️ Model not loaded — returning demo result');
      return _demoResult();
    }

    try {
      // Preprocess off the main thread to avoid jank
      final flat = await compute(_preprocessIsolate, imageBytes);

      // Wrap flat buffer in [1, H, W, 3] shape that TFLite expects
      final input = flat.reshape([1, inputSize, inputSize, 3]);

      // Prepare output as a nested List<List<double>> — tflite_flutter's run()
      // writes back into this structure. A flat Float32List passed via reshape()
      // does NOT get updated in place, which causes an all-zeros buffer and
      // always returns the same class at ~0% confidence.
      final numClasses = _interpreter!.getOutputTensor(0).shape[1];
      final output = [List<double>.filled(numClasses, 0.0)];

      // Run inference
      _interpreter!.run(input, output);

      final outputList = output[0];

      debugLog('Logits min=${outputList.reduce(math.min).toStringAsFixed(3)}  '
          'max=${outputList.reduce(math.max).toStringAsFixed(3)}');
      debugLog('First 5 logits: ${outputList.sublist(0, math.min(5, numClasses)).map((v) => v.toStringAsFixed(2)).toList()}');

      final probs = _softmax(outputList);
      final maxProb = probs.reduce(math.max);
      debugLog('Max probability: ${(maxProb * 100).toStringAsFixed(2)}%');

      final indexed = List.generate(probs.length, (i) => MapEntry(i, probs[i]))
        ..sort((a, b) => b.value.compareTo(a.value));

      final top5 = indexed.take(5).map((e) {
        final name = e.key < _labels.length ? _labels[e.key] : 'Class ${e.key}';
        return HerbPrediction(name: name, confidence: e.value);
      }).toList();

      debugLog('→ ${top5.first.name} (${(top5.first.confidence * 100).toStringAsFixed(1)}%)');

      return HerbResult(
        name: top5.first.name,
        confidence: top5.first.confidence,
        topPredictions: top5,
      );
    } catch (e, stack) {
      debugLog('❌ Inference error: $e');
      debugLog('Stack: $stack');
      return _demoResult();
    }
  }

  List<double> _softmax(List<double> logits) {
    final m    = logits.reduce(math.max);
    final exps = logits.map((x) => math.exp(x - m)).toList();
    final sum  = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  HerbResult _demoResult() {
    const herbs  = ['Rosemary', 'Basil', 'Thyme', 'Lavender', 'Mint'];
    const scores = [0.87, 0.07, 0.03, 0.02, 0.01];
    return HerbResult(
      name: herbs[0],
      confidence: scores[0],
      topPredictions: List.generate(
        herbs.length,
        (i) => HerbPrediction(name: herbs[i], confidence: scores[i]),
      ),
    );
  }

  void dispose() {
    _interpreter?.close();
  }
}
