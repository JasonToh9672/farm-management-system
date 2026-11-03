class BlockModel {
  String id;
  String name; // e.g. "Block A"
  String cropType; // Durian, Oil Palm, Cocoa, Rubber, Other — see CropType in constants.dart
  String location; // e.g. "North Field"
  DateTime plantingDate;
  String notes;

  BlockModel({
    required this.id,
    required this.name,
    required this.cropType,
    required this.location,
    required this.plantingDate,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'cropType': cropType,
        'location': location,
        'plantingDate': plantingDate.toIso8601String(),
        'notes': notes,
      };

  factory BlockModel.fromMap(Map<String, dynamic> map) => BlockModel(
        id: map['id'],
        name: map['name'],
        cropType: map['cropType'],
        location: map['location'] ?? '',
        plantingDate: DateTime.parse(map['plantingDate']),
        notes: map['notes'] ?? '',
      );

  BlockModel copyWith({
    String? name,
    String? cropType,
    String? location,
    DateTime? plantingDate,
    String? notes,
  }) =>
      BlockModel(
        id: id,
        name: name ?? this.name,
        cropType: cropType ?? this.cropType,
        location: location ?? this.location,
        plantingDate: plantingDate ?? this.plantingDate,
        notes: notes ?? this.notes,
      );
}
