class TreeModel {
  String id;
  String treeCode; // e.g. "D111"
  String notes;
  DateTime createdAt;

  TreeModel({
    required this.id,
    required this.treeCode,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'treeCode': treeCode,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TreeModel.fromMap(Map<String, dynamic> map) => TreeModel(
        id: map['id'],
        treeCode: map['treeCode'],
        notes: map['notes'] ?? '',
        createdAt: DateTime.parse(map['createdAt']),
      );

  TreeModel copyWith({
    String? treeCode,
    String? notes,
  }) =>
      TreeModel(
        id: id,
        treeCode: treeCode ?? this.treeCode,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
