import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/config/app_settings.dart';
import 'package:mini_app_qr/core/services/app_server.dart';

void main() {
  group('normalizeAudioAssetPath', () {
    test('acepta audios registrados y normaliza el prefijo assets', () {
      expect(
        normalizeAudioAssetPath('audio/kiky/saludo.wav'),
        'audio/kiky/saludo.wav',
      );
      expect(
        normalizeAudioAssetPath(' assets/audio/saludo.MP3 '),
        'audio/saludo.MP3',
      );
      expect(
        normalizeAudioAssetPath(r'audio\kiky\saludo.m4a'),
        'audio/kiky/saludo.m4a',
      );
    });

    test('rechaza rutas externas, recorridos y formatos no soportados', () {
      expect(normalizeAudioAssetPath(null), isNull);
      expect(normalizeAudioAssetPath(''), isNull);
      expect(normalizeAudioAssetPath('/tmp/saludo.wav'), isNull);
      expect(normalizeAudioAssetPath('audio/../saludo.wav'), isNull);
      expect(normalizeAudioAssetPath('https://example.com/saludo.wav'), isNull);
      expect(normalizeAudioAssetPath('audio/notas.txt'), isNull);
    });
  });

  group('buildPublicConfigData', () {
    test('excluye credenciales de la respuesta publica', () {
      final settings = AppSettings()
        ..baseUrl = 'https://api.example.com'
        ..bearerToken = 'secret-token'
        ..ecosystemBearerToken = 'ecosystem-secret';

      final data = buildPublicConfigData(settings);

      expect(data, isNot(contains('bearerToken')));
      expect(data, isNot(contains('ecosystemBearerToken')));
      expect(data['baseUrl'], 'https://api.example.com');
    });
  });
}
