/// Contador global de ventas (pagos confirmados) expuesto al remote-control.
///
/// Se incrementa en `ProductQrPanelWrapper._onPaymentSuccess()`
/// y se expone vía `GET /payment/polling-status`.
class PaymentCounter {
  static final PaymentCounter _instance = PaymentCounter._();
  factory PaymentCounter() => _instance;
  PaymentCounter._();

  /// Guarda las últimas ventas individuales (máximo 50).
  final List<_Sale> _sales = [];
  final Map<String, _ProductSummary> _productSummaries = {};

  int _totalSales = 0;
  int _totalUnits = 0;
  double _totalAmount = 0.0;

  int get totalSales => _totalSales;
  int get totalUnits => _totalUnits;
  double get totalAmount => _totalAmount;

  void increment({
    required double amount,
    required int productId,
    required String productName,
    int? merchantId,
    List<Map<String, dynamic>> cartItems = const [],
  }) {
    final items = _normalizeItems(
      cartItems: cartItems,
      fallbackProductId: productId,
      fallbackProductName: productName,
      fallbackAmount: amount,
    );

    _totalSales++;
    _totalUnits += items.fold(0, (total, item) => total + item.quantity);
    _totalAmount += amount;

    for (final item in items) {
      final key = item.productId > 0
          ? '${merchantId ?? 0}:${item.productId}'
          : '${merchantId ?? 0}:name:${item.name.toLowerCase()}';
      final summary = _productSummaries.putIfAbsent(
        key,
        () => _ProductSummary(
          productId: item.productId,
          merchantId: merchantId,
          name: item.name,
        ),
      );
      summary.quantity += item.quantity;
      summary.total += item.total;
    }

    _sales.insert(
      0,
      _Sale(
        productId: productId,
        productName: productName,
        amount: amount,
        merchantId: merchantId,
        items: items,
        timestamp: DateTime.now(),
      ),
    );

    // Mantener máximo 50 registros
    if (_sales.length > 50) {
      _sales.removeRange(50, _sales.length);
    }
  }

  void reset() {
    _totalSales = 0;
    _totalUnits = 0;
    _totalAmount = 0.0;
    _sales.clear();
    _productSummaries.clear();
  }

  /// Resume unidades vendidas por producto durante toda la sesión.
  List<Map<String, dynamic>> _summaryByProduct() {
    return _productSummaries.values
        .map((p) => {
              'productId': p.productId,
              'merchantId': p.merchantId,
              'name': p.name,
              // `count` se conserva para clientes remotos existentes.
              'count': p.quantity,
              'quantity': p.quantity,
              'total': double.parse(p.total.toStringAsFixed(2)),
            })
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'totalSales': _totalSales,
        'totalOrders': _totalSales,
        'totalUnits': _totalUnits,
        'totalAmount': double.parse(_totalAmount.toStringAsFixed(2)),
        'recent': _sales.take(10).map(_saleToJson).toList(),
        'byProduct': _summaryByProduct(),
      };

  static Map<String, dynamic> _saleToJson(_Sale s) => {
        'productName': s.productName,
        'productId': s.productId,
        'amount': s.amount,
        'merchantId': s.merchantId,
        'quantity': s.items.fold(0, (total, item) => total + item.quantity),
        'items': s.items.map((item) => item.toJson()).toList(),
        'time': s.timestamp.toIso8601String(),
      };

  static List<_SaleItem> _normalizeItems({
    required List<Map<String, dynamic>> cartItems,
    required int fallbackProductId,
    required String fallbackProductName,
    required double fallbackAmount,
  }) {
    final grouped = <String, _SaleItem>{};

    for (final rawItem in cartItems) {
      final productId = (rawItem['id'] as num?)?.toInt() ?? 0;
      final name = (rawItem['name'] as String? ?? '').trim();
      final quantity = (rawItem['quantity'] as num?)?.toInt() ?? 1;
      final price = (rawItem['price'] as num?)?.toDouble() ?? 0.0;
      if (name.isEmpty || quantity <= 0) continue;

      final key =
          productId > 0 ? 'id:$productId' : 'name:${name.toLowerCase()}';
      final previous = grouped[key];
      grouped[key] = _SaleItem(
        productId: productId,
        name: name,
        quantity: (previous?.quantity ?? 0) + quantity,
        unitPrice: price,
      );
    }

    if (grouped.isNotEmpty) return grouped.values.toList(growable: false);

    return [
      _SaleItem(
        productId: fallbackProductId,
        name: fallbackProductName,
        quantity: 1,
        unitPrice: fallbackAmount,
      ),
    ];
  }
}

class _Sale {
  final int productId;
  final String productName;
  final double amount;
  final int? merchantId;
  final List<_SaleItem> items;
  final DateTime timestamp;

  const _Sale({
    required this.productId,
    required this.productName,
    required this.amount,
    this.merchantId,
    required this.items,
    required this.timestamp,
  });
}

class _SaleItem {
  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;

  const _SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitPrice': double.parse(unitPrice.toStringAsFixed(2)),
        'total': double.parse(total.toStringAsFixed(2)),
      };
}

class _ProductSummary {
  final int productId;
  final int? merchantId;
  final String name;
  int quantity;
  double total;

  _ProductSummary({
    required this.productId,
    required this.merchantId,
    required this.name,
  })  : quantity = 0,
        total = 0;
}
