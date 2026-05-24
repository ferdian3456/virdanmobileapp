import 'package:flutter/foundation.dart';

@immutable
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.accessTokenExpiresIn,
    required this.refreshToken,
    required this.refreshTokenExpiresIn,
    required this.tokenType,
  });

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    return SessionTokens(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresIn: (json['accessTokenExpiresIn'] as num).toInt(),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresIn: (json['refreshTokenExpiresIn'] as num).toInt(),
      tokenType: (json['tokenType'] as String?) ?? 'Bearer',
    );
  }

  final String accessToken;
  final int accessTokenExpiresIn;
  final String refreshToken;
  final int refreshTokenExpiresIn;
  final String tokenType;
}
