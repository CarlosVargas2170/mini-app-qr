import 'payment_counter.dart';

/// Estado global del polling de pago QR en la home.
///
/// Lo actualiza [ProductQrPanelWrapper] y lo expone [AppServer]
/// vía `GET /payment/polling-status` para el remote-control.
class PaymentPollingStatus {
  static final PaymentPollingStatus _instance = PaymentPollingStatus._();
  factory PaymentPollingStatus() => _instance;
  PaymentPollingStatus._();

  /// idle | waiting | polling | success | failed
  String phase = 'idle';

  bool isPolling = false;
  int? productId;
  int? merchantId;
  int? orderId;
  double? amount;
  String? productName;
  DateTime? updatedAt;

  void setIdle({String reason = 'idle'}) {
    phase = reason == 'success' || reason == 'failed' ? reason : 'idle';
    isPolling = false;
    if (reason == 'idle') {
      // Limpia contexto al salir del producto / dispose.
      productId = null;
      merchantId = null;
      orderId = null;
      amount = null;
      productName = null;
    }
    updatedAt = DateTime.now();
  }

  void setWaiting({
    required int productId,
    required int merchantId,
    int? orderId,
    double? amount,
    String? productName,
  }) {
    phase = 'waiting';
    isPolling = false;
    this.productId = productId;
    this.merchantId = merchantId;
    this.orderId = orderId;
    this.amount = amount;
    this.productName = productName;
    updatedAt = DateTime.now();
  }

  void setPolling({
    required int productId,
    required int merchantId,
    required int orderId,
    double? amount,
    String? productName,
  }) {
    phase = 'polling';
    isPolling = true;
    this.productId = productId;
    this.merchantId = merchantId;
    this.orderId = orderId;
    this.amount = amount;
    this.productName = productName;
    updatedAt = DateTime.now();
  }

  void setSuccess({
    int? productId,
    int? merchantId,
    int? orderId,
    double? amount,
    String? productName,
  }) {
    phase = 'success';
    isPolling = false;
    this.productId = productId ?? this.productId;
    this.merchantId = merchantId ?? this.merchantId;
    this.orderId = orderId ?? this.orderId;
    this.amount = amount ?? this.amount;
    this.productName = productName ?? this.productName;
    updatedAt = DateTime.now();
  }

  void setFailed({
    int? productId,
    int? merchantId,
    int? orderId,
  }) {
    phase = 'failed';
    isPolling = false;
    this.productId = productId ?? this.productId;
    this.merchantId = merchantId ?? this.merchantId;
    this.orderId = orderId ?? this.orderId;
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'success': true,
        'isPolling': isPolling,
        'phase': phase,
        'productId': productId,
        'merchantId': merchantId,
        'orderId': orderId,
        'amount': amount,
        'productName': productName,
        'updatedAt': updatedAt?.toIso8601String(),
        'label': _label,
        'counter': PaymentCounter().toJson(),
      };

  String get _label => switch (phase) {
        'polling' => 'Polling activo',
        'waiting' => 'QR listo (sin polling)',
        'success' => 'Pago exitoso',
        'failed' => 'Pago fallido',
        _ => 'Polling detenido',
      };
}
