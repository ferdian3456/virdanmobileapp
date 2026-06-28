import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../data/auth_api.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

/// Server-side step values used by `GET /auth/signup/:sessionId/status`.
abstract final class SignupStep {
  static const startSignup = 'start_signup';
  static const otpVerified = 'otp_verified';
  static const passwordSet = 'password_set';
}

/// Drives the multi-step signup flow. Persists sessionId + otpExpiresAt to
/// secure storage so users can resume after closing the app.
class SignupController extends Notifier<SignupSession> {
  @override
  SignupSession build() {
    // Lazy boot from storage so resume works on cold start.
    _hydrate();
    return SignupSession.empty();
  }

  AuthApi get _api => ref.read(authApiProvider);
  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _hydrate() async {
    final id = await _storage.readSignupSessionId();
    if (id == null || id.isEmpty) return;
    final expires = await _storage.readOtpExpiresAt();
    state = state.copyWith(sessionId: id, otpExpiresAt: expires);
  }

  /// Step 1 — sends OTP to [email]. Sets sessionId on success.
  Future<void> start(String email) async {
    final normalized = email.toLowerCase().trim();
    await _storage.deleteSignupSessionId();
    await _storage.deleteOtpExpiresAt();
    state = SignupSession.empty();
    final result = await _api.startSignup(normalized);
    await _storage.writeSignupSessionId(result.sessionId);
    await _storage.writeOtpExpiresAt(result.otpExpiresAt);
    state = SignupSession(
      email: normalized,
      sessionId: result.sessionId,
      otpExpiresAt: result.otpExpiresAt,
    );
  }

  /// Step 2 — verifies the OTP. Marks the session as otpVerified.
  Future<void> verifyOtp(String otp) async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    await _api.verifyOtp(sessionId: id, otp: otp);
    await _storage.deleteOtpExpiresAt();
    state = state.copyWith(otpVerified: true, otpExpiresAt: null);
  }

  /// Resends a fresh OTP for the active session. Returns the new expiry.
  Future<int> resendOtp() async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    final result = await _api.resendOtp(id);
    if (result.otpExpiresAt > 0) {
      await _storage.writeOtpExpiresAt(result.otpExpiresAt);
      state = state.copyWith(otpExpiresAt: result.otpExpiresAt);
    }
    return result.otpExpiresAt;
  }

  /// Step 3 — sets password, completes signup. Tokens get applied to the
  /// global auth state so the router can transition the user into the app.
  Future<void> setPassword(String password) async {
    final id = state.sessionId;
    if (id == null) throw StateError('Signup session not started');
    if (!state.otpVerified) throw StateError('OTP must be verified first');
    final tokens = await _api.setPassword(sessionId: id, password: password);
    await ref.read(authRepositoryProvider.notifier).applyTokensAndFetchUser(tokens);
    await _storage.deleteSignupSessionId();
    await _storage.deleteOtpExpiresAt();
    state = SignupSession.empty();
  }

  /// Looks up the persisted sessionId (if any) and asks the server for its
  /// current step. Used by LoginPage's resume modal.
  ///
  /// Returns null when there is no resumable session.
  Future<String?> probePendingStep() async {
    final id = await _storage.readSignupSessionId();
    if (id == null || id.isEmpty) return null;
    try {
      final step = await _api.getSignupStatus(id);
      if (step.isEmpty || step == SignupStep.passwordSet) {
        await _storage.deleteSignupSessionId();
        await _storage.deleteOtpExpiresAt();
        state = SignupSession.empty();
        return null;
      }
      final expires = await _storage.readOtpExpiresAt();
      state = state.copyWith(
        sessionId: id,
        otpExpiresAt: expires,
        otpVerified: step == SignupStep.otpVerified,
      );
      return step;
    } catch (_) {
      await _storage.deleteSignupSessionId();
      await _storage.deleteOtpExpiresAt();
      state = SignupSession.empty();
      return null;
    }
  }

  Future<void> reset() async {
    await _storage.deleteSignupSessionId();
    await _storage.deleteOtpExpiresAt();
    state = SignupSession.empty();
  }
}

final signupControllerProvider = NotifierProvider<SignupController, SignupSession>(
  SignupController.new,
);
