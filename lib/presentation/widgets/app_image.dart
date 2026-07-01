import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_settings.dart';

/// Widget que muestra una imagen de red con cache opcional.
/// Si [AppSettings.enableImageCache] es true usa [CachedNetworkImage],
/// si es false usa [Image.network] estándar.
class AppImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (AppSettings().enableImageCache) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 300),
        progressIndicatorBuilder: (context, url, progress) {
          debugPrint('[AppImage] Descargando desde RED: $url (${(progress.progress ?? 0 * 100).toStringAsFixed(0)}%)');
          return placeholder ?? const SizedBox.shrink();
        },
        errorWidget: errorWidget != null
            ? (_, __, ___) => errorWidget!
            : null,
        imageBuilder: (context, imageProvider) {
          debugPrint('[AppImage] Imagen lista: $imageUrl');
          return Image(
            image: imageProvider,
            fit: fit,
          );
        },
      );
    }

    return Image.network(
      imageUrl,
      fit: fit,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          debugPrint('[AppImage] Imagen lista (sin cache): $imageUrl');
          return child;
        }
        debugPrint('[AppImage] Descargando desde RED (sin cache): $imageUrl');
        return placeholder ?? const SizedBox.shrink();
      },
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget!
          : null,
    );
  }
}
