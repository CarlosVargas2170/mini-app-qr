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

  int _totalSales = 0;
  double _totalAmount = 0.0;

  int get totalSales => _totalSales;
  double get totalAmount => _totalAmount;

  void increment({
    required double amount,
    required int productId,
    required String productName,
    int? merchantId,
  }) {
    _totalSales++;
    _totalAmount += amount;

    _sales.insert(
      0,
      _Sale(
        productId: productId,
        productName: productName,
        amount: amount,
        merchantId: merchantId,
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
    _totalAmount = 0.0;
    _sales.clear();
  }

  /// Agrupa ventas por producto.
  List<Map<String, dynamic>> _summaryByProduct() {
    final map = <String, _ProductSummary>{};
    for (final s in _sales) {
      final key = s.productName;
      map.putIfAbsent(
        key,
        () => _ProductSummary(name: s.productName, count: 0, total: 0),
      );
      map[key]!.count++;
      map[key]!.total += s.amount;
    }
    return map.values
        .map((p) => {
              'name': p.name,
              'count': p.count,
              'total': double.parse(p.total.toStringAsFixed(2)),
            })
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'totalSales': _totalSales,
        'totalAmount': double.parse(_totalAmount.toStringAsFixed(2)),
        'recent': _sales.take(10).map(_saleToJson).toList(),
        'byProduct': _summaryByProduct(),
      };

  static Map<String, dynamic> _saleToJson(_Sale s) => {
        'productName': s.productName,
        'productId': s.productId,
        'amount': s.amount,
        'merchantId': s.merchantId,
        'time': s.timestamp.toIso8601String(),
      };
}

class _Sale {
  final int productId;
  final String productName;
  final double amount;
  final int? merchantId;
  final DateTime timestamp;

  const _Sale({
    required this.productId,
    required this.productName,
    required this.amount,
    this.merchantId,
    required this.timestamp,
  });
}

class _ProductSummary {
  final String name;
  int count;
  double total;

  _ProductSummary({required this.name, this.count = 0, this.total = 0});
}
