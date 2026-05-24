import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';

/// Note: BE only exposes per-server profile fields now (multi-identity Opsi B).
/// Global profile fields (fullname/bio/avatar) are removed. This page is kept
/// as a hub for "tweak per-server identities" and routes users to the relevant
/// server's profile editor.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _displayName = TextEditingController(text: '');

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Edit profile', leading: VAppBarLeading.close),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              VInput(
                controller: _displayName,
                label: 'Display name (per server)',
                helper: 'To edit a per-server identity, open the server and tap your avatar.',
                maxLength: 50,
              ),
              const SizedBox(height: 24),
              VButton(
                label: 'Save',
                fullWidth: true,
                size: VButtonSize.lg,
                onPressed: () {
                  ref.read(toastControllerProvider.notifier).info(
                        title: 'Per-server identity editor lands next iteration',
                      );
                  context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
