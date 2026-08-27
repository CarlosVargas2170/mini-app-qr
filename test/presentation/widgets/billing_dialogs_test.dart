import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/billing_dialogs.dart';

void main() {
  testWidgets('continuar sin factura devuelve una seleccion sin datos',
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
    bool dialogCompleted = false;
    BillingFlowResult? result = const BillingFlowResult.withoutInvoice();
    await _pumpDialog(
      tester,
      onResult: (value) {
        result = value;
        dialogCompleted = true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('billing_close_button')));
    await tester.pumpAndSettle();

    expect(dialogCompleted, isTrue);
    expect(result, isNull);
  });

  testWidgets('cambia al formulario y permite regresar a la consulta',
      (tester) async {
    await _pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('billing_form_step')), findsOneWidget);
    expect(find.text('Datos para la factura'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('business_name_field')),
      'Empresa temporal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('nit_field')),
      '123456',
    );

    await tester.tap(find.byKey(const ValueKey('billing_form_back_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('billing_confirmation_step')),
      findsOneWidget,
    );
    expect(find.text('¿Necesitas factura?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('billing_yes_button')));
    await tester.pumpAndSettle();
    final businessNameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    final nitField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('nit_field')),
    );
    expect(businessNameField.controller?.text, isEmpty);
    expect(nitField.controller?.text, isEmpty);
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

    await tester.enterText(
      find.byKey(const ValueKey('business_name_field')),
      List.filled(61, 'A').join(),
    );
    final businessNameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('business_name_field')),
    );
    expect(businessNameField.controller?.text, hasLength(60));

    await tester.enterText(
      find.byKey(const ValueKey('business_name_field')),
      ' Empresa SRL ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('nit_field')),
      ' 1234567890123 ',
    );
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
