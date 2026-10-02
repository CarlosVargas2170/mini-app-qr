import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Tipo de archivo remoto que el robot acepta descargar.
enum MediaKind {
  audio(
    folder: 'audio',
    extensions: {'.wav', '.mp3', '.ogg', '.m4a', '.aac'},
    maxBytes: 20 * 1024 * 1024,
  ),
  image(
    folder: 'images',
    extensions: {'.gif'},
    maxBytes: 25 * 1024 * 1024,
  );

  const MediaKind({
    required this.folder,
    required this.extensions,
    required this.maxBytes,
  });

  /// Subcarpeta de la caché donde se guardan los archivos de este tipo.
  final String folder;
  final Set<String> extensions;
  final int maxBytes;
}

/// Falla al validar o descargar un archivo remoto.
class MediaCacheException implements Exception {
  const MediaCacheException(this.message, {this.invalidUrl = false});

  final String message;

  /// `true` si la URL no está permitida (error del cliente, HTTP 400);
  /// `false` si la descarga o el guardado fallaron (HTTP 502).
  final bool invalidUrl;

  @override
  String toString() => message;
}

/// Cloud de Cloudinary desde el que el robot acepta archivos.
/// Se puede cambiar con `CLOUDINARY_CLOUD_NAME` en el `.env`.
const String defaultCloudinaryCloudName = 'zrwcfuqw';
const String _cloudinaryHost = 'res.cloudinary.com';

/// `true` si [value] apunta a un archivo remoto (`https://...`) y no a un asset.
bool isRemoteMediaReference(String? value) =>
    value != null && value.contains('://');

String configuredCloudinaryCloudName() {
  try {
    final fromEnv = dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  } catch (_) {
    // .env sin cargar (tests): se usa el valor por defecto.
  }
  return defaultCloudinaryCloudName;
}

/// Valida que [raw] sea una URL de Cloudinary que el robot puede descargar.
///
/// El servidor HTTP del robot no tiene autenticación, así que solo se aceptan
/// URLs `https://res.cloudinary.com/<cloud>/<image|video>/upload/...` con un
/// archivo de la extensión esperada. Cualquier otra cosa devuelve `null`.
Uri? parseCloudinaryMediaUrl(String? raw, MediaKind kind, {String? cloudName}) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;

  if (uri.scheme != 'https' || uri.host != _cloudinaryHost) return null;
  if (uri.hasPort && uri.port != 443) return null;
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;

  // Cloud, tipo de recurso, 'upload' y al menos el nombre del archivo.
  final segments = uri.pathSegments;
  if (segments.length < 4) return null;
  final unsafe = segments.any((segment) =>
      segment.isEmpty ||
      segment == '.' ||
      segment == '..' ||
      segment.contains('/') ||
      segment.contains(r'\'));
  if (unsafe) return null;

  if (segments.first != (cloudName ?? configuredCloudinaryCloudName())) {
    return null;
  }
  // Cloudinary guarda los audios como "video"; un video convertido a GIF también.
  final resourceTypes =
      kind == MediaKind.audio ? const {'video'} : const {'image', 'video'};
  if (!resourceTypes.contains(segments[1]) || segments[2] != 'upload') {
    return null;
  }
  if (!kind.extensions.contains(_extensionOf(segments.last))) return null;

  return uri;
}

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? '' : fileName.substring(dot).toLowerCase();
}

/// Nombre del archivo en la caché: el final de la URL, que en los archivos
/// subidos desde el panel ya es único (lleva un sufijo aleatorio).
@visibleForTesting
String cacheFileName(Uri url) =>
    url.pathSegments.last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Descarga audios y GIFs de Cloudinary y los guarda en disco, para
/// reproducirlos sin internet después de la primera vez.
///
/// Los archivos se guardan por fuera de `build/` (que se borra al compilar):
/// ver [candidatePaths].
class MediaCache {
  MediaCache({Dio? dio, Directory? directory, String? cloudName})
      : _dio = dio ?? createDio(),
        _fixedDirectory = directory,
        _cloudName = cloudName;

  /// Caché compartida por el servidor HTTP. Los tests la reemplazan por una con
  /// un Cloudinary falso.
  static MediaCache instance = MediaCache();

  static const String _appFolder = 'mini_app_qr';
  static const String _cacheFolder = 'media_cache';

  final Dio _dio;
  final Directory? _fixedDirectory;
  final String? _cloudName;

  Future<Directory>? _root;

  /// Descargas en curso por archivo: dos peticiones del mismo archivo comparten una.
  final Map<String, Future<File>> _inFlight = {};

