import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

@immutable
class ServerCreateDraft {
  const ServerCreateDraft({
    required this.name,
    required this.shortName,
    required this.categoryId,
    required this.description,
    required this.isPrivate,
    this.avatarPath,
    this.avatarName,
  });

  final String name;
  final String shortName;
  final int categoryId;
  final String description;
  final bool isPrivate;
  final String? avatarPath;
  final String? avatarName;

  XFile? get avatarFile {
    if (avatarPath == null) return null;
    return XFile(avatarPath!, name: avatarName);
  }
}

@immutable
class JoinTarget {
  const JoinTarget({
    required this.serverId,
    required this.serverName,
    required this.serverShortName,
  });

  final String serverId;
  final String serverName;
  final String serverShortName;
}

/// Holds the in-flight Create Server draft (step 1) so the per-server identity
/// page (step 2 — YourProfilePage) can pick it up and submit the combined
/// multipart payload.
class ServerCreateController extends Notifier<ServerCreateDraft?> {
  @override
  ServerCreateDraft? build() => null;

  void setDraft(ServerCreateDraft draft) => state = draft;
  void clear() => state = null;
}

final serverCreateDraftProvider =
    NotifierProvider<ServerCreateController, ServerCreateDraft?>(ServerCreateController.new);

class JoinTargetController extends Notifier<JoinTarget?> {
  @override
  JoinTarget? build() => null;

  void setTarget(JoinTarget target) => state = target;
  void clear() => state = null;
}

final joinTargetProvider =
    NotifierProvider<JoinTargetController, JoinTarget?>(JoinTargetController.new);
