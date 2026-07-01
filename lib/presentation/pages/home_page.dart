import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/ui_command_bus.dart';
import '../../core/ui/themes/app_colors.dart';
import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';
import '../bloc/qr_payment_cubit.dart';
import '../widgets/attract_gif_player.dart';
import '../widgets/audio_overlay_wrapper.dart';
import '../widgets/audio_overlay_widget.dart';
import '../widgets/product_carousel.dart';
import 'qr_payment_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl.homeCubit(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  StreamSubscription<UiCommand>? _commandSub;
  QrPaymentCubit? _activePaymentCubit;

  @override
  void initState() {
    super.initState();
    _commandSub = UiCommandBus.stream.listen(_onCommand);
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    _activePaymentCubit?.close();
    _activePaymentCubit = null;
    super.dispose();
  }

  void _onCommand(UiCommand cmd) async {
    debugPrint('[HomePage] UiCommand recibido: $cmd');
    if (!mounted) {
      debugPrint('[HomePage] Comando ignorado: widget no montado');
      return;
    }
    final cubit = context.read<HomeCubit>();
    switch (cmd) {
      case UiCommand.showAttract:
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showAttract();
        break;
      case UiCommand.showProduct:
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showProduct();
        break;
      case UiCommand.cancelPayment:
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showProductWithTimeout(const Duration(seconds: 5));
        break;
      case UiCommand.showIdle:
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showIdle();
        break;
      case UiCommand.reloadProduct:
        debugPrint('[HomePage] Recargando productos por cambio de config...');
        await cubit.load();
        break;
    }
  }

  void _cancelActivePayment() {
    _activePaymentCubit?.cancel();
    _activePaymentCubit = null;
  }

  void _popPaymentIfOpen() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AudioOverlayWrapper(
      position: AudioOverlayPosition.bottom,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocConsumer<HomeCubit, HomeState>(
            listener: (context, state) {},
            builder: (context, state) {
              debugPrint(
                  '[HomePage] rebuild -> status=${state.status}, displayMode=${state.displayMode}');
              return switch (state.displayMode) {
                DisplayMode.attract => const AttractGifPlayer(),
                DisplayMode.idle => _buildIdle(),
                DisplayMode.product => switch (state.status) {
                    HomeStatus.initial || HomeStatus.loading => _buildLoading(),
                    HomeStatus.error => _buildError(state.errorMessage, context),
                    HomeStatus.loaded => _buildContent(context, state),
                  },
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Text(
          'Esperando...',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final isTall = constraints.maxHeight > 700;

        if (isWide) {
          return _buildWideLayout(context, state);
        }
        return _buildPortraitLayout(context, state, isTall: isTall);
      },
    );
  }

  Widget _buildPortraitLayout(BuildContext context, HomeState state,
      {required bool isTall}) {
    final product = state.currentProduct!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Expanded(
                flex: isTall ? 3 : 2,
                child: ProductCarousel(
                  products: state.products,
                  currentIndex: state.currentIndex,
                ),
              ),
              const SizedBox(height: 16),
              _buildProductInfo(product),
              const SizedBox(height: 12),
              _buildPayButton(context, state),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, HomeState state) {
    final product = state.currentProduct!;
    return Padding(
      padding:
          const EdgeInsets.only(left: 200, top: 96, right: 96, bottom: 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: ProductCarousel(
              products: state.products,
              currentIndex: state.currentIndex,
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.coffee,
                        color: AppColors.accent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      '¿Quieres un ${product.name}?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${product.price} Bs',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 40),
                    const SizedBox(height: 12),
                    _buildPayButton(context, state),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo(dynamic product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            product.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${product.price} Bs',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Cargando productos...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String? errorMessage, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 80),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Ocurrió un error',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<HomeCubit>().load(),
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton(BuildContext context, HomeState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: () => _goToPayment(context, state),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: const Icon(Icons.qr_code, size: 28),
        label: const Text(
          'PAGAR CON QR',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }

  void _goToPayment(BuildContext context, HomeState state) {
    final p = state.currentProduct!;

    _activePaymentCubit?.close();

    final cubit = sl.qrPaymentCubit();
    _activePaymentCubit = cubit;

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: QrPaymentPage(
            merchantId: AppSettings().merchantId,
            amount: p.price,
            customerName: 'Cliente',
            cartItems: [
              {
                'name': p.name,
                'quantity': 1,
                'price': p.price,
              },
            ],
            menuData: {
              'merchantName': state.merchantName,
              'categories': [
                {
                  'products': [
                    {
                      'id': p.id,
                      'name': p.name,
                      'price': p.price,
                      'urlImage': p.urlImage,
                      'description': p.description,
                    },
                  ],
                },
              ],
            },
            onSuccess: () {
              _activePaymentCubit?.cancel();
              _activePaymentCubit = null;
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              if (mounted) {
                context.read<HomeCubit>().showAttract();
              }
            },
          ),
        ),
      ),
    )
        .then((_) {
      _activePaymentCubit?.cancel();
      _activePaymentCubit = null;
    });
  }
}
