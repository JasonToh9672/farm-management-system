# Fruit Counting Model: Training Guide

This document describes how the durian fruit-counting model was trained and how to retrain or replace it. Training happens **outside** the Flutter app, in Python (Google Colab). The app only uses the final exported model file at `assets/models/fruit_detector.tflite`.

## Pipeline overview

```
Roboflow dataset → Google Colab (Ultralytics YOLOv8, GPU) → best.pt
    → export to TensorFlow Lite → assets/models/fruit_detector.tflite
```

## 1. Dataset

The final model was trained on the **"Durian Project"** dataset from Roboflow Universe (`durian-project-rfru6/durian-lq8ha`, about 1.4k images, 1 class). Its images show durians hanging on real trees, in natural, cluttered scenes, with **many labelled fruit per image**. This matches how the app is used: one photo of a tree, with several fruit to count.

### Why the first dataset failed

The first dataset tried (808 images, 8 classes) gave a near-perfect validation score (mAP50 = 0.995), but in the app it detected **only one fruit per photo**, regardless of the real count.

Looking through the dataset's images showed the cause: every image contained a **single durian on a plain background**. It was effectively a classification dataset labelled as if it were for detection. The model learned to find one durian-shaped region per image, not to count fruit in a real scene. The validation score was high because the validation images had the same narrow style as the training images.

**Lesson:** always look at a sample of the raw dataset images before training, and test the model on real photos. A high validation score only means the model fits data that looks like its validation set.

### Getting a dataset from Roboflow

1. Search Roboflow Universe for the crop, e.g. `https://universe.roboflow.com/search?q=class:durian`
2. Open the dataset → **Download Dataset** → format **YOLOv8**. This gives a `data.yaml` file and folders of images and labels.
3. Check the dataset's licence. Many are CC BY 4.0, which requires attribution.

## 2. Training (Google Colab)

In a new Colab notebook, set **Runtime → Change runtime type → GPU**.

```python
!pip install ultralytics

from ultralytics import YOLO

# First download the Roboflow export into Colab
# (Roboflow shows a code snippet for this on its download screen).

model = YOLO("yolov8n.pt")   # nano: the smallest and fastest size, suited to phones
results = model.train(
    data="data.yaml",        # from the Roboflow export
    epochs=100,
    imgsz=640,
    batch=16,
)
```

Notes:
- **YOLOv8n (nano)** was chosen because it runs fast on a phone. Larger sizes (`s`, `m`, `l`) are slower and heavier, with little benefit for a single-class problem.
- Ultralytics saves the best checkpoint automatically at `runs/detect/train/weights/best.pt`. If `mAP50` is still improving at the last epoch, train for longer.
- For small datasets, augmentation (rotation, brightness, blur) matters more than the number of epochs.

**Final model results (validation set: 151 images, 921 fruit):** mAP50 = 0.960, mAP50-95 = 0.713, about 4.2 ms inference time per image.

## 3. Export to TensorFlow Lite

```python
model = YOLO("runs/detect/train/weights/best.pt")
model.export(format="tflite", imgsz=320, int8=True)
```

- **`imgsz=320`:** a smaller input size than training (640) roughly halves inference time on the phone, with a small accuracy trade-off. The app analyses single photos, not live video, so this trade-off is acceptable.
- **`int8=True`:** quantisation makes the model about 4x smaller and faster. The final file is about 3.3 MB.
- **Non-max suppression (NMS)** is not built into the exported model. The `ultralytics_yolo` Flutter plugin runs NMS on the device.
- Ultralytics updates its export options from time to time, so check the [export documentation](https://docs.ultralytics.com/modes/export/) if a command stops working.

Rename the exported `.tflite` file to `fruit_detector.tflite`.

**Known trade-off:** with int8 quantisation, most detection confidence scores cluster around 50%. The fruit **count** is still correct, so this doesn't affect the feature, but exporting with float16 instead of int8 may give more spread-out scores, at the cost of a larger file.

## 4. Adding the model to the app

1. Put the file at `assets/models/fruit_detector.tflite`.
2. Make sure it's listed in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/fruit_detector.tflite
   ```
3. Run `flutter pub get`.

The detection code is in `lib/services/fruit_detection_service.dart`. If the model file is missing or fails to load, the app doesn't crash: it falls back to manual count entry.

### Detection settings for clustered fruit

Durians grow in tight, overlapping clusters, so the plugin's general-purpose defaults were changed in `FruitDetectionService.detectFruits()`:
- **`confidenceThreshold = 0.15`** (lower than usual), so partly hidden fruit isn't filtered out for having a lower score than a fully visible one
- **`iouThreshold = 0.6`** (higher than usual), so two separate but overlapping fruit aren't merged into one detection by NMS

## 5. Testing

The `ultralytics_yolo` plugin works on **Android and iOS only**, not on the web/Chrome target. Test detection on an Android emulator or a physical device.

**Emulator caching issue:** after replacing the `.tflite` file, the Android emulator may keep using the old model. A hot reload or restart isn't enough. Uninstall the app from the emulator and reinstall it.

## Extending to other crops

To support oil palm or cocoa, repeat the same steps with a dataset for that crop. Check the dataset images first, as described in section 1.
