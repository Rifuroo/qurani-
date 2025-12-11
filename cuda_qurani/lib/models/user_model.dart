import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.createdAt,
  });
  factory UserModel.fromSupabaseUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'],
      createdAt: DateTime.parse(user.createdAt),
    );
  }
}



