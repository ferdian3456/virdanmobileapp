import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/http/dio_client.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../server/data/server_repository.dart';
import '../data/server_feed_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _caption = TextEditingController();
  XFile? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 88, maxWidth: 1920);
      if (file == null || !mounted) return;
      setState(() => _image = file);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.primary),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.primary),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_image != null)
              ListTile(
                leading: const Icon(LucideIcons.x, color: AppColors.error),
                title: const Text('Remove image'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _image = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) {
      ref.read(toastControllerProvider.notifier).warning(title: 'Select a server first');
      return;
    }
    final caption = _caption.text.trim();
    if (caption.isEmpty && _image == null) {
      ref.read(toastControllerProvider.notifier).warning(
            title: 'Add a caption or image',
          );
      return;
    }
    setState(() => _submitting = true);
    try {
      final form = FormData.fromMap({
        'caption': caption,
        if (_image != null)
          'image': await MultipartFile.fromFile(_image!.path, filename: _image!.name),
      });
      await ref.read(apiDioProvider).post<Map<String, dynamic>>(
            '/servers/$serverId/posts',
            data: form,
            options: Options(contentType: 'multipart/form-data'),
          );
      if (!mounted) return;
      await ref.read(serverFeedProvider.notifier).refresh();
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Post created');
      context.go(Routes.appHome);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(
        title: 'New post',
        leading: VAppBarLeading.close,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Posting…' : 'Share',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _submitting ? AppColors.textTertiary : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  child: _image == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.image,
                                  size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 8),
                              Text(
                                'Tap to add an image',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_image!.path), fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              maxLines: 5,
              maxLength: 500,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Write a caption…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            VButton(
              label: _image == null ? 'Add image' : 'Replace image',
              variant: VButtonVariant.secondary,
              fullWidth: true,
              leading: const Icon(LucideIcons.image, size: 18),
              onPressed: _showSourceSheet,
            ),
          ],
        ),
      ),
    );
  }
}
