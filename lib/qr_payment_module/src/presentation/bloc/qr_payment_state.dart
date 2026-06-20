import 'package:equatable/equatable.dart';

enum QrPaymentStatus {
  initial,
  loading,
  qrReady,
  success,
  failed,
  cancelled,
}

class QrPaymentState extends Equatable {
  final QrPaymentStatus status;
  final String? qrBase64;
  final int? orderId;
  final String? errorMessage;
  final bool isPolling;

  const QrPaymentState({
    this.status = QrPaymentStatus.initial,
    this.qrBase64,
    this.orderId,
    this.errorMessage,
    this.isPolling = false,
  });

  static const _absent = Object();

  QrPaymentState copyWith({
    QrPaymentStatus? status,
    Object? qrBase64 = _absent,
    Object? orderId = _absent,
    String? errorMessage,
    bool? isPolling,
  }) {
    return QrPaymentState(
      status: status ?? this.status,
      qrBase64: qrBase64 == _absent ? this.qrBase64 : qrBase64 as String?,
      orderId: orderId == _absent ? this.orderId : orderId as int?,
      errorMessage: errorMessage ?? this.errorMessage,
      isPolling: isPolling ?? this.isPolling,
    );
  }

  @override
  List<Object?> get props => [
        status,
        qrBase64,
        orderId,
        errorMessage,
        isPolling,
      ];
}
