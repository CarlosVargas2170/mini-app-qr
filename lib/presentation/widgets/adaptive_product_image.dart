import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_settings.dart';
import 'app_image.dart';

const double _maxCompatibleAspectDifference = 1.55;

/// Determines whether an image would lose too much content with [BoxFit.cover].
@visibleForTesting
bool shouldContainProductImage({
  required Size imageSize,
  required Size containerSize,
}) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      containerSize.width <= 0 ||
      containerSize.height <= 0) {
    return false;
  }

  final imageAspectRatio = imageSize.width / imageSize.height;
  final containerAspectRatio = containerSize.width / containerSize.height;
  final aspectDifference = imageAspectRatio > containerAspectRatio
      ? imageAspectRatio / containerAspectRatio
      : containerAspectRatio / imageAspectRatio;

  return aspectDifference > _maxCompatibleAspectDifference;
}

/// Shows conventional product photos edge-to-edge and protects images with an
/// extreme aspect ratio from being cropped.
class AdaptiveProductImage extends StatefulWidget {
  final String imageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AdaptiveProductImage({
    super.key,
    required this.imageUrl,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AdaptiveProductImage> createState() => _AdaptiveProductImageState();
}

class _AdaptiveProductImageState extends State<AdaptiveProductImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Size? _imageSize;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imageStream == null) {
      _resolveImageSize();
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeImageListener();
      _imageSize = null;
      _hasError = false;
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final configuration = createLocalImageConfiguration(context);
    final ImageStream stream;
    if (AppSettings().enableImageCache) {
      stream = CachedNetworkImageProvider(widget.imageUrl).resolve(
        configuration,
      );
    } else {
      stream = NetworkImage(widget.imageUrl).resolve(configuration);
    }
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            imageInfo.image.width.toDouble(),
            imageInfo.image.height.toDouble(),
          );
          _hasError = false;
        });
      },
      onError: (Object _, StackTrace? __) {
        if (!mounted) return;
        setState(() => _hasError = true);
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? const SizedBox.shrink();
    }

    final imageSize = _imageSize;
    if (imageSize == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final requiresContainedLayout = shouldContainProductImage(
          imageSize: imageSize,
          containerSize: containerSize,
        );

        if (!requiresContainedLayout) {
          return AppImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            errorWidget: widget.errorWidget,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.08,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AppImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: widget.errorWidget,
                ),
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                errorWidget: widget.errorWidget,
              ),
            ),
          ],
        );
      },
    );
  }
}
