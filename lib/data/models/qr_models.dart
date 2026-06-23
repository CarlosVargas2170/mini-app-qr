import '../../domain/entities/order_status.dart';
// ---------------------------------------------------------------------------
// Request / Response para generar QR de pago
// ---------------------------------------------------------------------------

class GeneratePaymentQrRequestDto {
  final double amount;
  final int merchantId;
  final int orderId;

  GeneratePaymentQrRequestDto({
    required this.amount,
    required this.merchantId,
    required this.orderId,
  });

  Map<String, dynamic> toJson() => {
        'amount': double.parse(amount.toStringAsFixed(2)),
        'merchantId': merchantId,
        'orderId': orderId,
      };
}

class GeneratePaymentQrResponseDto {
  final String qrBase64;
  final int orderId;

  GeneratePaymentQrResponseDto({
    required this.qrBase64,
    required this.orderId,
  });

  factory GeneratePaymentQrResponseDto.fromJson(Map<String, dynamic> json) =>
      GeneratePaymentQrResponseDto(
        qrBase64: (json['qrBase64'] as String?) ?? '',
        orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Response de creacion de orden
// ---------------------------------------------------------------------------

class PlaceOrderResponseDto {
  final int orderId;
  final int? dailyOrderNumber;
  final String? storeName;
  final String? provider;
  final String? status;
  final String? createdAt;
  final String? externalId;

  PlaceOrderResponseDto({
    required this.orderId,
    this.dailyOrderNumber,
    this.storeName,
    this.provider,
    this.status,
    this.createdAt,
    this.externalId,
  });

  factory PlaceOrderResponseDto.fromJson(Map<String, dynamic> json) =>
      PlaceOrderResponseDto(
        orderId: (json['id'] as num?)?.toInt() ?? 0,
        dailyOrderNumber: (json['dailyOrderNumber'] as num?)?.toInt(),
        storeName: json['storeName'] as String?,
        provider: json['provider'] as String?,
        status: json['status'] as String?,
        createdAt: json['createdAt'] as String?,
        externalId: json['externalId'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Response de consulta de estado de pago
// ---------------------------------------------------------------------------

class PaymentStatusDto {
  final OrderStatus status;

  PaymentStatusDto({required this.status});

  factory PaymentStatusDto.fromJson(Map<String, dynamic> json) {
    final raw = (json['status'] as String?)?.toUpperCase() ?? '';
    final status = switch (raw) {
      'SUCCESS' || 'PAID' => OrderStatus.confirmed,
      'FAILED' || 'EXPIRED' || 'CANCELLED' || 'CLOSED' || 'ERROR' =>
        OrderStatus.failed,
      'PENDING' || 'NOTFOUND' => OrderStatus.pending,
      _ => OrderStatus.unknown,
    };
    return PaymentStatusDto(status: status);
  }
}
