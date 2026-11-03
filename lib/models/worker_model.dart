class WorkerModel {
  String id; // worker's Firebase Auth UID
  String name;
  String email;
  String phone;
  DateTime joinedAt;

  WorkerModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory WorkerModel.fromMap(Map<String, dynamic> map) => WorkerModel(
        id: map['id'],
        name: map['name'],
        email: map['email'],
        phone: map['phone'] ?? '',
        joinedAt: DateTime.parse(map['joinedAt']),
      );
}
