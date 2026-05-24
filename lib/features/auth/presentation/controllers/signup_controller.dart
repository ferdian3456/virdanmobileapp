import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_api.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

/// Drives the multi-step signup flow. Holds the cross-page state (email,
/// sessionId, otpVerified) so users can hit back without losing progress.
class SignupController extends Notifier<SignupSession> {
  @override
  SignupSession build() => SignupSession.empty();

  AuthApi get _api => ref.read(authApiProvider);

  /// Step 1 — sends OTP to [email]. Sets sessionId on success.
  Future<void> start(String email) async {
    final result = await _api.startSignup(email.toLowerCase().trim());
    state = state.copyWith(
      email: email.toLowerCase().trim(),
      sessionId: result.sessionId,
      otpExpiresAt: result.otpExpiresAt,
      otpVerified: false,
    );
  }

  /// Step 2 — verifies the OTP. Marks the session as otpVerified.
  Future<void> verifyOtp(String otp) async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    await _api.verifyOtp(sessionId: id, otp: otp);
    state = state.copyWith(otpVerified: true);
  }

  /// Resends a fresh OTP for the active session.
  Future<void> resendOtp() async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    await _api.resendOtp(id);
  }

  /// Step 3 — sets password, completes signup. Tokens get applied to the
  /// global auth state so the router can transition the user into the app.
  Future<void> setPassword(String password) async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    if (!state.otpVerified) throw StateError('OTP must be verified first');
    final tokens = await _api.setPassword(sessionId: id, password: password);
    await ref.read(authRepositoryProvider.notifier).applyTokensAndFetchUser(tokens);
    state = SignupSession.empty();
  }

  void reset() => state = SignupSession.empty();
}

final signupControllerProvider = NotifierProvider<SignupController, SignupSession>(
  SignupController.new,
);
