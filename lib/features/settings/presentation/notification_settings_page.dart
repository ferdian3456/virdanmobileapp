import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/http/dio_client.dart';
import '../../../core/notifications/notification_api.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';

/// Likes / Comments / Replies toggles are persisted to the backend
/// (users.settings JSONB). Mentions / followers / server activity stay local for
/// now — no backend toggle yet (mentions = Fase 2.5; followers/server not built).
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  bool _likes = true;
  bool _comments = true;
  bool _replies = true;
  bool _mentions = true;
  bool _follows = true;
  bool _serverActivity = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final response = await ref.read(apiDioProvider).get('/users/me');
      final settings = (response.data as Map<String, dynamic>)['settings'] as Map<String, dynamic>?;
      if (settings == null || !mounted) return;
      setState(() {
        _likes = settings['notif_like'] as bool? ?? true;
        _comments = settings['notif_comment'] as bool? ?? true;
        _replies = settings['notif_reply'] as bool? ?? true;
      });
    } catch (_) {
      // Keep defaults on failure.
    }
  }

  Future<void> _savePrefs({
    required bool prevLikes,
    required bool prevComments,
    required bool prevReplies,
  }) async {
    try {
      await ref.read(notificationApiProvider).updateNotificationPreferences(
            notifLike: _likes,
            notifComment: _comments,
            notifReply: _replies,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _likes = prevLikes;
        _comments = prevComments;
        _replies = prevReplies;
      });
      showApiErrorToast(ref, e);
    }
  }

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
            onChanged: (v) {
              final prev = (_likes, _comments, _replies);
              setState(() => _likes = v);
              _savePrefs(prevLikes: prev.$1, prevComments: prev.$2, prevReplies: prev.$3);
            },
            title: 'Likes',
          ),
          _Switch(
            value: _comments,
            onChanged: (v) {
              final prev = (_likes, _comments, _replies);
              setState(() => _comments = v);
              _savePrefs(prevLikes: prev.$1, prevComments: prev.$2, prevReplies: prev.$3);
            },
            title: 'Comments',
          ),
          _Switch(
            value: _replies,
            onChanged: (v) {
              final prev = (_likes, _comments, _replies);
              setState(() => _replies = v);
              _savePrefs(prevLikes: prev.$1, prevComments: prev.$2, prevReplies: prev.$3);
            },
            title: 'Replies',
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
              'Likes, Comments, and Replies are saved to your account. Mentions, followers, and server activity are stored locally for now.',
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
