import 'package:flutter/foundation.dart';

import 'user_me.dart';

/// Top-level auth state. Use exhaustive switch at consumers:
///   switch (state) { case Authenticated(): ... case Anonymous(): ... }
sealed class AuthState {
  const AuthState();
}

class AuthAnonymous extends AuthState {
  const AuthAnonymous();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});
  final UserMe user;
}

@immutable
class SignupSession {
  const SignupSession({
    this.email,
    this.sessionId,
    this.otpVerified = false,
    this.otpExpiresAt,
  });

  factory SignupSession.empty() => const SignupSession();

  final String? email;
  final String? sessionId;
  final bool otpVerified;
  final int? otpExpiresAt;

  bool get hasSession => sessionId != null && sessionId!.isNotEmpty;

  SignupSession copyWith({
    String? email,
    String? sessionId,
    bool? otpVerified,
    int? otpExpiresAt,
  }) {
    return SignupSession(
      email: email ?? this.email,
      sessionId: sessionId ?? this.sessionId,
      otpVerified: otpVerified ?? this.otpVerified,
      otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
    );
  }
}
