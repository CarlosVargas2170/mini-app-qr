import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/app_settings.dart';
import 'core/di/service_locator.dart';
import 'core/services/app_server.dart';
import 'core/ui/themes/app_colors.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar window_manager para controlar la ventana nativa.
  await windowManager.ensureInitialized();

  // Configurar ventana: pantalla completa, sin bordes.
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Sin barra de titulo
    fullScreen: true, // Pantalla completa
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 0. Cargar variables de entorno desde el archivo .env
  await dotenv.load(fileName: ".env");

  // 1. Cargar configuracion desde disco (o fallback por defecto).
  await AppSettings().load();

  // 2. Inicializar inyeccion de dependencias con la config cargada.
  sl.init();

  // 3. Iniciar servidor HTTP unificado (config + audio en un solo puerto).
  final server = AppServer(port: 8080);
  server.start();

  // 4. Linux: forzar volumen del sistema a 130% (+6dB) para compensar
  //    la pérdida típica de GStreamer + PulseAudio en el pipeline de audio.
  // if (Platform.isLinux) {
  //   try {
  //     await Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '130%']);
  //     debugPrint('[Main]  Volumen del sistema seteado a 130%');
  //   } catch (_) {
  //     // Fallo silencioso: no bloquear arranque de la app
  //   }
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini App QR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(color: AppColors.textSecondary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodySmall: TextStyle(color: AppColors.textMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
