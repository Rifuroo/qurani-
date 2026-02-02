class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final DateTime createdAt;
  final String? username;
  final String? image;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.createdAt,
    this.username,
    this.image,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      email: map['email'] ?? '',
      fullName: map['name'] ?? map['fullName'],
      username: map['username'],
      image: map['image'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'username': username,
      'image': image,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}



