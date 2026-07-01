import 'package:dio/dio.dart';
import '../../core/config/app_settings.dart';
import '../../data/product_remote_data_source.dart';
import '../../data/datasources/qr_payment_remote_data_source.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/qr_payment_repository.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/get_products.dart';
import '../../domain/usecases/get_merchant_info.dart';
import '../../domain/usecases/start_qr_payment.dart';
import '../../domain/usecases/get_payment_status.dart';
import '../../domain/usecases/update_order.dart';
import '../../domain/usecases/complete_order.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/qr_payment_repository_impl.dart';
import '../../presentation/bloc/home_cubit.dart';
import '../../presentation/bloc/qr_payment_cubit.dart';

/// Service locator manual (interino) hasta migrar a get_it / injectable.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final Dio _dio;
  late final ProductRemoteDataSource _productRemoteDataSource;
  late final QrPaymentRemoteDataSource _qrPaymentRemoteDataSource;

  late final ProductRepository productRepository;
  late final QrPaymentRepository qrPaymentRepository;

  late final GetProductUseCase getProductUseCase;
  late final GetProductsUseCase getProductsUseCase;
  late final GetMerchantInfoUseCase getMerchantInfoUseCase;
  late final StartQrPaymentUseCase startQrPaymentUseCase;
  late final GetPaymentStatusUseCase getPaymentStatusUseCase;
  late final UpdateOrderUseCase updateOrderUseCase;
  late final CompleteOrderUseCase completeOrderUseCase;

  void init() {
    final settings = AppSettings();
    _dio = Dio(BaseOptions(
      baseUrl: settings.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Authorization': 'Bearer ${settings.bearerToken}',
        'Content-Type': 'application/json',
      },
    ));

    _productRemoteDataSource = ProductRemoteDataSource(_dio);
    _qrPaymentRemoteDataSource = QrPaymentRemoteDataSourceImpl(_dio);

    productRepository = ProductRepositoryImpl(_productRemoteDataSource);
    qrPaymentRepository = QrPaymentRepositoryImpl(_qrPaymentRemoteDataSource);

    getProductUseCase = GetProductUseCase(productRepository);
    getProductsUseCase = GetProductsUseCase(productRepository);
    getMerchantInfoUseCase = GetMerchantInfoUseCase(productRepository);
    startQrPaymentUseCase = StartQrPaymentUseCase(qrPaymentRepository);
    getPaymentStatusUseCase = GetPaymentStatusUseCase(qrPaymentRepository);
    updateOrderUseCase = UpdateOrderUseCase(qrPaymentRepository);
    completeOrderUseCase = CompleteOrderUseCase(qrPaymentRepository);
  }

  /// Factory: crea un nuevo HomeCubit cada vez que se invoca.
  HomeCubit homeCubit() => HomeCubit(
        getProducts: getProductsUseCase,
        getMerchant: getMerchantInfoUseCase,
      );

  /// Factory: crea un nuevo QrPaymentCubit cada vez que se invoca.
  QrPaymentCubit qrPaymentCubit() => QrPaymentCubit(
        startQrPayment: startQrPaymentUseCase,
        getPaymentStatus: getPaymentStatusUseCase,
        updateOrder: updateOrderUseCase,
        completeOrder: completeOrderUseCase,
      );
}

final sl = ServiceLocator();
