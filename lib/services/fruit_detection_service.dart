import 'dart:io';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

// Wraps the on-device YOLO model used for fruit counting.
//
// IMPORTANT — this needs a trained model before it will actually detect
// anything. Train one following ML_TRAINING_GUIDE.md, then drop the
// exported .tflite file at:
//   assets/models/fruit_detector.tflite
// and add it to pubspec.yaml under flutter/assets.
//
// Until that file exists, `modelAvailable` is false and the UI should fall
// back to manual count entry — the app won't crash, it just can't detect.
class DetectedFruit {
  final String label;
  final double confidence;

  const DetectedFruit({required this.label, required this.confidence});
}

class FruitDetectionResult {
  final List<DetectedFruit> detections;
  int get count => detections.length;

  const FruitDetectionResult(this.detections);
}

class FruitDetectionService {
  static const String modelAssetPath = 'assets/models/fruit_detector.tflite';

  static YOLO? _yolo;
  static bool _loadAttempted = false;
  static bool modelAvailable = false;

  // Attempts to load the bundled model exactly once per app session.
  // Safe to call repeatedly — later calls just return the cached result.
  static Future<bool> ensureModelLoaded() async {
    if (_loadAttempted) return modelAvailable;
    _loadAttempted = true;
    try {
      final yolo = YOLO(modelPath: modelAssetPath, task: YOLOTask.detect);
      await yolo.loadModel();
      _yolo = yolo;
      modelAvailable = true;
    } catch (_) {
      // Most likely cause: the .tflite asset hasn't been added yet, or this
      // is running on the Chrome/web debug target, which this plugin does
      // not support (Android/iOS only). Either way, fail soft.
      _yolo = null;
      modelAvailable = false;
    }
    return modelAvailable;
  }

  // Runs detection on a captured/picked photo. Returns null if no model is
  // loaded — callers should treat that as "fall back to manual count".
  //
  // Defaults are tuned for tightly-clustered fruit (like durian bunches)
  // rather than the plugin's general-purpose defaults:
  //   - confidenceThreshold lower (0.15) so partially-occluded fruit in a
  //     cluster isn't filtered out for being less certain than an isolated,
  //     well-lit fruit would be.
  //   - iouThreshold higher (0.6) so two genuinely separate but visually
  //     overlapping fruit aren't merged into a single detection by NMS.
  // Adjust these per-call if testing shows a different balance works better
  // for your dataset.
  static Future<FruitDetectionResult?> detectFruits(
    File imageFile, {
    double confidenceThreshold = 0.15,
    double iouThreshold = 0.6,
  }) async {
    final ready = await ensureModelLoaded();
    if (!ready || _yolo == null) return null;

    final bytes = await imageFile.readAsBytes();
    // predict() returns the raw channel payload as Map<String, dynamic>;
    // YOLODetectionResults.fromMap() parses it into the typed detections
    // list (each with className/confidence/boundingBox etc).
    final rawResult = await _yolo!.predict(
      bytes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );
    final parsed = YOLODetectionResults.fromMap(rawResult);

    final detections = parsed.detections
        .map((r) => DetectedFruit(label: r.className, confidence: r.confidence))
        .toList();
    return FruitDetectionResult(detections);
  }
}
