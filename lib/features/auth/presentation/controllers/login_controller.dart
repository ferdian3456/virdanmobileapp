import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';

/// Thin login submit handler. Exposed as a Provider so widget can call without
/// owning state — actual loading/state lives on `authRepositoryProvider`.
class LoginController {
  LoginController(this._ref);
  final Ref _ref;

  Future<void> submit({required String email, required String password}) async {
    await _ref
        .read(authRepositoryProvider.notifier)
        .login(email: email.toLowerCase().trim(), password: password);
  }
}

final loginControllerProvider = Provider<LoginController>(LoginController.new);
