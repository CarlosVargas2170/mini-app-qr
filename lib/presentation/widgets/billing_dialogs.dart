import 'package:flutter/material.dart';

import '../../core/ui/themes/app_colors.dart';

class BillingFlowResult {
  final String? nit;
  final String? businessName;

  const BillingFlowResult.withoutInvoice()
      : nit = null,
        businessName = null;

  const BillingFlowResult.withInvoice({
    required String this.nit,
    required String this.businessName,
  });

  bool get wantsInvoice => nit != null && businessName != null;
}

enum _BillingField { businessName, nit }

class BillingFlowDialog extends StatefulWidget {
  const BillingFlowDialog({super.key});

  @override
  State<BillingFlowDialog> createState() => _BillingFlowDialogState();
}

class _BillingFlowDialogState extends State<BillingFlowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _nitController = TextEditingController();
  final _businessFocus = FocusNode();
  final _nitFocus = FocusNode();
  bool _showForm = false;
  bool _hasAttemptedSubmit = false;
  _BillingField _activeField = _BillingField.businessName;

  @override
  void dispose() {
    _businessController.dispose();
    _nitController.dispose();
    _businessFocus.dispose();
    _nitFocus.dispose();
    super.dispose();
  }

  void _showBillingForm() {
    setState(() {
      _showForm = true;
      _hasAttemptedSubmit = false;
      _activeField = _BillingField.businessName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _businessFocus.requestFocus();
    });
  }

  void _showConfirmation() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();
    _businessController.clear();
    _nitController.clear();
    setState(() {
      _showForm = false;
      _hasAttemptedSubmit = false;
    });
  }

  void _activate(_BillingField field) {
    setState(() => _activeField = field);
    (field == _BillingField.businessName ? _businessFocus : _nitFocus)
        .requestFocus();
  }

  TextEditingController get _activeController =>
      _activeField == _BillingField.businessName
          ? _businessController
          : _nitController;

  void _insert(String value) {
    final controller = _activeController;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final next = controller.text.replaceRange(start, end, value);
    final limit = _activeField == _BillingField.businessName ? 60 : 30;
    if (next.length > limit) return;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    if (_hasAttemptedSubmit) _formKey.currentState?.validate();
  }

  void _backspace() {
    final controller = _activeController;
    if (controller.text.isEmpty) return;
    final selection = controller.selection;
    var start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    if (start == end) {
      if (start == 0) return;
      start--;
    }
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
    if (_hasAttemptedSubmit) _formKey.currentState?.validate();
  }

  void _goToNit() {
    if (_businessController.text.trim().isEmpty) {
      _hasAttemptedSubmit = true;
      _formKey.currentState?.validate();
      return;
    }
    _activate(_BillingField.nit);
  }

  void _submit() {
    _hasAttemptedSubmit = true;
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      BillingFlowResult.withInvoice(
        nit: _nitController.text.trim(),
        businessName: _businessController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final usesWideCarouselLayout = size.width > 700;
    final verticalInset = size.height > 700 ? 96.0 : 16.0;
    final availableSafeHeight = size.height - (verticalInset * 2);
    final expanded = availableSafeHeight >= 680 && size.width >= 1000;
    final leftInset = usesWideCarouselLayout ? 200.0 : 24.0;
    final rightInset = usesWideCarouselLayout ? 96.0 : 24.0;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: EdgeInsets.fromLTRB(
        leftInset,
        _showForm ? verticalInset : 24,
        rightInset,
        _showForm ? verticalInset : 24,
      ),
      backgroundColor: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _showForm
            ? _buildFormViewport(expanded: expanded)
            : _buildConfirmation(),
      ),
    );
  }

  Widget _buildFormViewport({required bool expanded}) {
    final targetWidth = expanded ? 900.0 : 760.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: targetWidth,
              child: _buildFormLayout(expanded: expanded),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmation() {
    return Container(
      key: const ValueKey('billing_confirmation_step'),
      width: 680,
      height: 510,
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const Spacer(),
          const Icon(Icons.request_quote_rounded,
              color: AppColors.textPrimary, size: 58),
          const SizedBox(height: 12),
          const Text(
            '¿Necesitas factura?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _BillingOptionCard(
                  key: const ValueKey('billing_no_button'),
                  icon: Icons.close_rounded,
                  title: 'SIN FACTURA',
                  onTap: () => Navigator.of(context)
                      .pop(const BillingFlowResult.withoutInvoice()),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _BillingOptionCard(
                  key: const ValueKey('billing_yes_button'),
                  icon: Icons.receipt_long_rounded,
                  title: 'CON FACTURA',
                  isPrimary: true,
                  onTap: _showBillingForm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormLayout({required bool expanded}) {
    final buttonHeight = expanded ? 64.0 : 52.0;

    return ConstrainedBox(
      key: const ValueKey('billing_form_step'),
      constraints: BoxConstraints(maxWidth: expanded ? 900 : 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              expanded ? 30 : 22,
              expanded ? 20 : 14,
              expanded ? 30 : 22,
              expanded ? 24 : 18,
            ),
            decoration: _decoration(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(
                    title: 'DATOS PARA LA FACTURA',
                    expanded: expanded,
                  ),
                  SizedBox(height: expanded ? 16 : 10),
                  _field(
                    key: const ValueKey('business_name_field'),
                    controller: _businessController,
                    focusNode: _businessFocus,
                    label: 'Razón social / Nombre',
                    icon: Icons.business_rounded,
                    maxLength: 60,
                    field: _BillingField.businessName,
                    expanded: expanded,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa la razón social o nombre'
                        : null,
                  ),
                  SizedBox(height: expanded ? 12 : 8),
                  _field(
                    key: const ValueKey('nit_field'),
                    controller: _nitController,
                    focusNode: _nitFocus,
                    label: 'NIT',
                    icon: Icons.badge_outlined,
                    maxLength: 30,
                    field: _BillingField.nit,
                    expanded: expanded,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa el NIT'
                        : null,
                  ),
                  SizedBox(height: expanded ? 18 : 12),
                  Row(
                    children: [
                      SizedBox(
                        width: expanded ? 210 : 170,
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          key: const ValueKey('billing_form_back_button'),
                          onPressed: _showConfirmation,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('ATRÁS'),
                        ),
                      ),
                      SizedBox(width: expanded ? 18 : 12),
                      Expanded(
                        child: SizedBox(
                          height: buttonHeight,
                          child: FilledButton.icon(
                            key: const ValueKey('billing_form_submit_button'),
                            onPressed: _submit,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('IR AL PAGO'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _BillingKeyboard(
            mode: _activeField,
            expanded: expanded,
            onCharacter: _insert,
            onBackspace: _backspace,
            onAction:
                _activeField == _BillingField.businessName ? _goToNit : _submit,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required int maxLength,
    required _BillingField field,
    required bool expanded,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      showCursor: true,
      enableInteractiveSelection: false,
      maxLength: maxLength,
      style: TextStyle(
        fontSize: expanded ? 26 : 21,
        fontWeight: FontWeight.w500,
      ),
      cursorHeight: expanded ? 31 : 25,
      onTap: () => _activate(field),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: expanded ? 31 : 26),
        prefixIconConstraints: BoxConstraints(minWidth: expanded ? 68 : 56),
        border: const OutlineInputBorder(),
        counterText: '',
        contentPadding: EdgeInsets.symmetric(
          horizontal: expanded ? 22 : 18,
          vertical: expanded ? 21 : 17,
        ),
        errorStyle: TextStyle(fontSize: expanded ? 14 : 12, height: 0.8),
        helperText: ' ',
        helperStyle: TextStyle(fontSize: expanded ? 14 : 12, height: 0.8),
      ),
      validator: validator,
    );
  }

  Widget _header({String title = 'FACTURA', bool expanded = false}) {
    return Row(
      children: [
        Icon(
          Icons.receipt_long_rounded,
          color: AppColors.textLabel,
          size: expanded ? 31 : 25,
        ),
        SizedBox(width: expanded ? 14 : 10),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textLabel,
            fontSize: expanded ? 18 : 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        IconButton(
          key: const ValueKey('billing_close_button'),
          tooltip: 'Volver al carrusel',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, size: expanded ? 36 : 30),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            backgroundColor: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderMuted),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      );
}

class _BillingKeyboard extends StatelessWidget {
  static const _letters = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '.', '-', '&'],
  ];
  static const _numbers = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  final _BillingField mode;
  final bool expanded;
  final ValueChanged<String> onCharacter;
  final VoidCallback onBackspace;
  final VoidCallback onAction;

  const _BillingKeyboard({
    required this.mode,
    required this.expanded,
    required this.onCharacter,
    required this.onBackspace,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final alphabetic = mode == _BillingField.businessName;
    final rows = alphabetic ? _letters : _numbers;
    return Container(
      key: ValueKey(
        alphabetic ? 'billing_keyboard_alpha' : 'billing_keyboard_numeric',
      ),
      padding: EdgeInsets.all(expanded ? 14 : 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows) ...[
            _characterRow(row),
            SizedBox(height: expanded ? 7 : 5),
          ],
          if (alphabetic) _alphabetActions() else _numberActions(),
        ],
      ),
    );
  }

  Widget _characterRow(List<String> values) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: _KeyboardKey(
                key: ValueKey('billing_key_${values[i]}'),
                label: values[i],
                expanded: expanded,
                onTap: () => onCharacter(values[i]),
              ),
            ),
            if (i < values.length - 1) SizedBox(width: expanded ? 7 : 5),
          ],
        ],
      );

  Widget _alphabetActions() => Row(
        children: [
          Expanded(
            flex: 5,
            child: _KeyboardKey(
              key: const ValueKey('billing_keyboard_space'),
              label: 'ESPACIO',
              expanded: expanded,
              onTap: () => onCharacter(' '),
            ),
          ),
          SizedBox(width: expanded ? 7 : 5),
          Expanded(
            flex: 2,
            child: _KeyboardKey(
              key: const ValueKey('billing_keyboard_backspace'),
              icon: Icons.backspace_outlined,
              expanded: expanded,
              onTap: onBackspace,
            ),
          ),
          SizedBox(width: expanded ? 7 : 5),
          Expanded(
            flex: 3,
            child: _KeyboardKey(
              key: const ValueKey('billing_keyboard_action'),
              label: 'SIGUIENTE',
              primary: true,
              expanded: expanded,
              onTap: onAction,
            ),
          ),
        ],
      );

  Widget _numberActions() => Row(
        children: [
          Expanded(
            child: _KeyboardKey(
              key: const ValueKey('billing_keyboard_backspace'),
              icon: Icons.backspace_outlined,
              expanded: expanded,
              onTap: onBackspace,
            ),
          ),
          SizedBox(width: expanded ? 7 : 5),
          Expanded(
            child: _KeyboardKey(
              key: const ValueKey('billing_key_0'),
              label: '0',
              expanded: expanded,
              onTap: () => onCharacter('0'),
            ),
          ),
          SizedBox(width: expanded ? 7 : 5),
          Expanded(
            child: _KeyboardKey(
              key: const ValueKey('billing_keyboard_action'),
              label: 'LISTO',
              primary: true,
              expanded: expanded,
              onTap: onAction,
            ),
          ),
        ],
      );
}

class _KeyboardKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool primary;
  final bool expanded;
  final VoidCallback onTap;

  const _KeyboardKey({
    super.key,
    this.label,
    this.icon,
    this.primary = false,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: expanded ? 56 : 43,
      child: Material(
        color: primary ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: expanded ? 28 : 23,
                    color: AppColors.textPrimary,
                  )
                : FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        label!,
                        style: TextStyle(
                          color: primary
                              ? AppColors.background
                              : AppColors.textPrimary,
                          fontSize: expanded ? 21 : 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BillingOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BillingOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.accent : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary ? AppColors.accent : AppColors.borderMuted,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isPrimary ? AppColors.background : AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isPrimary
                        ? AppColors.background
                        : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
