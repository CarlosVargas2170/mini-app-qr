/// Body para actualizar datos de una orden existente.
/// Endpoint: PUT /orders/{id}
class UpdateOrderRequestDto {
  final String? customerName;
  final String? nit;
  final String? businessName;
  final String? phoneNumber;

  UpdateOrderRequestDto({
    this.customerName,
    this.nit,
    this.businessName,
    this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (customerName != null && customerName!.isNotEmpty) {
      map['customerName'] = customerName;
    }
    if (nit != null && nit!.isNotEmpty) {
      map['nit'] = nit;
    }
    if (businessName != null && businessName!.isNotEmpty) {
      map['businessName'] = businessName;
    }
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      map['phoneNumber'] = phoneNumber;
    }
    return map;
  }
}
