import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/domain/entities/merchant.dart';
import 'package:mini_app_qr/domain/entities/order.dart';
import 'package:mini_app_qr/domain/entities/order_status.dart';
import 'package:mini_app_qr/domain/entities/product.dart';
import 'package:mini_app_qr/domain/repositories/product_repository.dart';
import 'package:mini_app_qr/domain/repositories/qr_payment_repository.dart';
import 'package:mini_app_qr/domain/usecases/complete_order.dart';
import 'package:mini_app_qr/domain/usecases/get_payment_status.dart';
import 'package:mini_app_qr/domain/usecases/get_product.dart';
import 'package:mini_app_qr/domain/usecases/start_qr_payment.dart';
import 'package:mini_app_qr/domain/usecases/update_order.dart';
import 'package:mini_app_qr/presentation/bloc/qr_payment_cubit.dart';
import 'package:mini_app_qr/presentation/bloc/qr_payment_state.dart';

void main() {
  const coffee = Product(
    id: 1,
    merchantId: 53,
    name: 'Cafe actualizado',
    description: '',
    price: 12,
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

  late _FakeQrPaymentRepository paymentRepository;
  late _FakeProductRepository productRepository;
  late QrPaymentCubit cubit;

  setUp(() {
    paymentRepository = _FakeQrPaymentRepository();
    productRepository = _FakeProductRepository([coffee, tea]);
    cubit = QrPaymentCubit(
      startQrPayment: StartQrPaymentUseCase(paymentRepository),
      getPaymentStatus: GetPaymentStatusUseCase(paymentRepository),
      updateOrder: UpdateOrderUseCase(paymentRepository),
      completeOrder: CompleteOrderUseCase(paymentRepository),
      getProduct: GetProductUseCase(productRepository),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('valida todos los productos y genera QR con el total actualizado',
      () async {
    await cubit.startQrPayment(
      merchantId: 53,
      productId: 1,
      customerName: 'Robot',
      phoneNumber: '',
      whereEat: 'dineIn',
      amount: 35,
      autoPoll: false,
      cartItems: const [
        {'id': 1, 'name': 'Cafe', 'quantity': 2, 'price': 10.0},
        {'id': 2, 'name': 'Te', 'quantity': 3, 'price': 5.0},
      ],
      menuData: const {
        'categories': [
          {
            'products': [
              {'id': 1, 'name': 'Cafe', 'price': 10.0},
              {'id': 2, 'name': 'Te', 'price': 5.0},
            ],
          },
        ],
      },
    );

    expect(cubit.state.status, QrPaymentStatus.qrReady);
    expect(cubit.state.amount, 39);
    expect(paymentRepository.startCalls, 1);
    expect(paymentRepository.lastAmount, 39);
    expect(paymentRepository.lastCartItems, hasLength(2));
    expect(paymentRepository.lastCartItems![0]['quantity'], 2);
    expect(paymentRepository.lastCartItems![0]['price'], 12);
  });

  test('no crea orden si uno de los productos ya no esta disponible',
      () async {
    productRepository.products = [coffee];

    await cubit.startQrPayment(
      merchantId: 53,
      productId: 1,
      customerName: 'Robot',
      phoneNumber: '',
      whereEat: 'dineIn',
      amount: 15,
      autoPoll: false,
      cartItems: const [
        {'id': 1, 'name': 'Cafe', 'quantity': 1, 'price': 10.0},
        {'id': 2, 'name': 'Te', 'quantity': 1, 'price': 5.0},
      ],
      menuData: const {
        'categories': [
          {
            'products': [
              {'id': 1, 'name': 'Cafe', 'price': 10.0},
              {'id': 2, 'name': 'Te', 'price': 5.0},
            ],
          },
        ],
      },
    );

    expect(cubit.state.status, QrPaymentStatus.failed);
    expect(cubit.state.errorMessage, contains('Te'));
    expect(cubit.state.errorMessage, contains('no está disponible'));
    expect(paymentRepository.startCalls, 0);
  });

  test('propaga los datos de facturacion al crear la orden', () async {
    await cubit.startQrPayment(
      merchantId: 53,
      productId: 1,
      customerName: 'Robot',
      phoneNumber: '',
      whereEat: 'dineIn',
      amount: 10,
      nit: ' 1234567890123 ',
      businessName: ' Empresa SRL ',
      autoPoll: false,
      cartItems: const [
        {'id': 1, 'name': 'Cafe', 'quantity': 1, 'price': 10.0},
      ],
      menuData: const {
        'categories': [
          {
            'products': [
              {'id': 1, 'name': 'Cafe', 'price': 10.0},
            ],
          },
        ],
      },
    );

    expect(paymentRepository.lastNit, ' 1234567890123 ');
    expect(paymentRepository.lastBusinessName, ' Empresa SRL ');
  });
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this.products);

  List<Product> products;

  @override
  Future<Product> getProduct(int merchantId, int productId) async => products
      .firstWhere((product) =>
          product.merchantId == merchantId && product.id == productId);

  @override
  Future<List<Product>> getProducts(int merchantId) async => products;

  @override
  Future<Merchant> getMerchantInfo(int merchantId) async =>
      Merchant(id: merchantId, name: 'Merchant');
}

class _FakeQrPaymentRepository implements QrPaymentRepository {
  int startCalls = 0;
  double? lastAmount;
  List<Map<String, dynamic>>? lastCartItems;
  String? lastNit;
  String? lastBusinessName;

  @override
  Future<Order> startQrPayment({
    required int merchantId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? nit,
    String? businessName,
    String? paymentReferenceOverride,
  }) async {
    startCalls++;
    lastAmount = amount;
    lastCartItems = cartItems;
    lastNit = nit;
    lastBusinessName = businessName;
    return const Order(orderId: 123, qrBase64: 'qr');
  }

  @override
  Future<OrderStatus> getPaymentStatus(int merchantId, int orderId) async =>
      OrderStatus.pending;

  @override
  Future<void> updateOrder({
    required int orderId,
    String? customerName,
    String? nit,
    String? businessName,
    String? phoneNumber,
  }) async {}

  @override
  Future<void> completeOrder(int orderId) async {}
}
