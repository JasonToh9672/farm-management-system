class UserModel {
  String uid;
  String email;
  String name;
  String role; // 'owner' or 'worker'
  String farmId; // shared between owner and their workers
  DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.farmId,
    required this.createdAt,
  });

  bool get isOwner => role == UserRole.owner;
  bool get isWorker => role == UserRole.worker;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'farmId': farmId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'],
        email: map['email'],
        name: map['name'] ?? '',
        role: map['role'],
        farmId: map['farmId'],
        createdAt: DateTime.parse(map['createdAt']),
      );
}

class UserRole {
  static const String owner = 'owner';
  static const String worker = 'worker';
}
