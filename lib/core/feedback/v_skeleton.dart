import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/tokens.dart';

/// Shimmer skeleton placeholder. Default = rounded rectangle.
class VSkeleton extends StatelessWidget {
  const VSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.shape = BoxShape.rectangle,
  });

  /// Convenience for circular skeleton (avatar).
  const VSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.skeletonBase,
      highlightColor: AppColors.skeletonHighlight,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.skeletonBase,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
          shape: shape,
        ),
      ),
    );
  }
}
