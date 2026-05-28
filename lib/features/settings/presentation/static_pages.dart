import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LongDoc(
      title: 'Terms of service',
      content:
          'Last updated: this is placeholder copy. The final terms will be published before public launch.\n\n'
          'By using Virdan you agree to community guidelines, acceptable-use rules, and the privacy practices described in our Privacy Policy. Virdan is provided "as is"; we are still in active development and may change features without notice.\n\n'
          '1. Account eligibility. You must be at least 13 years old.\n\n'
          '2. Content ownership. You retain ownership of content you post.\n\n'
          '3. Prohibited use. No spam, abuse, illegal content, or attempts to circumvent moderation.\n\n'
          '4. Termination. We may suspend accounts that violate these terms.\n\n'
          '5. Governing law. These terms are governed by applicable consumer protection laws in your country of residence.\n\n'
          'For the canonical version of the terms please visit our website once launch is announced.',
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LongDoc(
      title: 'Privacy policy',
      content:
          'Last updated: placeholder. The published policy will appear before public launch.\n\n'
          'We collect the minimum data needed to operate Virdan: email for authentication, your per-server identities (nickname, bio, avatar), and content you post. We use industry-standard encryption in transit and at rest.\n\n'
          'You can request export or deletion of your data at any time via Settings → Privacy & security.\n\n'
          'We do not sell personal data. Analytics is aggregated and anonymised.',
    );
  }
}

class _LongDoc extends StatelessWidget {
  const _LongDoc({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(title: title, leading: VAppBarLeading.back),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            content,
            style: AppTextStyles.body.copyWith(height: 1.6, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