  /// Cliente HTTP con las restricciones de la caché (los tests le cambian el adaptador).
  @visibleForTesting
  static Dio createDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        // Sin redirecciones: Cloudinary responde directo y no debe poder
        // mandar al robot a otro host.
        followRedirects: false,
        validateStatus: (status) => status == 200,
      ));

  /// Devuelve el archivo local de [rawUrl], descargándolo si aún no está.
  ///
  /// Lanza [MediaCacheException] si la URL no está permitida o la descarga falla.
  Future<File> fetch(String rawUrl, MediaKind kind) async {
    final url = parseCloudinaryMediaUrl(rawUrl, kind, cloudName: _cloudName);
    if (url == null) {
      throw MediaCacheException(
        'URL no permitida: solo https://res.cloudinary.com/'
        '${_cloudName ?? configuredCloudinaryCloudName()}/... con un archivo '
        '${kind.extensions.join(', ')}',
        invalidUrl: true,
      );
    }

    final root = await _rootDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}${kind.folder}');
    final target =
        File('${dir.path}${Platform.pathSeparator}${cacheFileName(url)}');

    return _inFlight[target.path] ??=
        _download(url, kind, dir, target).whenComplete(() {
      _inFlight.remove(target.path);
    });
  }

  Future<File> _download(
      Uri url, MediaKind kind, Directory dir, File target) async {
    if (await target.exists() && await target.length() > 0) return target;

    await dir.create(recursive: true);
    // Se descarga a un .part y se renombra al terminar: un corte a mitad de
    // camino nunca deja un archivo incompleto con el nombre final.
    final part = File('${target.path}.part');
    final cancel = CancelToken();
    try {
      await _dio.download(
        url.toString(),
        part.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > kind.maxBytes || total > kind.maxBytes) {
            cancel.cancel('too_large');
          }
        },
      );
      if (await part.length() == 0) {
        throw const MediaCacheException('El archivo descargado está vacío');
      }
      await part.rename(target.path);
      debugPrint('[MediaCache] Descargado: ${target.path}');
      return target;
    } on DioException catch (error) {
      throw MediaCacheException(_describe(error, kind));
    } on FileSystemException catch (error) {
      throw MediaCacheException(
          'No se pudo guardar el archivo en la caché: ${error.message}');
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  String _describe(DioException error, MediaKind kind) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return 'El archivo supera el máximo de ${kind.maxBytes ~/ (1024 * 1024)} MB';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Cloudinary no respondió a tiempo';
      case DioExceptionType.connectionError:
        return 'Sin conexión con Cloudinary';
      case DioExceptionType.badResponse:
        return 'Cloudinary respondió ${error.response?.statusCode}';
      default:
        return error.message ?? 'No se pudo descargar el archivo';
    }
  }

  /// Carpeta raíz de la caché; la crea y limpia descargas a medias la primera vez.
  Future<Directory> _rootDirectory() => _root ??= _initRoot();

  Future<Directory> _initRoot() async {
    final fixed = _fixedDirectory;
    final candidates = fixed != null
        ? [fixed.path]
        : candidatePaths(
            env: Platform.environment,
            platform: Platform.operatingSystem,
            executablePath: Platform.resolvedExecutable,
          );

    Object? lastError;
    for (final path in candidates) {
      try {
        final dir = Directory(path);
        await dir.create(recursive: true);
        await _removeStaleParts(dir);
        debugPrint('[MediaCache] Carpeta de caché: ${dir.path}');
        return dir;
      } catch (error) {
        lastError = error;
        debugPrint('[MediaCache] No se pudo usar $path: $error');
      }
    }
    _root = null; // permitir reintentar en la siguiente petición
    throw MediaCacheException('No se pudo crear la carpeta de caché: $lastError');
  }

  Future<void> _removeStaleParts(Directory root) async {
    try {
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.part')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Limpieza de cortesía: si falla, no impide usar la caché.
    }
  }

  /// Carpetas candidatas, de la preferida a la de último recurso.
  ///
  /// 1. Datos del usuario (`~/.local/share/mini_app_qr/media_cache` en Linux):
  ///    sobrevive a recompilar (`build/` se borra) y a actualizar el bundle.
  /// 2. Junto al ejecutable.
  /// 3. Carpeta temporal del sistema.
  @visibleForTesting
  static List<String> candidatePaths({
    required Map<String, String> env,
    required String platform,
    required String executablePath,
  }) {
    final separator = platform == 'windows' ? r'\' : '/';
    final home = env['HOME'];
    String? dataDir;
    switch (platform) {
      case 'windows':
        dataDir = env['LOCALAPPDATA'];
      case 'macos':
        dataDir = (home == null || home.isEmpty)
            ? null
            : '$home/Library/Application Support';
      default:
        final xdg = env['XDG_DATA_HOME'];
        if (xdg != null && xdg.isNotEmpty) {
          dataDir = xdg;
        } else if (home != null && home.isNotEmpty) {
          dataDir = '$home/.local/share';
        }
    }

    String join(String base) => '$base$separator$_appFolder$separator$_cacheFolder';
    return [
      if (dataDir != null && dataDir.isNotEmpty) join(dataDir),
      '${File(executablePath).parent.path}$separator$_cacheFolder',
      join(Directory.systemTemp.path),
    ];
  }
}
