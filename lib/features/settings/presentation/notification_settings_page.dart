import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _likes = true;
  bool _comments = true;
  bool _mentions = true;
  bool _follows = true;
  bool _serverActivity = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Notifications', leading: VAppBarLeading.back),
      body: ListView(
        children: [
          const _Header('Push notifications'),
          _Switch(
            value: _likes,
            onChanged: (v) => setState(() => _likes = v),
            title: 'Likes',
          ),
          _Switch(
            value: _comments,
            onChanged: (v) => setState(() => _comments = v),
            title: 'Comments',
          ),
          _Switch(
            value: _mentions,
            onChanged: (v) => setState(() => _mentions = v),
            title: 'Mentions',
          ),
          _Switch(
            value: _follows,
            onChanged: (v) => setState(() => _follows = v),
            title: 'New followers',
          ),
          _Switch(
            value: _serverActivity,
            onChanged: (v) => setState(() => _serverActivity = v),
            title: 'Server activity',
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'These preferences are stored locally for now. Push delivery and backend persistence land with FCM/APNs integration.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.onChanged,
    required this.title,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
