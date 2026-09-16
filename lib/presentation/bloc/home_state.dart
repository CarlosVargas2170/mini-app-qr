import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/merchant.dart';
import '../../domain/entities/product.dart';

enum HomeStatus { initial, loading, loaded, error }

/// Modo de visualizacion en la pantalla principal.
/// - [idle]: reposo (pantalla negra / espera).
/// - [attract]: video de atraccion cuando el robot esta cerca.
/// - [product]: carrusel de productos y boton de pago.
enum DisplayMode { idle, attract, product }

class HomeState extends Equatable {
  final HomeStatus status;
  final DisplayMode displayMode;
  final List<Product> products;
  final int currentIndex;
  final String merchantName;
  final List<String> merchantNames;
  final List<int> merchantIds;
  final Map<int, Merchant> merchantsById;

  /// Lineas del carrito. Un mismo producto puede aparecer en varias lineas
  /// cuando tiene toppings con distinta configuracion cada una.
  final List<CartItem> cartLines;
  final String? cartSyncMessage;
  final int cartSyncRevision;
  final String? errorMessage;

  /// Marca de tiempo del último polling exitoso de productos.
  /// `null` si nunca se ha ejecutado el polling.
  final DateTime? lastPolledAt;

  /// Ruta del asset GIF que se muestra en modo [DisplayMode.attract].
  /// Por defecto `assets/images/normal.gif`.
  final String attractGifAsset;

  const HomeState({
    this.status = HomeStatus.initial,
    this.displayMode = DisplayMode.idle,
    this.products = const [],
    this.currentIndex = 0,
    this.merchantName = 'Mi Tienda',
    this.merchantNames = const [],
    this.merchantIds = const [],
    this.merchantsById = const {},
    this.cartLines = const [],
    this.cartSyncMessage,
    this.cartSyncRevision = 0,
    this.errorMessage,
    this.lastPolledAt,
    this.attractGifAsset = 'assets/images/normal.gif',
  });

  Product? get currentProduct =>
      products.isNotEmpty ? products[currentIndex] : null;

  static String cartKey(Product product) =>
      '${product.merchantId}_${product.id}';

  /// Linea sin configuracion de toppings de [product], si existe. Un
  /// producto sin toppings tiene a lo sumo una de estas lineas: es la que
  /// maneja el "+/-" simple del carrusel.
  CartItem? _unconfiguredLineFor(Product product) {
    final key = cartKey(product);
    for (final line in cartLines) {
      if (cartKey(line.product) == key && !line.hasCustomConfiguration) {
        return line;
      }
    }
    return null;
  }

  /// Cantidad de la linea sin configurar de [product]. Para productos con
  /// toppings, las lineas configuradas no se cuentan aqui: se muestran por
  /// separado en el carrito.
  int quantityFor(Product product) =>
      _unconfiguredLineFor(product)?.quantity ?? 0;

  /// Todas las lineas (configuradas o no) de [product].
  List<CartItem> cartLinesFor(Product product) {
    final key = cartKey(product);
    return cartLines.where((line) => cartKey(line.product) == key).toList();
  }

  /// Productos distintos presentes en el carrito, sin importar cuantas
  /// lineas/configuraciones tenga cada uno.
  List<Product> get cartProducts {
    final seen = <String>{};
    final result = <Product>[];
    for (final line in cartLines) {
      if (seen.add(cartKey(line.product))) result.add(line.product);
    }
    return result;
  }

  int get cartTotalItems =>
      cartLines.fold(0, (total, line) => total + line.quantity);

  double get cartTotal =>
      cartLines.fold(0.0, (total, line) => total + line.totalPrice);

  /// Obtiene el nombre del merchant para un producto especifico.
  String getMerchantNameForProduct(Product product) {
    final merchant = merchantsById[product.merchantId];
    if (merchant != null) return merchant.name;

    final index = merchantIds.indexOf(product.merchantId);
    if (index >= 0 && index < merchantNames.length) {
      return merchantNames[index];
    }
    return merchantName; // Fallback
  }

  bool merchantUsesBilling(int merchantId) =>
      merchantsById[merchantId]?.usesBilling ?? false;

  HomeState copyWith({
    HomeStatus? status,
    DisplayMode? displayMode,
    List<Product>? products,
    int? currentIndex,
    String? merchantName,
    List<String>? merchantNames,
    List<int>? merchantIds,
    Map<int, Merchant>? merchantsById,
    List<CartItem>? cartLines,
    String? cartSyncMessage,
    int? cartSyncRevision,
    String? errorMessage,
    DateTime? lastPolledAt,
    String? attractGifAsset,
  }) {
    return HomeState(
      status: status ?? this.status,
      displayMode: displayMode ?? this.displayMode,
      products: products ?? this.products,
      currentIndex: currentIndex ?? this.currentIndex,
      merchantName: merchantName ?? this.merchantName,
      merchantNames: merchantNames ?? this.merchantNames,
      merchantIds: merchantIds ?? this.merchantIds,
      merchantsById: merchantsById ?? this.merchantsById,
      cartLines: cartLines ?? this.cartLines,
      cartSyncMessage: cartSyncMessage ?? this.cartSyncMessage,
      cartSyncRevision: cartSyncRevision ?? this.cartSyncRevision,
      errorMessage: errorMessage ?? this.errorMessage,
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
      attractGifAsset: attractGifAsset ?? this.attractGifAsset,
    );
  }

  @override
  List<Object?> get props => [
        status,
        displayMode,
        products,
        currentIndex,
        merchantName,
        merchantNames,
        merchantIds,
        merchantsById,
        cartLines,
        cartSyncMessage,
        cartSyncRevision,
        errorMessage,
        lastPolledAt,
        attractGifAsset,
      ];
}
