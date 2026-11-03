class FruitCountModel {
  String id;
  String blockId;
  String treeId;
  String imageUrl; // Firebase Storage download URL for the captured photo
  int detectedCount; // raw count returned by the on-device YOLO model
  int count; // final count after the user reviews/adjusts the detection
  String notes;
  DateTime capturedAt;

  FruitCountModel({
    required this.id,
    required this.blockId,
    required this.treeId,
    required this.imageUrl,
    required this.detectedCount,
    required this.count,
    this.notes = '',
    required this.capturedAt,
  });

  // True when the farmer corrected the model's raw count — useful later for
  // gauging how reliable the model is in the field without any extra data.
  bool get wasAdjusted => count != detectedCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'blockId': blockId,
        'treeId': treeId,
        'imageUrl': imageUrl,
        'detectedCount': detectedCount,
        'count': count,
        'notes': notes,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory FruitCountModel.fromMap(Map<String, dynamic> map) => FruitCountModel(
        id: map['id'],
        blockId: map['blockId'],
        treeId: map['treeId'],
        imageUrl: map['imageUrl'] ?? '',
        detectedCount: map['detectedCount'] ?? 0,
        count: map['count'] ?? 0,
        notes: map['notes'] ?? '',
        capturedAt: DateTime.parse(map['capturedAt']),
      );
}
