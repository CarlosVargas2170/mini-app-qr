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
import '../widgets/billing_dialogs.dart';
import '../widgets/floating_cart.dart';
import '../widgets/product_carousel.dart';
import '../widgets/product_quantity_selector.dart';
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
  BuildContext? _clearCartDialogContext;
  int _lastCartSyncRevision = 0;
  bool _isPreparingPayment = false;

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
      case ShowAttract(:final gifAsset):
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showAttract(gifAsset: gifAsset);
        break;
      case ShowProduct():
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showProduct();
        break;
      case CancelPayment():
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showProductWithTimeout(const Duration(seconds: 5));
        break;
      case ShowIdle():
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showIdle();
        break;
      case ReloadProduct():
        debugPrint('[HomePage] Recargando productos por cambio de config...');
        await cubit.load();
        break;
      case ShowProductResetCarousel():
        _cancelActivePayment();
        _popPaymentIfOpen();
        await cubit.showProductResetCarousel();
        break;
      // ── Product polling ──
      case ForceProductPoll():
        await cubit.forcePoll();
        break;
      case GetProductPollingStatus():
        // No-op: el estado se consulta via HTTP (GET /products/polling/status)
        break;
      // Polling manual del QR: lo gestiona QrPaymentPage al navegar.
      case StartPaymentPolling():
      case StopPaymentPolling():
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
            listener: (context, state) {
              if (state.displayMode != DisplayMode.product) {
                _dismissClearCartDialog();
                // Una nueva sesion no debe mostrar avisos de la anterior.
                _lastCartSyncRevision = state.cartSyncRevision;
              }
              _showCartSyncNoticeIfNeeded(context, state);
            },
            builder: (context, state) {
              debugPrint(
                  '[HomePage] rebuild -> status=${state.status}, displayMode=${state.displayMode}');
              return switch (state.displayMode) {
                DisplayMode.attract =>
                  AttractGifPlayer(assetPath: state.attractGifAsset),
                DisplayMode.idle => _buildIdle(),
                DisplayMode.product => switch (state.status) {
                    HomeStatus.initial || HomeStatus.loading => _buildLoading(),
                    HomeStatus.error =>
                      _buildError(state.errorMessage, context),
                    HomeStatus.loaded => state.products.isEmpty
                        ? _buildNoProducts()
                        : _buildContent(context, state),
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

  Widget _buildNoProducts() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No hay productos disponibles en este momento.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 20),
        ),
      ),
    );
  }

  void _showCartSyncNoticeIfNeeded(
    BuildContext context,
    HomeState state,
  ) {
    if (state.displayMode != DisplayMode.product ||
        _activePaymentCubit != null ||
        state.cartSyncRevision <= _lastCartSyncRevision ||
        state.cartSyncMessage == null) {
      return;
    }

    _lastCartSyncRevision = state.cartSyncRevision;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(state.cartSyncMessage!),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildPortraitLayout(BuildContext context, HomeState state,
      {required bool isTall}) {
    final product = state.currentProduct!;
    return Stack(
      children: [
        SingleChildScrollView(
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
              _buildQuantitySelector(context, state),
              const SizedBox(height: 24),
              _buildPayButton(context, state),
              const SizedBox(height: 96),
            ],
          ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: _buildFloatingCart(context, state),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, HomeState state) {
    final product = state.currentProduct!;
    return Padding(
      padding: const EdgeInsets.only(left: 200, top: 96, right: 96, bottom: 96),
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const SizedBox(height: 56),
                    const Icon(Icons.coffee, color: AppColors.accent, size: 48),
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
                    _buildQuantitySelector(context, state),
                    const SizedBox(height: 24),
                    _buildPayButton(context, state),
                    const SizedBox(height: 68),
                      ],
                    ),
                    const Positioned(
                      top: -68,
                      left: 0,
                      right: 0,
                      child: Center(child: _MegacenterLogo()),
                    ),
                    const Positioned(
                      left: 0,
                      bottom: -4,
                      child: _NexusTechnologySignature(),
                    ),
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: _buildFloatingCart(context, state),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(BuildContext context, HomeState state) {
    final product = state.currentProduct!;
    final cubit = context.read<HomeCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ProductQuantitySelector(
        quantity: state.quantityFor(product),
        maxQuantity: AppSettings().maxCartItemQuantity,
        onIncrement: () => cubit.incrementProduct(product),
        onDecrement: () => cubit.decrementProduct(product),
      ),
    );
  }

  Widget _buildFloatingCart(BuildContext context, HomeState state) {
    final cubit = context.read<HomeCubit>();
    return FloatingCart(
      products: state.cartProducts,
      quantityFor: state.quantityFor,
      totalItems: state.cartTotalItems,
      totalAmount: state.cartTotal,
      maxItemQuantity: AppSettings().maxCartItemQuantity,
      onIncrement: cubit.incrementProduct,
      onDecrement: cubit.decrementProduct,
      onRemove: cubit.removeProductFromCart,
      onClear: () => _confirmClearCart(context),
      onInteraction: cubit.registerCartInteraction,
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
    final hasCartItems = state.cartTotalItems > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: hasCartItems ? () => _goToPayment(context, state) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: const Icon(Icons.qr_code, size: 28),
        label: const Text(
          'PAGAR PEDIDO CON QR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearCart(BuildContext context) async {
    context.read<HomeCubit>().registerCartInteraction();
    final shouldClear = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _clearCartDialogContext = dialogContext;
        return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
        actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        title: const Text(
          '¿Vaciar el carrito?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: 480,
          child: Text(
            'Se eliminarán todos los productos seleccionados.',
            style: TextStyle(fontSize: 18),
          ),
        ),
        actions: [
          SizedBox(
            width: 160,
            height: 58,
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCELAR', style: TextStyle(fontSize: 17)),
            ),
          ),
          SizedBox(
            width: 160,
            height: 58,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('VACIAR', style: TextStyle(fontSize: 17)),
            ),
          ),
        ],
        );
      },
    );

    _clearCartDialogContext = null;

    if (shouldClear == true && mounted) {
      this.context.read<HomeCubit>().clearCart();
    }
  }

  void _dismissClearCartDialog() {
    final dialogContext = _clearCartDialogContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    _clearCartDialogContext = null;
    Navigator.of(dialogContext).pop(false);
  }

  Future<void> _goToPayment(BuildContext context, HomeState state) async {
    if (_isPreparingPayment || _activePaymentCubit != null) return;
    if (state.cartProducts.isEmpty) return;

    _isPreparingPayment = true;
    final homeCubit = context.read<HomeCubit>();
    final previousSyncRevision = homeCubit.state.cartSyncRevision;
    homeCubit.pauseCustomerSessionTimeout();

    // La orden debe salir del catalogo mas reciente. El polling reconcilia el
    // carrito por merchant/producto antes de crear el snapshot de pago.
    await homeCubit.forcePoll();
    if (!mounted) return;

    final refreshedState = homeCubit.state;
    final cartWasAdjusted =
        refreshedState.cartSyncRevision > previousSyncRevision;
    if (refreshedState.displayMode != DisplayMode.product) {
      _isPreparingPayment = false;
      return;
    }
    if (cartWasAdjusted || refreshedState.cartProducts.isEmpty) {
      _isPreparingPayment = false;
      homeCubit.resumeCustomerSessionTimeout();
      _showCartSyncNoticeIfNeeded(this.context, refreshedState);
      return;
    }

    final products = List.of(refreshedState.cartProducts);
    final firstProduct = products.first;

    final billingDetails = refreshedState
            .merchantUsesBilling(firstProduct.merchantId)
        ? await _collectBillingDetails()
        : const BillingFlowResult.withoutInvoice();
    if (!mounted) return;
    if (billingDetails == null) {
      _isPreparingPayment = false;
      homeCubit.resumeCustomerSessionTimeout();
      return;
    }

    // Snapshot del carrito: orden y QR salen de la misma seleccion.
    final cartItems = products
        .map<Map<String, dynamic>>((product) => {
              'id': product.id,
              'name': product.name,
              'quantity': refreshedState.quantityFor(product),
              'price': product.price,
            })
        .toList(growable: false);
    final menuProducts = products
        .map<Map<String, dynamic>>((product) => {
              'id': product.id,
              'name': product.name,
              'price': product.price,
              'urlImage': product.urlImage,
              'description': product.description,
            })
        .toList(growable: false);
    final amount = products.fold<double>(
      0,
      (total, product) =>
          total + product.price * refreshedState.quantityFor(product),
    );

    _activePaymentCubit?.close();
    final cubit = sl.qrPaymentCubit();
    _activePaymentCubit = cubit;
    _isPreparingPayment = false;

    Navigator.of(this.context)
        .push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: QrPaymentPage(
            merchantId: firstProduct.merchantId,
            productId: firstProduct.id,
            amount: amount,
            nit: billingDetails.nit,
            businessName: billingDetails.businessName,
            cartItems: cartItems,
            menuData: {
              'merchantName':
                  refreshedState.getMerchantNameForProduct(firstProduct),
              'categories': [
                {
                  'products': menuProducts,
                },
              ],
            },
            onSuccess: () {
              // No llamar cancel(): sobrescribiría success → cancelled en la UI.
              _activePaymentCubit?.stopPollingOnly();
              final cubit = _activePaymentCubit;
              _activePaymentCubit = null;
              if (mounted && Navigator.of(this.context).canPop()) {
                Navigator.of(this.context).pop();
              }
              cubit?.close();
              if (mounted) {
                this.context.read<HomeCubit>().showAttract();
              }
            },
          ),
        ),
      ),
    )
        .then((_) {
      // Al salir de la página (back / pop): detener sin forzar UI cancelada.
      _activePaymentCubit?.stopPollingOnly();
      _activePaymentCubit?.close();
      _activePaymentCubit = null;
      if (!mounted) return;
      final homeCubit = this.context.read<HomeCubit>();
      homeCubit.resumeCustomerSessionTimeout();
      _showCartSyncNoticeIfNeeded(this.context, homeCubit.state);
    });
  }

  Future<BillingFlowResult?> _collectBillingDetails() {
    return showDialog<BillingFlowResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BillingFlowDialog(),
    );
  }
}

class _MegacenterLogo extends StatelessWidget {
  const _MegacenterLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 144,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderLight, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/logo_megacenter.jpg',
          fit: BoxFit.contain,
          semanticLabel: 'Logo Megacenter',
        ),
      ),
    );
  }
}

class _NexusTechnologySignature extends StatelessWidget {
  const _NexusTechnologySignature();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            'Tecnología de',
            style: TextStyle(
              color: AppColors.textCaption,
              fontSize: 11,
              letterSpacing: .4,
            ),
          ),
        ),
        SizedBox(
          width: 150,
          height: 58,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 210,
              maxWidth: 210,
              minHeight: 210,
              maxHeight: 210,
              child: Image(
                image: AssetImage(
                  'assets/images/logo_nexus_patio_tech.png',
                ),
                fit: BoxFit.contain,
                semanticLabel: 'Logo Nexus Patio Tech',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
