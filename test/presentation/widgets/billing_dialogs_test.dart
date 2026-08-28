import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/billing_dialogs.dart';

void main() {
  testWidgets('continuar sin factura devuelve una selección sin datos',
      (tester) async {
    BillingFlowResult? result;
    await _pumpDialog(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('billing_no_button')));
    await tester.pumpAndSettle();

    expect(result?.wantsInvoice, isFalse);
    expect(result?.nit, isNull);
    expect(result?.businessName, isNull);
  });

  testWidgets('la X cierra el flujo para volver al carrusel', (tester) async {
    var completed = false;
    BillingFlowResult? result = const BillingFlowResult.withoutInvoice();
    await _pumpDialog(
      tester,
      onResult: (value) {
        result = value;
        completed = true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('billing_close_button')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('cambia al formulario y permite regresar a la consulta',
      (tester) async {
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing_form_step')), findsOneWidget);
    expect(find.text('DATOS PARA LA FACTURA'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('billing_keyboard_alpha')), findsOneWidget);

    final business = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    final nit = tester.widget<TextFormField>(
      find.byKey(const ValueKey('nit_field')),
    );
    business.controller?.text = 'Empresa temporal';
    nit.controller?.text = '123456';

    await tester.tap(find.byKey(const ValueKey('billing_form_back_button')));
    await tester.pumpAndSettle();
    expect(find.text('¿Necesitas factura?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('business_name_field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('nit_field')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('el teclado cambia con el campo activo y edita los datos',
      (tester) async {
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    final business = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    await tester.tap(find.byKey(const ValueKey('billing_key_A')));
    await tester.tap(find.byKey(const ValueKey('billing_keyboard_space')));
    await tester.tap(find.byKey(const ValueKey('billing_key_B')));
    expect(business.controller?.text, 'A B');

    await tester.tap(find.byKey(const ValueKey('billing_keyboard_action')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('billing_keyboard_numeric')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('billing_key_1')));
    await tester.tap(find.byKey(const ValueKey('billing_key_2')));
    await tester.tap(find.byKey(const ValueKey('billing_keyboard_backspace')));
    await tester.tap(find.byKey(const ValueKey('billing_key_3')));

    final nit = tester.widget<TextFormField>(
      find.byKey(const ValueKey('nit_field')),
    );
    expect(nit.controller?.text, '13');
  });

  testWidgets('siguiente exige razón social y limpia el error al escribir',
      (tester) async {
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('billing_keyboard_action')));
    await tester.pump();
    expect(find.text('Ingresa la razón social o nombre'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('billing_keyboard_alpha')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('billing_key_A')));
    await tester.pump();
    expect(find.text('Ingresa la razón social o nombre'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('billing_keyboard_action')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('billing_keyboard_numeric')),
      findsOneWidget,
    );
  });

  testWidgets('acepta símbolos empresariales y respeta el límite de longitud',
      (tester) async {
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('billing_key_&')));
    await tester.tap(find.byKey(const ValueKey('billing_key_-')));
    await tester.tap(find.byKey(const ValueKey('billing_key_.')));
    final business = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    expect(business.controller?.text, '&-.');

    business.controller?.clear();
    for (var index = 0; index < 61; index++) {
      await tester.tap(find.byKey(const ValueKey('billing_key_A')));
    }
    expect(business.controller?.text, hasLength(60));
  });

  testWidgets('respeta la zona segura del carrusel en pantallas grandes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    final formRect = tester.getRect(
      find.byKey(const ValueKey('billing_form_step')),
    );
    final keyRect = tester.getRect(find.byKey(const ValueKey('billing_key_A')));

    expect(formRect.top, greaterThanOrEqualTo(96));
    expect(formRect.bottom, lessThanOrEqualTo(900 - 96));
    expect(formRect.width, greaterThan(680));
    expect(keyRect.height, 56);
  });

  testWidgets('no desborda en resoluciones verticales límite', (tester) async {
    const sizes = [
      Size(800, 600),
      Size(1024, 701),
      Size(1280, 720),
      Size(1280, 800),
      Size(1280, 900),
      Size(1920, 1080),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await _pumpDialog(tester);
      await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('billing_form_submit_button')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'Resolución $size');
      final formRect = tester.getRect(
        find.byKey(const ValueKey('billing_form_step')),
      );
      final safeInset = size.height > 700 ? 96.0 : 16.0;
      expect(
        formRect.top,
        greaterThanOrEqualTo(safeInset - 0.1),
        reason: 'Resolución $size',
      );
      expect(
        formRect.bottom,
        lessThanOrEqualTo(size.height - safeInset + 0.1),
        reason: 'Resolución $size',
      );
    }
  });

  testWidgets('el formulario valida y devuelve los datos recortados',
      (tester) async {
    BillingFlowResult? result;
    await _pumpDialog(tester, onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('billing_form_submit_button')));
    await tester.pump();
    expect(find.text('Ingresa la razón social o nombre'), findsOneWidget);
    expect(find.text('Ingresa el NIT'), findsOneWidget);

    final business = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    final nit = tester.widget<TextFormField>(
      find.byKey(const ValueKey('nit_field')),
    );
    business.controller?.text = ' Empresa SRL ';
    nit.controller?.text = ' 1234567890123 ';

    await tester.tap(find.byKey(const ValueKey('billing_form_submit_button')));
    await tester.pumpAndSettle();
    expect(result?.wantsInvoice, isTrue);
    expect(result?.businessName, 'Empresa SRL');
    expect(result?.nit, '1234567890123');
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ValueChanged<BillingFlowResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showDialog<BillingFlowResult>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BillingFlowDialog(),
            );
            onResult?.call(result);
          },
          child: const Text('Abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
