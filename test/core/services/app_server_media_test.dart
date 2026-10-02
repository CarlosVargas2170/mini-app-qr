import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/config/app_settings.dart';
import 'package:mini_app_qr/core/services/app_server.dart';
import 'package:mini_app_qr/core/services/media_cache.dart';
import 'package:mini_app_qr/core/services/ui_command_bus.dart';

const _cloud = 'zrwcfuqw';
const _gifUrl =
    'https://res.cloudinary.com/$_cloud/image/upload/v1/robotics/emotions/wink_ab12-1f2e3d4c.gif';
const _audioUrl =
    'https://res.cloudinary.com/$_cloud/video/upload/v1/robotics/audios/test1_52as-906a1c86.mp3';

/// Cloudinary falso: responde [status] y cuenta las peticiones.
class _FakeCloudinary implements HttpClientAdapter {
  int status = 200;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri);
    return ResponseBody.fromBytes(
        status == 200 ? [71, 73, 70, 56, 57, 97] : [], status);
  }

  @override
  void close({bool force = false}) {}
}

/// Levanta el AppServer real en un puerto libre, con Cloudinary falso y sin
/// tocar el audio ni la pantalla: solo comprueba lo que el robot responde.
void main() {
  late AppServer server;
  late Directory cacheDir;
  late _FakeCloudinary cloudinary;
  late int port;
  final commands = <UiCommand>[];
  late StreamSubscription<UiCommand> commandSub;

  Future<({int status, Map<String, dynamic> body})> request(
    String method,
    String path, [
    Map<String, dynamic>? json,
  ]) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
      if (json != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(json));
      }
      final res = await req.close();
      final text = await utf8.decoder.bind(res).join();
      return (status: res.statusCode, body: jsonDecode(text) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('app_server_media_test_');
    cloudinary = _FakeCloudinary();
    MediaCache.instance = MediaCache(
      dio: MediaCache.createDio()..httpClientAdapter = cloudinary,
      directory: cacheDir,
      cloudName: _cloud,
    );

    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();
    AppSettings().baseUrlVpn = '127.0.0.1';
    AppSettings().portVpn = port;

    server = AppServer();
    unawaited(server.start());
    for (var i = 0; i < 50; i++) {
      try {
        (await Socket.connect('127.0.0.1', port)).destroy();
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    commandSub = UiCommandBus.stream.listen(commands.add);
  });

  tearDownAll(() async {
    await commandSub.cancel();
    await server.stop();
    MediaCache.instance = MediaCache();
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  setUp(() {
    cloudinary
      ..status = 200
      ..requests.clear();
    commands.clear();
    UiCommandBus.currentGifName = 'attract';
    UiCommandBus.currentGifUrl = null;
  });

  group('POST /attract/set', () {
    test('con una URL de Cloudinary descarga el GIF y lo muestra desde la caché',
        () async {
      final res = await request('POST', '/attract/set', {'gif': 'wink', 'url': _gifUrl});
      await Future<void>.delayed(Duration.zero);

      expect(res.status, 200);
      expect(res.body['url'], _gifUrl);
      final path = res.body['assetPath'] as String;
      expect(path, startsWith(cacheDir.path));
      expect(File(path).existsSync(), isTrue);

      expect(commands.whereType<ShowAttract>().single.gifAsset, path);
      expect(UiCommandBus.currentGifName, 'wink');
      expect(UiCommandBus.currentGifUrl, _gifUrl);

      final current = await request('GET', '/attract/current');
      expect(current.body['url'], _gifUrl);
      expect(current.body['assetPath'], isNull);
    });

    test('la segunda vez usa la caché y no vuelve a descargar', () async {
      await request('POST', '/attract/set', {'gif': 'wink', 'url': _gifUrl});
      cloudinary.requests.clear();

      final res = await request('POST', '/attract/set', {'gif': 'wink', 'url': _gifUrl});

      expect(res.status, 200);
      expect(cloudinary.requests, isEmpty);
    });

    test('sin URL sigue usando el GIF incluido en la app', () async {
      UiCommandBus.currentGifUrl = 'https://anterior';
      final res = await request('POST', '/attract/set', {'gif': 'happy'});
      await Future<void>.delayed(Duration.zero);

      expect(res.status, 200);
      expect(res.body['assetPath'], 'assets/images/happy.gif');
      expect(res.body.containsKey('url'), isFalse);
      expect(commands.whereType<ShowAttract>().single.gifAsset, 'assets/images/happy.gif');
      expect(UiCommandBus.currentGifUrl, isNull);

      final current = await request('GET', '/attract/current');
      expect(current.body['assetPath'], 'assets/images/happy.gif');
      expect(current.body.containsKey('url'), isFalse);
    });

    test('una URL no permitida responde 400 y no cambia el GIF', () async {
      final res = await request('POST', '/attract/set',
          {'gif': 'wink', 'url': 'https://evil.com/wink.gif'});
      await Future<void>.delayed(Duration.zero);

      expect(res.status, 400);
      expect(res.body['success'], isFalse);
      expect(commands.whereType<ShowAttract>(), isEmpty);
      expect(UiCommandBus.currentGifName, 'attract');
      expect(cloudinary.requests, isEmpty);
    });

    test('si Cloudinary falla responde 502 y no cambia el GIF', () async {
      cloudinary.status = 500;
      final res = await request('POST', '/attract/set',
          {'gif': 'otro', 'url': _gifUrl.replaceFirst('wink_ab12', 'otro_cd34')});
      await Future<void>.delayed(Duration.zero);

      expect(res.status, 502);
      expect(res.body['message'], contains('500'));
      expect(commands.whereType<ShowAttract>(), isEmpty);
      expect(UiCommandBus.currentGifName, 'attract');
    });
  });

  group('audios por URL: lo que se rechaza antes de reproducir', () {
    for (final target in <(String, String Function(String url))>[
      ('POST /audio/play', (url) => '/audio/play'),
      ('POST /play-audio', (url) => '/play-audio?asset=${Uri.encodeQueryComponent(url)}'),
      ('POST /greet/audio', (url) => '/greet/audio?asset=${Uri.encodeQueryComponent(url)}'),
    ]) {
      final (name, pathFor) = target;

      Future<({int status, Map<String, dynamic> body})> play(String url) =>
          request('POST', pathFor(url), name == 'POST /audio/play' ? {'asset': url} : null);

      test('$name: una URL de otro servidor responde 400 sin descargar', () async {
        final res = await play('https://evil.com/x.mp3');

        expect(res.status, 400);
        expect(res.body['success'], isFalse);
        expect(cloudinary.requests, isEmpty);
      });

      test('$name: un GIF no es un audio', () async {
        final res = await play(_gifUrl);

        expect(res.status, 400);
        expect(cloudinary.requests, isEmpty);
      });

      test('$name: si Cloudinary falla responde 502 con el motivo', () async {
        cloudinary.status = 404;
        final res = await play(_audioUrl);

        expect(res.status, 502);
        expect(res.body['message'], contains('404'));
        expect(cloudinary.requests, hasLength(1));
      });
    }
  });
}
