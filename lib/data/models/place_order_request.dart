/// Body para crear una orden en estado pendiente.
/// Es generico; puedes construir el body con `toJson()` o pasar un `Map<String,dynamic>` directo.
class PlaceOrderRequestDto {
  final int merchantId;
  final String customerName;
  final String paymentMethodType;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? menuData;
  final String? phoneNumber;
  final String? whereEat;
  final String? nit;
  final String? businessName;
  final String? paymentReferenceOverride;

  PlaceOrderRequestDto({
    required this.merchantId,
    required this.customerName,
    this.paymentMethodType = 'qr',
    required this.cartItems,
    this.menuData,
    this.phoneNumber,
    this.whereEat,
    this.nit,
    this.businessName,
    this.paymentReferenceOverride,
  });

  Map<String, dynamic> toJson() {
    final items = _buildItems();
    final total = _calculateTotal(items);

    return {
      'cart': {
        'metadataMerchant': {
          'id': merchantId,
          'name': _merchantName(),
          'urlLogo': _merchantLogo(),
        },
        'items': items,
        'subtotal': total,
        'tax': 0.0,
        'total': total,
      },
      'paymentMethod': paymentMethodType.toLowerCase(),
      if (whereEat != null) 'whereEat': whereEat,
      'paymentReference': paymentReferenceOverride ??
          'TOTEM-${DateTime.now().millisecondsSinceEpoch}',
      'customerName': customerName,
      if (phoneNumber != null && phoneNumber!.isNotEmpty)
        'phoneNumber': phoneNumber,
      if (nit != null && nit!.trim().isNotEmpty) 'nit': nit!.trim(),
      if (businessName != null && businessName!.trim().isNotEmpty)
        'businessName': businessName!.trim(),
    };
  }

  List<Map<String, dynamic>> _buildItems() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final item in cartItems) {
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final productId = (item['id'] as num?)?.toInt();
      final key = productId != null && productId > 0
          ? 'id:$productId'
          : 'name:${name.toLowerCase()}';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      if (grouped.containsKey(key)) {
        grouped[key]!['quantity'] =
            (grouped[key]!['quantity'] as int) + qty;
      } else {
        grouped[key] = Map<String, dynamic>.from(item)..['quantity'] = qty;
      }
    }

    return grouped.values.map((item) {
      final name = item['name'] as String;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final itemProductId = (item['id'] as num?)?.toInt();
      final product = _findProduct(itemProductId, name);
      final price = product?['price'] != null
          ? (product!['price'] as num).toDouble()
          : (item['price'] as num?)?.toDouble() ?? 0.0;
      final rawImage = product?['urlImage'] as String? ??
          product?['image'] as String? ??
          '';
      final imageUrl =
          rawImage.isNotEmpty ? rawImage : 'https://placeholder.com/product.png';

      return {
        'id': 'totem-${name.replaceAll(' ', '-').toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}',
        'product': {
          'id': (product?['id'] as num?)?.toInt() ?? 0,
          'name': name,
          'price': price,
          'urlImage': imageUrl,
          if (product?['description'] != null)
            'description': product!['description'],
        },
        'quantity': qty,
        'selectedToppings': [],
        'totalPrice': price * qty,
      };
    }).toList();
  }

  Map<String, dynamic>? _findProduct(int? productId, String productName) {
    final categories = menuData?['categories'] as List<dynamic>?;
    if (categories == null) return null;
    final nameLower = productName.toLowerCase();
    for (final cat in categories) {
      final products =
          (cat as Map<String, dynamic>)['products'] as List<dynamic>?;
      if (products == null) continue;
      for (final prod in products) {
        final p = prod as Map<String, dynamic>;
        if (productId != null &&
            productId > 0 &&
            (p['id'] as num?)?.toInt() == productId) {
          return p;
        }
        if ((p['name'] as String?)?.toLowerCase() == nameLower) return p;
      }
    }
    return null;
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    return items.fold(
        0.0,
        (sum, item) =>
            sum + ((item['totalPrice'] as num?)?.toDouble() ?? 0.0));
  }

  String _merchantName() {
    final name = menuData?['merchantName'] as String? ??
        menuData?['name'] as String? ??
        (menuData?['merchant'] as Map<String, dynamic>?)?['name'] as String? ??
        '';
    return name.isNotEmpty ? name : 'Comercio';
  }

  String _merchantLogo() {
    final logo = menuData?['merchantUrlLogo'] as String? ??
        menuData?['urlLogo'] as String? ??
        menuData?['logo'] as String? ??
        (menuData?['merchant'] as Map<String, dynamic>?)?['urlLogo']
            as String? ??
        '';
    return logo.isNotEmpty ? logo : 'https://placeholder.com/logo.png';
  }
}
