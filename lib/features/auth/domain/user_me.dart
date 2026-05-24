import 'package:flutter/foundation.dart';

@immutable
class UserMe {
  const UserMe({required this.id, required this.email, this.settings = const {}});

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id'] as String,
      email: json['email'] as String,
      settings: (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String id;
  final String email;
  final Map<String, dynamic> settings;
}
