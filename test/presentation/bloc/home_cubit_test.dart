import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/config/app_settings.dart';
import 'package:mini_app_qr/core/config/product_filter_config.dart';
import 'package:mini_app_qr/domain/entities/merchant.dart';
import 'package:mini_app_qr/domain/entities/product.dart';
import 'package:mini_app_qr/domain/repositories/product_repository.dart';
import 'package:mini_app_qr/domain/usecases/get_merchant_info.dart';
import 'package:mini_app_qr/domain/usecases/get_products.dart';
import 'package:mini_app_qr/presentation/bloc/home_cubit.dart';
import 'package:mini_app_qr/presentation/bloc/home_state.dart';

void main() {
  const coffee = Product(
    id: 1,
    merchantId: 53,
    name: 'Cafe',
    description: '',
    price: 10,
    urlImage: '',
  );
  const tea = Product(
    id: 2,
    merchantId: 53,
    name: 'Te',
    description: '',
    price: 5,
    urlImage: '',
  );

  late _FakeProductRepository repository;
  late HomeCubit cubit;

  setUp(() async {
    AppSettings()
      ..merchantIds = [53]
      ..maxCartItemQuantity = 3
      ..customerSessionTimeoutSeconds = 60
      ..productPollingStaleSeconds = 60
      ..filterConfig = ProductFilterConfig(filterMode: 'all');
    repository = _FakeProductRepository([coffee, tea]);
    cubit = HomeCubit(
      getProducts: GetProductsUseCase(repository),
      getMerchant: GetMerchantInfoUseCase(repository),
    );
    await _waitForLoaded(cubit);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('HomeCubit carrito', () {
    test('incrementa sin superar el maximo configurado', () {
      for (var i = 0; i < 5; i++) {
        cubit.incrementProduct(coffee);
      }

      expect(cubit.state.quantityFor(coffee), 3);
      expect(cubit.state.cartTotalItems, 3);
    });

    test('al disminuir la unica unidad elimina la entrada del carrito', () {
      cubit.incrementProduct(coffee);
      cubit.decrementProduct(coffee);
      cubit.decrementProduct(coffee);

      expect(cubit.state.quantityFor(coffee), 0);
      expect(cubit.state.cartQuantities, isEmpty);
      expect(cubit.state.cartProducts, isEmpty);
    });

    test('vaciar carrito elimina todas las selecciones', () {
      cubit.incrementProduct(coffee);
      cubit.incrementProduct(tea);

      cubit.clearCart();

      expect(cubit.state.cartQuantities, isEmpty);
      expect(cubit.state.cartTotal, 0);
    });

    test('mostrar el GIF inicia una sesion nueva con carrito vacio', () async {
      cubit.incrementProduct(coffee);

      await cubit.showAttract();

      expect(cubit.state.displayMode, DisplayMode.attract);
      expect(cubit.state.cartQuantities, isEmpty);
    });

    testWidgets('pausa el timeout durante el QR y lo reanuda al volver',
        (tester) async {
      AppSettings().customerSessionTimeoutSeconds = 1;
      await cubit.showProduct();

      cubit.pauseCustomerSessionTimeout();
      await tester.pump(const Duration(seconds: 2));
      expect(cubit.state.displayMode, DisplayMode.product);

      cubit.resumeCustomerSessionTimeout();
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.displayMode, DisplayMode.attract);
    });
  });

  group('HomeCubit sincronizacion con polling', () {
    test('conserva cantidades cuando los productos siguen disponibles',
        () async {
      cubit.incrementProduct(coffee);
      cubit.incrementProduct(coffee);
      repository.products = [coffee, tea];

      await cubit.forcePoll();

      expect(cubit.state.quantityFor(coffee), 2);
      expect(cubit.state.cartSyncRevision, 0);
    });

    test('retira del carrito un producto que desaparecio', () async {
      cubit.incrementProduct(coffee);
      cubit.incrementProduct(tea);
      repository.products = [coffee];

      await cubit.forcePoll();

      expect(cubit.state.quantityFor(coffee), 1);
      expect(cubit.state.quantityFor(tea), 0);
      expect(cubit.state.cartSyncRevision, 1);
      expect(cubit.state.cartSyncMessage, contains('Te'));
      expect(cubit.state.cartSyncMessage, contains('retirado'));
    });

    test('actualiza el precio y recalcula el total conservando cantidad',
        () async {
      cubit.incrementProduct(coffee);
      cubit.incrementProduct(coffee);
      repository.products = [coffee.copyWith(price: 12), tea];

      await cubit.forcePoll();

      expect(cubit.state.quantityFor(coffee), 2);
      expect(cubit.state.cartTotal, 24);
      expect(cubit.state.cartSyncRevision, 1);
      expect(cubit.state.cartSyncMessage, contains('precio'));
    });

    test('tolera un catalogo vacio retirando todo el carrito', () async {
      cubit.incrementProduct(coffee);
      repository.products = [];

      await cubit.forcePoll();

      expect(cubit.state.products, isEmpty);
      expect(cubit.state.cartQuantities, isEmpty);
      expect(cubit.state.currentProduct, isNull);
    });
  });
}

Future<void> _waitForLoaded(HomeCubit cubit) async {
  if (cubit.state.status == HomeStatus.loaded) return;
  await cubit.stream
      .firstWhere((state) => state.status == HomeStatus.loaded)
      .timeout(const Duration(seconds: 2));
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this.products);

  List<Product> products;

  @override
  Future<Merchant> getMerchantInfo(int merchantId) async =>
      Merchant(id: merchantId, name: 'Merchant $merchantId');

  @override
  Future<Product> getProduct(int merchantId, int productId) async => products
      .firstWhere((product) =>
          product.merchantId == merchantId && product.id == productId);

  @override
  Future<List<Product>> getProducts(int merchantId) async =>
      List<Product>.from(products);
}
