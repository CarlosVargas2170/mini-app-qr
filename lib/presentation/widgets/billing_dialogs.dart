import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class BillingFlowDialog extends StatefulWidget {
  const BillingFlowDialog({super.key});

  @override
  State<BillingFlowDialog> createState() => _BillingFlowDialogState();
}

class _BillingFlowDialogState extends State<BillingFlowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _nitController = TextEditingController();
  bool _showForm = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _nitController.dispose();
    super.dispose();
  }

  void _showBillingForm() => setState(() => _showForm = true);

  void _showConfirmation() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();
    _businessNameController.clear();
    _nitController.clear();
    setState(() => _showForm = false);
  }

  void _continueWithoutInvoice() {
    Navigator.of(context).pop(const BillingFlowResult.withoutInvoice());
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      BillingFlowResult.withInvoice(
        nit: _nitController.text.trim(),
        businessName: _businessNameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 680,
        height: 510,
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
        decoration: BoxDecoration(
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.textLabel,
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Text(
                  'FACTURA',
                  style: TextStyle(
                    color: AppColors.textLabel,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('billing_close_button'),
                  tooltip: 'Volver al carrusel',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 34),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    backgroundColor: AppColors.surfaceAlt,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _showForm ? _buildFormStep() : _buildConfirmationStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      key: const ValueKey('billing_confirmation_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(
          Icons.request_quote_rounded,
          color: AppColors.textPrimary,
          size: 58,
        ),
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
                onTap: _continueWithoutInvoice,
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
    );
  }

  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('billing_form_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos para la factura',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('business_name_field'),
            controller: _businessNameController,
            autofocus: true,
            maxLength: 60,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
            cursorHeight: 28,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Razón social / Nombre',
              // hintText: 'Ej.: Nombre',
              prefixIcon: Icon(Icons.business_rounded, size: 28),
              prefixIconConstraints: BoxConstraints(minWidth: 62),
              border: OutlineInputBorder(),
              counterText: '',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 23),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ingresa la razón social o nombre'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('nit_field'),
            controller: _nitController,
            maxLength: 30,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
            cursorHeight: 28,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'NIT',
              // hintText: 'Ej.: 1234567890123',
              prefixIcon: Icon(Icons.badge_outlined, size: 28),
              prefixIconConstraints: BoxConstraints(minWidth: 62),
              border: OutlineInputBorder(),
              counterText: '',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 23),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Ingresa el NIT' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                width: 180,
                height: 60,
                child: OutlinedButton.icon(
                  key: const ValueKey('billing_form_back_button'),
                  onPressed: _showConfirmation,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('ATRÁS'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    key: const ValueKey('billing_form_submit_button'),
                    onPressed: _submit,
                    icon: const Icon(Icons.qr_code_rounded),
                    label: const Text(
                      'IR AL PAGO',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
