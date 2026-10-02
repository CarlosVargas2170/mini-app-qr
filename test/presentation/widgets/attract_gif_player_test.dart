import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/attract_gif_player.dart';

void main() {
  Image shownImage(WidgetTester tester) =>
      tester.widget<Image>(find.byType(Image));

  testWidgets('un GIF incluido en la app se muestra desde assets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AttractGifPlayer(assetPath: 'assets/images/happy.gif'),
    ));

    expect(shownImage(tester).image, isA<AssetImage>());
  });

  testWidgets('un GIF descargado de Cloudinary se muestra desde el archivo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AttractGifPlayer(
          assetPath: '/home/robot/.local/share/mini_app_qr/media_cache/images/wink.gif'),
    ));

    expect(shownImage(tester).image, isA<FileImage>());
  });
}
