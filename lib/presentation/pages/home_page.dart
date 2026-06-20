import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/services/audio_service.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../data/product_remote_data_source.dart';
import '../../qr_payment_module/qr_payment_module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'qr_payment_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ProductRemoteDataSource _dataSource;
  Product? _selectedProduct;
  bool _isLoading = true;
  String? _error;
  String _merchantName = 'Mi Tienda';

  @override
  void initState() {
    super.initState();
    final dio = createAuthenticatedDio();
    _dataSource = ProductRemoteDataSource(dio);
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      setState(() { _isLoading = true; _error = null; });

      final product = await _dataSource.getProduct(
        AppConfig.merchantId,
        AppConfig.productId,
      );
      final merchantInfo = await _dataSource.getMerchantInfo(AppConfig.merchantId);

      setState(() {
        _selectedProduct = product;
        _merchantName = merchantInfo['name'] ?? 'Mi Tienda';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el producto.\n${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_selectedProduct == null) return _buildEmpty();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final isTall = constraints.maxHeight > 700;

            if (isWide) {
              return _buildWideLayout();
            }
            return _buildPortraitLayout(isTall: isTall);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout({required bool isTall}) {
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
              // _buildTitle(),
              const SizedBox(height: 8),
              Expanded(
                flex: isTall ? 3 : 2,
                child: _ProductCard(product: _selectedProduct!),
              ),
              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 12),
              // _buildGreetButton(),
              // const SizedBox(height: 12),
              _buildPayButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Izquierda: producto grande
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _ProductCard(product: _selectedProduct!, fill: true),
          ),
        ),
        // Derecha: resumen + botón
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
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
                  const Icon(Icons.coffee, color: AppColors.accent, size: 48),
                  const SizedBox(height: 16),
                  // Text(""),
                  Text(
                    '¿Quieres un ${_selectedProduct!.name}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedProduct!.price} Bs',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 40),
                  // _buildWideRow('Cantidad', '1'),
                  // const SizedBox(height: 8),
                  // _buildWideRow('Precio unitario', '${_selectedProduct!.price} Bs'),
                  // const SizedBox(height: 16),
                  // _buildWideRow('TOTAL', '${_selectedProduct!.price} Bs', isTotal: true),
                  // const SizedBox(height: 12),
                  // _buildGreetButton(),
                  const SizedBox(height: 12),
                  _buildPayButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   '¿un café?',
          //   style: Theme.of(context).textTheme.displaySmall?.copyWith(
          //         color: AppColors.textPrimary,
          //         fontWeight: FontWeight.w800,
          //         fontSize: 42,
          //         letterSpacing: -1,
          //       ),
          // ),
          const SizedBox(height: 4),
          // Text(
          //   _merchantName,
          //   style: const TextStyle(
          //     color: AppColors.textCaption,
          //     fontSize: 14,
          //     letterSpacing: 2,
          //     fontWeight: FontWeight.w500,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildWideRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.accent : AppColors.textPrimary,
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Cargando producto...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 80),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProduct,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'No hay productos disponibles',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final price = _selectedProduct!.price;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESUMEN DEL PEDIDO',
              style: TextStyle(
                color: AppColors.textCaption,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _RowLabel(label: 'Producto', value: _selectedProduct!.name),
            const SizedBox(height: 8),
            const _RowLabel(label: 'Cantidad', value: '1'),
            const SizedBox(height: 8),
            _RowLabel(label: 'Precio unitario', value: '$price Bs'),
            const Divider(color: AppColors.border, height: 24),
            _RowLabel(
              label: 'TOTAL',
              value: '$price Bs',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () => AudioService.playQuestion(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.record_voice_over, size: 24),
        label: const Text(
          'SALUDAR CLIENTE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _goToPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: const Icon(Icons.qr_code, size: 26),
        label: const Text(
          'PAGAR CON QR',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }

  void _goToPayment() {
    final p = _selectedProduct!;
    final dio = createAuthenticatedDio();

    final remote = QrPaymentRemoteDataSourceImpl(dio);
    final cubit = QrPaymentCubit(remoteDataSource: remote);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: QrPaymentPage(
            merchantId: AppConfig.merchantId,
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
              'merchantName': _merchantName,
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
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool fill;
  const _ProductCard({required this.product, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final hasOffer = product.oldPrice != null;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    final stack = Stack(
      fit: StackFit.expand,
      children: [
              Container(color: const Color(0xFF0D0D1A)),
              if (product.urlImage.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    product.urlImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _Placeholder(),
                  ),
                )
              else
                _Placeholder(),
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xEE000000), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 120, bottom: 20, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isWide ? 32 : 26,
                        ),
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          product.description,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isWide ? 16 : 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    if (hasOffer)
                      _Badge(label: 'Oferta', color: const Color(0xFF6B7BF7)),
                    if (hasOffer) const SizedBox(width: 6),
                    _Badge(
                      label: '${product.price} Bs',
                      color: const Color(0xFFFF6B6B),
                    ),
                  ],
                ),
              ),
            ],
          );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: fill
            ? stack
            : AspectRatio(
                aspectRatio: isWide ? 16 / 10 : 4 / 5,
                child: stack,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.fastfood, color: Colors.white24, size: 80),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  const _RowLabel({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.accent : AppColors.textPrimary,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
