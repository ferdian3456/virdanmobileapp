import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/http/dio_client.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../server/data/server_repository.dart';
import '../data/server_feed_provider.dart';

/// Mirrors Quasar CreatePostPage.vue — IG-style 3-step composer:
/// source (gallery/photo/video) → crop (aspect + zoom + pan) → detail
/// (cropped thumb + caption + meta/toggle rows + server info + Post).
enum CpStep { source, crop, detail }
enum SourceTab { gallery, photo, video }

class _Aspect {
  const _Aspect(this.id, this.label, this.ratio);
  final String id;
  final String label;
  final double? ratio; // width / height; null = free
}

const _aspects = <_Aspect>[
  _Aspect('free', 'Free', null),
  _Aspect('1:1', '1:1', 1),
  _Aspect('4:5', '4:5', 4 / 5),
  _Aspect('9:16', '9:16', 9 / 16),
  _Aspect('16:9', '16:9', 16 / 9),
];

const double _zoomMin = 1.0;
const double _zoomMax = 3.0;

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage>
    with WidgetsBindingObserver {
  CpStep _step = CpStep.source;
  SourceTab _tab = SourceTab.gallery;

  Uint8List? _sourceBytes;
  img.Image? _decoded;

  String _aspectId = '1:1';
  double _zoom = 1.0;
  Offset _translate = Offset.zero;
  double _stageW = 0;
  double _frameW = 0;
  double _frameH = 0;

  Uint8List? _croppedBytes;
  final _captionCtrl = TextEditingController();

  AssetEntity? _selectedAsset;

  bool _isProcessing = false;
  bool _isUploading = false;

  // Camera
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _camInitializing = false;
  String? _camError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      _stopCamera();
    } else if (s == AppLifecycleState.resumed &&
        _tab == SourceTab.photo &&
        _step == CpStep.source) {
      _startCamera();
    }
  }

  /* ─── Camera ─── */

  Future<void> _startCamera() async {
    if (_camInitializing) return;

    // Detach + dispose the previous controller BEFORE creating a new one so
    // CameraPreview never gets rebuilt against a disposed instance.
    final old = _camCtrl;
    if (mounted) {
      setState(() {
        _camCtrl = null;
        _camInitializing = true;
        _camError = null;
      });
    } else {
      _camCtrl = null;
      _camInitializing = true;
      _camError = null;
    }
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _camError = 'No camera available on this device.');
        }
        return;
      }
      final desc = _cameras[_camIndex % _cameras.length];
      final ctrl = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _camCtrl = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _camError = 'Could not start camera.');
    } finally {
      if (mounted) setState(() => _camInitializing = false);
    }
  }

  Future<void> _stopCamera() async {
    final c = _camCtrl;
    if (mounted) {
      setState(() => _camCtrl = null);
    } else {
      _camCtrl = null;
    }
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _camInitializing) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> _captureFrame() async {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      final shot = await ctrl.takePicture();
      final bytes = await shot.readAsBytes();
      // Stop camera AFTER reading bytes so the controller stays alive for
      // the takePicture / readAsBytes await chain.
      await _stopCamera();
      if (!mounted) return;
      _loadBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  /* ─── Source picking ─── */

  Future<void> _loadFromSelectedAsset() async {
    final asset = _selectedAsset;
    if (asset == null) return;
    try {
      final bytes = await asset.originBytes;
      if (bytes == null || !mounted) return;
      _loadBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  void _loadBytes(Uint8List bytes) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      ref
          .read(toastControllerProvider.notifier)
          .error(title: 'Could not read image.');
      return;
    }
    // Apply EXIF rotation so width/height match what users see — camera
    // captures often carry an orientation tag that Image.memory honors but
    // img.decodeImage doesn't until we bake it in.
    decoded = img.bakeOrientation(decoded);
    final rebaked = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
    setState(() {
      _sourceBytes = rebaked;
      _decoded = decoded;
      _step = CpStep.crop;
      _aspectId = '1:1';
      _zoom = 1.0;
      _translate = Offset.zero;
      _stageW = 0;
    });
  }

  void _onSourceTabChanged(SourceTab next) {
    final prev = _tab;
    if (prev == next) return;
    setState(() => _tab = next);
    if (prev == SourceTab.photo) _stopCamera();
    if (next == SourceTab.photo && _step == CpStep.source) {
      _startCamera();
    }
  }

  /* ─── Step 2 layout math ─── */

  double? _aspectRatio() {
    final a = _aspects.firstWhere((x) => x.id == _aspectId);
    return a.ratio;
  }

  void _recalcStage(double parentWidth) {
    final ratio = _aspectRatio();
    final fw = parentWidth;
    final fh = ratio == null ? parentWidth : (parentWidth / ratio);
    if (_stageW == fw && _frameW == fw && _frameH == fh) return;
    _stageW = fw;
    _frameW = fw;
    _frameH = fh;
    _translate = Offset.zero;
  }

  Offset _clampTranslate(Offset t) {
    // Cover-fit-zoomed image overflows by (zoom-1) in BOTH axes around the
    // frame center. Allow translation up to half that overflow per side.
    final overflowX = _frameW * (_zoom - 1);
    final overflowY = _frameH * (_zoom - 1);
    final half = Offset(overflowX / 2, overflowY / 2);
    return Offset(
      t.dx.clamp(-half.dx, half.dx),
      t.dy.clamp(-half.dy, half.dy),
    );
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _translate = _clampTranslate(_translate + d.delta));
  }

  void _onZoomChanged(double v) {
    setState(() {
      _zoom = v;
      _translate = _clampTranslate(_translate);
    });
  }

  void _changeAspect(String id) {
    setState(() {
      _aspectId = id;
      _zoom = 1.0;
      _stageW = 0; // force recalc on next layout
    });
  }

  /* ─── Crop commit ─── */

  Future<void> _commitCrop() async {
    final dec = _decoded;
    if (dec == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      // BoxFit.cover-fits the source image into the frame, then we apply
      // scale + translate. Compute the source-pixel rect that corresponds
      // to the visible frame.
      final imgRatio = dec.width / dec.height;
      final frameRatio = _frameW / _frameH;
      // baseScale = how many display px per source px at zoom=1 (cover fit).
      final double baseScale;
      if (imgRatio > frameRatio) {
        // wider image — fits to frame height.
        baseScale = _frameH / dec.height;
      } else {
        baseScale = _frameW / dec.width;
      }
      final effectiveScale = baseScale * _zoom;
      // Source rect width/height in source pixels.
      final sw = _frameW / effectiveScale;
      final sh = _frameH / effectiveScale;
      // Centered cover-fit puts source image center at frame center;
      // translate shifts that. Negative translate = image moved up/left
      // visually, which means the visible source rect moves down/right.
      final centerX = dec.width / 2 - _translate.dx / effectiveScale;
      final centerY = dec.height / 2 - _translate.dy / effectiveScale;
      final sx = (centerX - sw / 2).round().clamp(0, dec.width - 1);
      final sy = (centerY - sh / 2).round().clamp(0, dec.height - 1);
      var cropped = img.copyCrop(
        dec,
        x: sx,
        y: sy,
        width: sw.round().clamp(1, dec.width - sx),
        height: sh.round().clamp(1, dec.height - sy),
      );
      if (cropped.width > 1080) {
        cropped = img.copyResize(cropped, width: 1080);
      }
      final encoded = img.encodeJpg(cropped, quality: 92);
      if (!mounted) return;
      setState(() {
        _croppedBytes = Uint8List.fromList(encoded);
        _step = CpStep.detail;
      });
    } catch (e) {
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .error(title: 'Failed to crop image.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /* ─── Submit ─── */

  bool get _canPost {
    final activeId = ref.read(myServersProvider).activeServerId;
    return _croppedBytes != null &&
        _captionCtrl.text.trim().isNotEmpty &&
        activeId != null;
  }

  Future<void> _submit() async {
    if (!_canPost || _isUploading) return;
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) {
      ref
          .read(toastControllerProvider.notifier)
          .error(title: 'No active server selected.');
      return;
    }
    setState(() => _isUploading = true);
    try {
      final form = FormData.fromMap({
        'caption': _captionCtrl.text.trim(),
        'image': MultipartFile.fromBytes(_croppedBytes!, filename: 'post.jpg'),
      });
      await ref.read(apiDioProvider).post<Map<String, dynamic>>(
            '/servers/$serverId/posts',
            data: form,
            options: Options(contentType: 'multipart/form-data'),
          );
      if (!mounted) return;
      await ref.read(serverFeedProvider.notifier).refresh();
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Post shared.');
      context.go(Routes.appHome);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /* ─── Header back ─── */

  void _onBack() {
    if (_step == CpStep.detail) {
      setState(() => _step = CpStep.crop);
      return;
    }
    if (_step == CpStep.crop) {
      setState(() {
        _step = CpStep.source;
        _sourceBytes = null;
        _decoded = null;
      });
      if (_tab == SourceTab.photo) _startCamera();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.appHome);
    }
  }

  String get _headerTitle => switch (_step) {
        CpStep.source => 'New Post',
        CpStep.crop => 'Crop',
        CpStep.detail => 'Detail',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _step == CpStep.crop ? Colors.black : Colors.white,
      body: Column(
        children: [
          _Header(
            title: _headerTitle,
            onBack: _onBack,
            trailing: switch (_step) {
              CpStep.source when _tab == SourceTab.gallery => _NextButton(
                  enabled: _selectedAsset != null,
                  onTap: _loadFromSelectedAsset,
                ),
              CpStep.crop => _NextButton(
                  enabled: _decoded != null && !_isProcessing,
                  onTap: _commitCrop,
                  dark: true,
                ),
              _ => const SizedBox(width: 64),
            },
            dark: _step == CpStep.crop,
          ),
          Expanded(
            child: switch (_step) {
              CpStep.source => _buildSource(),
              CpStep.crop => _buildCrop(),
              CpStep.detail => _buildDetail(),
            },
          ),
          if (_step == CpStep.detail) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSource() {
    return Column(
      children: [
        Expanded(
          child: switch (_tab) {
            SourceTab.gallery => _GalleryPicker(
                selected: _selectedAsset,
                onSelect: (a) => setState(() => _selectedAsset = a),
              ),
            SourceTab.photo => _PhotoStage(
                controller: _camCtrl,
                initializing: _camInitializing,
                errorText: _camError,
                onShutter: _captureFrame,
                onPickGallery: () => _onSourceTabChanged(SourceTab.gallery),
                onFlip: _flipCamera,
                onMount: _startCamera,
              ),
            SourceTab.video => const _VideoStage(),
          },
        ),
        _SourceTabs(active: _tab, onTap: _onSourceTabChanged),
      ],
    );
  }

  Widget _buildCrop() {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  _recalcStage(c.maxWidth);
                  final src = _sourceBytes;
                  if (src == null) return const SizedBox.shrink();
                  return SizedBox(
                    width: _frameW,
                    height: _frameH,
                    child: ClipRect(
                      child: GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            // Cover-fit the source into the frame, then
                            // scale + translate it for zoom + pan.
                            Transform.translate(
                              offset: _translate,
                              child: Transform.scale(
                                scale: _zoom,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: _frameW,
                                  height: _frameH,
                                  child: Image.memory(
                                    src,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                size: Size(_frameW, _frameH),
                                painter: _CropGridPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _ZoomRow(value: _zoom, onChanged: _onZoomChanged),
          _AspectStrip(active: _aspectId, onTap: _changeAspect),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final servers = ref.watch(myServersProvider);
    final activeName = servers.activeServer?.name ?? 'No server selected';
    final captionLen = _captionCtrl.text.length;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 200,
              height: 200,
              child: _croppedBytes != null
                  ? Image.memory(_croppedBytes!, fit: BoxFit.cover)
                  : Container(color: const Color(0xFFF1F3F5)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              TextField(
                controller: _captionCtrl,
                maxLines: 4,
                minLines: 4,
                maxLength: 2000,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a caption…',
                  hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                child: Text(
                  '$captionLen/2000',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: captionLen > 1900
                        ? AppColors.error
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MetaRow(icon: LucideIcons.users, label: 'Tag people'),
        _MetaRow(icon: LucideIcons.mapPin, label: 'Add location'),
        _MetaRow(icon: LucideIcons.music, label: 'Add music'),
        const SizedBox(height: 8),
        _ToggleRow(
          title: 'Post to other servers',
          help: 'Share to multiple servers at once',
        ),
        _ToggleRow(
          title: 'Hide like count',
          help: 'Only you can see how many likes this post gets',
        ),
        _ToggleRow(
          title: 'Turn off commenting',
          help: "Members can't comment on this post",
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'POSTING TO',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.88,
                  color: AppColors.textTertiary,
                ),
              ),
              Flexible(
                child: Text(
                  activeName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: Opacity(
          opacity: _canPost ? 1 : 0.4,
          child: Material(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _canPost && !_isUploading ? _submit : null,
              child: SizedBox(
                height: 48,
                child: Center(
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ─── Header ─── */

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.trailing,
    required this.dark,
  });

  final String title;
  final VoidCallback onBack;
  final Widget trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      color: dark ? Colors.black : Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: dark ? Colors.black : const Color(0xFFF1F3F5)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(LucideIcons.chevronLeft, size: 24, color: color),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.17,
                      color: color,
                    ),
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.enabled, required this.onTap, this.dark = false});

  final bool enabled;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.primary;
    final disabled = dark ? Colors.white38 : AppColors.textTertiary;
    return SizedBox(
      width: 64,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: disabled,
        ),
        child: const Text(
          'Next',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/* ─── Source step bodies ─── */

class _GalleryPicker extends StatefulWidget {
  const _GalleryPicker({required this.selected, required this.onSelect});

  final AssetEntity? selected;
  final ValueChanged<AssetEntity> onSelect;

  @override
  State<_GalleryPicker> createState() => _GalleryPickerState();
}

class _GalleryPickerState extends State<_GalleryPicker> {
  List<AssetEntity> _items = const [];
  bool _loading = true;
  bool _denied = false;
  bool _fullView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGallery());
  }

  Future<void> _loadGallery() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth && !perm.hasAccess) {
        if (!mounted) return;
        setState(() {
          _denied = true;
          _loading = false;
        });
        return;
      }
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (albums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = const [];
          _loading = false;
        });
        return;
      }
      final count = await albums.first.assetCountAsync;
      final assets = await albums.first.getAssetListRange(
        start: 0,
        end: count > 200 ? 200 : count,
      );
      if (!mounted) return;
      setState(() {
        _items = assets;
        _loading = false;
      });
      // Auto-select first (most recent) if nothing chosen yet.
      if (widget.selected == null && assets.isNotEmpty) {
        widget.onSelect(assets.first);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.imageOff,
                  size: 44, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text(
                'No access to your photos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant photo permission to pick an image from your library.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await PhotoManager.openSetting();
                  if (mounted) _loadGallery();
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No photos found.',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      children: [
        // Top preview — square frame; image cover or contain (full view).
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: widget.selected == null
                      ? null
                      : _AssetImage(
                          asset: widget.selected!,
                          size: const ThumbnailSize.square(1080),
                          fit: _fullView ? BoxFit.contain : BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _ExpandToggle(
                  expanded: _fullView,
                  onTap: () => setState(() => _fullView = !_fullView),
                ),
              ),
            ],
          ),
        ),
        // Recents header.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              const Text(
                'Recents',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronDown,
                  size: 18, color: AppColors.textSecondary),
              const Spacer(),
            ],
          ),
        ),
        // Grid — 4 cols.
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final a = _items[i];
              final active = widget.selected?.id == a.id;
              return _GridTile(
                asset: a,
                active: active,
                onTap: () => widget.onSelect(a),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.asset,
    required this.active,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetImage(
            asset: asset,
            size: const ThumbnailSize.square(200),
            fit: BoxFit.cover,
          ),
          if (active)
            const IgnorePointer(
              child: ColoredBox(color: Color(0x88FFFFFF)),
            ),
          if (active)
            const IgnorePointer(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(LucideIcons.check,
                      color: AppColors.primary, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x88000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            expanded ? LucideIcons.minimize2 : LucideIcons.maximize2,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({
    required this.asset,
    required this.size,
    this.fit = BoxFit.cover,
  });

  final AssetEntity asset;
  final ThumbnailSize size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(size),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return Container(color: const Color(0xFFE9ECEF));
        }
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

class _PhotoStage extends StatefulWidget {
  const _PhotoStage({
    required this.controller,
    required this.initializing,
    required this.errorText,
    required this.onShutter,
    required this.onPickGallery,
    required this.onFlip,
    required this.onMount,
  });

  final CameraController? controller;
  final bool initializing;
  final String? errorText;
  final VoidCallback onShutter;
  final VoidCallback onPickGallery;
  final VoidCallback onFlip;
  final VoidCallback onMount;

  @override
  State<_PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends State<_PhotoStage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMount());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final ready = ctrl != null && ctrl.value.isInitialized;
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Fill stage with cover crop — match Quasar object-fit:cover.
          if (ready)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  // camera value.aspectRatio is width / height in landscape
                  // sensor orientation. Use the previewSize, swapping axes
                  // to portrait when needed.
                  final preview = ctrl.value.previewSize;
                  final pw = preview?.height ?? c.maxWidth;
                  final ph = preview?.width ?? c.maxHeight;
                  return FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: pw,
                      height: ph,
                      child: CameraPreview(ctrl),
                    ),
                  );
                },
              ),
            ),
          if (!ready) Positioned.fill(child: Container(color: Colors.black)),
          // Error overlay
          if (widget.errorText != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xCC000000),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.cameraOff,
                            size: 36, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          widget.errorText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: widget.onPickGallery,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: const Text('Pick from gallery instead'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.initializing && !ready)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          // Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CamSideBtn(
                  icon: LucideIcons.image,
                  onTap: widget.onPickGallery,
                ),
                _Shutter(
                  enabled: ready,
                  onTap: widget.onShutter,
                ),
                _CamSideBtn(
                  icon: LucideIcons.refreshCw,
                  onTap: ready ? widget.onFlip : () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CamSideBtn extends StatelessWidget {
  const _CamSideBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.video, size: 44, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'Video posts coming soon',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.active, required this.onTap});

  final SourceTab active;
  final ValueChanged<SourceTab> onTap;

  static const _labels = [
    (SourceTab.gallery, 'Gallery'),
    (SourceTab.photo, 'Photo'),
    (SourceTab.video, 'Video'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: _labels.map((e) {
              final selected = e.$1 == active;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(e.$1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      e.$2,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : const Color(0xFF495057),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

/* ─── Crop step ─── */

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1;
    // 3x3 grid
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
    }
    // Outer frame
    final frame = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      frame,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ZoomRow extends StatelessWidget {
  const _ZoomRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.zoomOut, size: 16, color: Colors.white70),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: const Color(0xFF495057),
                thumbColor: Colors.white,
                overlayColor: Colors.white12,
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                min: _zoomMin,
                max: _zoomMax,
                onChanged: onChanged,
              ),
            ),
          ),
          const Icon(LucideIcons.zoomIn, size: 16, color: Colors.white70),
        ],
      ),
    );
  }
}

class _AspectStrip extends StatelessWidget {
  const _AspectStrip({required this.active, required this.onTap});

  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(top: 12, bottom: 40 + bottomInset),
      child: SizedBox(
        height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _aspects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = _aspects[i];
              final selected = a.id == active;
              return Material(
                color: selected ? Colors.white : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: selected ? Colors.white : Colors.white54),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onTap(a.id),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(
                      a.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: selected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ),
    );
  }
}

/* ─── Detail step rows ─── */

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: 0.7,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF495057)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.help});

  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Opacity(
        opacity: 0.7,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    help,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: false,
              onChanged: null,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
