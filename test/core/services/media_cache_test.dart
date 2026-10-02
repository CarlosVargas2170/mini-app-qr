import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/services/media_cache.dart';

const _cloud = 'zrwcfuqw';
const _audioUrl =
    'https://res.cloudinary.com/$_cloud/video/upload/v1790885791/robotics/audios/test1_52as-906a1c86.mp3';
const _gifUrl =
    'https://res.cloudinary.com/$_cloud/image/upload/v1790885791/robotics/emotions/guino_wve1-8c2d1e0f.gif';
const _videoGifUrl =
    'https://res.cloudinary.com/$_cloud/video/upload/v1790885791/robotics/emotions/baile_ab12-1f2e3d4c.gif';

/// Adaptador HTTP falso: cuenta las peticiones y responde lo que indique [handler].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options.uri);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(List<int> bytes, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromBytes(bytes, 200, headers: headers ?? const {});

void main() {
  group('parseCloudinaryMediaUrl', () {
    test('acepta audios y GIF de Cloudinary', () {
      expect(parseCloudinaryMediaUrl(_audioUrl, MediaKind.audio), isNotNull);
      expect(parseCloudinaryMediaUrl(_gifUrl, MediaKind.image), isNotNull);
      // Un video convertido a GIF se sirve desde "video/upload" con extensión .gif.
      expect(parseCloudinaryMediaUrl(_videoGifUrl, MediaKind.image), isNotNull);
      expect(
        parseCloudinaryMediaUrl(
            ' $_audioUrl '.replaceAll('.mp3', '.WAV'), MediaKind.audio),
        isNotNull,
        reason: 'ignora espacios y mayúsculas en la extensión',
      );
    });

    test('rechaza otros protocolos y otros servidores', () {
      for (final url in [
        _audioUrl.replaceFirst('https', 'http'),
        'https://example.com/$_cloud/video/upload/x.mp3',
        'https://res.cloudinary.com.evil.com/$_cloud/video/upload/x.mp3',
        'https://evil.com/res.cloudinary.com/$_cloud/video/upload/x.mp3',
        'https://res.cloudinary.com@evil.com/$_cloud/video/upload/x.mp3',
        'https://user:pass@res.cloudinary.com/$_cloud/video/upload/x.mp3',
        'https://res.cloudinary.com:8443/$_cloud/video/upload/x.mp3',
        'file:///etc/passwd',
        '/tmp/x.mp3',
        'audio/x.mp3',
        '',
      ]) {
        expect(parseCloudinaryMediaUrl(url, MediaKind.audio), isNull,
            reason: url);
      }
      expect(parseCloudinaryMediaUrl(null, MediaKind.audio), isNull);
    });

    test('rechaza otros clouds de Cloudinary', () {
      expect(
        parseCloudinaryMediaUrl(
            'https://res.cloudinary.com/otro/video/upload/x.mp3',
            MediaKind.audio),
        isNull,
      );
      expect(
        parseCloudinaryMediaUrl(
            'https://res.cloudinary.com/otro/video/upload/x.mp3',
            MediaKind.audio,
            cloudName: 'otro'),
        isNotNull,
      );
    });

    test('rechaza recorridos de ruta, query y fragmentos', () {
      for (final url in [
        'https://res.cloudinary.com/$_cloud/video/upload/../../x.mp3',
        'https://res.cloudinary.com/$_cloud/video/upload/%2e%2e/x.mp3',
        'https://res.cloudinary.com/$_cloud/video/upload/a%2Fb.mp3',
        'https://res.cloudinary.com/$_cloud/video/upload/a%5Cb.mp3',
        'https://res.cloudinary.com/$_cloud/video/upload//x.mp3',
        '$_audioUrl?x=1',
        '$_audioUrl#frag',
        'https://res.cloudinary.com/$_cloud/video/upload/robotics/',
      ]) {
        expect(parseCloudinaryMediaUrl(url, MediaKind.audio), isNull,
            reason: url);
      }
    });

    test('rechaza tipos de recurso y extensiones que no corresponden', () {
      // Los audios viven en "video"; "image" no es un audio.
      expect(
        parseCloudinaryMediaUrl(
            'https://res.cloudinary.com/$_cloud/image/upload/x.mp3',
            MediaKind.audio),
        isNull,
      );
      expect(
        parseCloudinaryMediaUrl(
            'https://res.cloudinary.com/$_cloud/video/download/x.mp3',
            MediaKind.audio),
        isNull,
      );
      expect(parseCloudinaryMediaUrl(_gifUrl, MediaKind.audio), isNull);
      expect(parseCloudinaryMediaUrl(_audioUrl, MediaKind.image), isNull);
      for (final extension in ['.exe', '.sh', '.txt', '.mp4', '']) {
        expect(
          parseCloudinaryMediaUrl(
              'https://res.cloudinary.com/$_cloud/video/upload/x$extension',
              MediaKind.audio),
          isNull,
          reason: extension,
        );
      }
    });
  });

  group('helpers', () {
    test('isRemoteMediaReference distingue URLs de rutas de assets', () {
      expect(isRemoteMediaReference(_audioUrl), isTrue);
      expect(isRemoteMediaReference('http://x/y.mp3'), isTrue);
      expect(isRemoteMediaReference('audio/hello.wav'), isFalse);
      expect(isRemoteMediaReference('assets/audio/hello.wav'), isFalse);
      expect(isRemoteMediaReference(null), isFalse);
    });

    test('cacheFileName usa el final de la URL', () {
      expect(cacheFileName(Uri.parse(_audioUrl)), 'test1_52as-906a1c86.mp3');
    });

    test('la carpeta preferida es la de datos del usuario, no build/', () {
      final linux = MediaCache.candidatePaths(
        env: {'HOME': '/home/robot'},
        platform: 'linux',
        executablePath:
            '/home/robot/app/build/linux/arm64/release/bundle/mini_app_qr',
      );
      expect(linux.first, '/home/robot/.local/share/mini_app_qr/media_cache');
      expect(linux, hasLength(3));
      expect(linux[1], endsWith('media_cache')); // junto al ejecutable
      expect(linux[1], contains('bundle'));

      final xdg = MediaCache.candidatePaths(
        env: {'HOME': '/home/robot', 'XDG_DATA_HOME': '/data'},
        platform: 'linux',
        executablePath: '/x/mini_app_qr',
      );
      expect(xdg.first, '/data/mini_app_qr/media_cache');

      final windows = MediaCache.candidatePaths(
        env: {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'},
        platform: 'windows',
        executablePath: r'C:\app\mini_app_qr.exe',
      );
      expect(windows.first,
          r'C:\Users\u\AppData\Local\mini_app_qr\media_cache');

      // Sin HOME ni carpeta de datos: queda el ejecutable y la carpeta temporal.
      final bare = MediaCache.candidatePaths(
        env: {},
        platform: 'linux',
        executablePath: '/x/mini_app_qr',
      );
      expect(bare, hasLength(2));
    });
  });

  group('MediaCache.fetch', () {
    late Directory root;
    late _FakeAdapter adapter;
    late MediaCache cache;

    MediaCache buildCache(
        Future<ResponseBody> Function(RequestOptions) handler) {
      adapter = _FakeAdapter(handler);
      final dio = MediaCache.createDio()..httpClientAdapter = adapter;
      return MediaCache(dio: dio, directory: root, cloudName: _cloud);
    }

    List<String> filesIn(Directory directory) => directory
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .toList();

    setUp(() {
      root = Directory.systemTemp.createTempSync('media_cache_test_');
      cache = buildCache((_) async => _ok([1, 2, 3, 4]));
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('descarga una vez y reutiliza el archivo', () async {
      final first = await cache.fetch(_audioUrl, MediaKind.audio);
      expect(first.readAsBytesSync(), [1, 2, 3, 4]);
      expect(first.path, contains('audio'));
      expect(first.path, endsWith('test1_52as-906a1c86.mp3'));

      final second = await cache.fetch(_audioUrl, MediaKind.audio);
      expect(second.path, first.path);
      expect(adapter.requests, hasLength(1));
    });

    test('guarda los GIF en su propia carpeta', () async {
      final file = await cache.fetch(_gifUrl, MediaKind.image);
      expect(file.path, contains('images'));
      expect(file.path, endsWith('.gif'));
    });

    test('un archivo ya descargado funciona sin internet', () async {
      await cache.fetch(_audioUrl, MediaKind.audio);

      final offline = buildCache(
          (_) => throw DioException(requestOptions: RequestOptions()));
      final file = await offline.fetch(_audioUrl, MediaKind.audio);
      expect(file.existsSync(), isTrue);
      expect(adapter.requests, isEmpty);
    });

    test('dos peticiones simultáneas del mismo archivo descargan una vez',
        () async {
      cache = buildCache((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _ok([9, 9]);
      });

      final files = await Future.wait([
        cache.fetch(_audioUrl, MediaKind.audio),
        cache.fetch(_audioUrl, MediaKind.audio),
      ]);
      expect(files[0].path, files[1].path);
      expect(adapter.requests, hasLength(1));
    });

    test('rechaza URLs no permitidas sin tocar la red', () async {
      for (final url in [
        'https://example.com/x.mp3',
        _gifUrl, // un GIF no es un audio
      ]) {
        await expectLater(
          cache.fetch(url, MediaKind.audio),
          throwsA(isA<MediaCacheException>()
              .having((e) => e.invalidUrl, 'invalidUrl', isTrue)),
          reason: url,
        );
      }
      expect(adapter.requests, isEmpty);
    });

    test('un error de Cloudinary no deja archivos en la caché', () async {
      cache = buildCache((_) async => ResponseBody.fromBytes([], 404));

      await expectLater(
        cache.fetch(_audioUrl, MediaKind.audio),
        throwsA(isA<MediaCacheException>()
            .having((e) => e.invalidUrl, 'invalidUrl', isFalse)
            .having((e) => e.message, 'message', contains('404'))),
      );
      expect(filesIn(root), isEmpty);
    });

    test('no sigue redirecciones a otro servidor', () async {
      cache = buildCache((_) async => ResponseBody.fromBytes([], 302, headers: {
            'location': ['https://evil.com/x.mp3'],
          }));

      await expectLater(
        cache.fetch(_audioUrl, MediaKind.audio),
        throwsA(isA<MediaCacheException>()),
      );
      expect(adapter.requests, hasLength(1));
      expect(filesIn(root), isEmpty);
    });

    test('rechaza archivos que superan el tamaño máximo', () async {
      final tooBig = '${MediaKind.audio.maxBytes + 1}';
      cache = buildCache((_) async => _ok([1, 2, 3], headers: {
            'content-length': [tooBig],
          }));

      await expectLater(
        cache.fetch(_audioUrl, MediaKind.audio),
        throwsA(isA<MediaCacheException>()
            .having((e) => e.message, 'message', contains('máximo'))),
      );
      expect(filesIn(root), isEmpty);
    });

    test('no guarda archivos vacíos', () async {
      cache = buildCache((_) async => _ok([]));

      await expectLater(
        cache.fetch(_audioUrl, MediaKind.audio),
        throwsA(isA<MediaCacheException>()),
      );
      expect(filesIn(root), isEmpty);
    });

    test('tras un fallo se puede volver a intentar', () async {
      var attempt = 0;
      cache = buildCache((_) async =>
          ++attempt == 1 ? ResponseBody.fromBytes([], 500) : _ok([7]));

      await expectLater(cache.fetch(_audioUrl, MediaKind.audio),
          throwsA(isA<MediaCacheException>()));
      final file = await cache.fetch(_audioUrl, MediaKind.audio);
      expect(file.readAsBytesSync(), [7]);
    });

    test('al iniciar borra descargas a medias de ejecuciones anteriores',
        () async {
      final stale = File('${root.path}/audio/viejo.mp3.part')
        ..createSync(recursive: true);

      await cache.fetch(_audioUrl, MediaKind.audio);

      expect(stale.existsSync(), isFalse);
    });
  });
}
