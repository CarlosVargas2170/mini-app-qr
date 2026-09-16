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
      final baseKey = productId != null && productId > 0
          ? 'id:$productId'
          : 'name:${name.toLowerCase()}';
      // Dos lineas del mismo producto con distinta configuracion de
      // toppings deben quedar como items separados: la firma se agrega a
      // la clave de agrupacion para no fusionarlas.
      final key = '$baseKey|${_configurationSignature(item)}';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      if (grouped.containsKey(key)) {
        grouped[key]!['quantity'] = (grouped[key]!['quantity'] as int) + qty;
      } else {
        grouped[key] = Map<String, dynamic>.from(item)..['quantity'] = qty;
      }
    }

    return grouped.values.map((item) {
      final name = item['name'] as String;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final itemProductId = (item['id'] as num?)?.toInt();
      final product = _findProduct(itemProductId, name);
      final basePrice = product?['price'] != null
          ? (product!['price'] as num).toDouble()
          : (item['price'] as num?)?.toDouble() ?? 0.0;
      // `item['price']` ya incluye addons de toppings (recalculados y
      // validados por QrPaymentCubit contra el catalogo fresco antes de
      // llegar aqui); `basePrice` es solo el precio base para mostrar.
      final unitPrice = (item['price'] as num?)?.toDouble() ?? basePrice;
      final rawImage =
          product?['urlImage'] as String? ?? product?['image'] as String? ?? '';
      final imageUrl = rawImage.isNotEmpty
          ? rawImage
          : 'https://placeholder.com/product.png';

      return {
        'id':
            'totem-${name.replaceAll(' ', '-').toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}',
        'product': {
          'id': (product?['id'] as num?)?.toInt() ?? 0,
          'name': name,
          'price': basePrice,
          'urlImage': imageUrl,
          if (product?['description'] != null)
            'description': product!['description'],
        },
        'quantity': qty,
        'selectedToppings': _buildSelectedToppings(item['toppings']),
        'totalPrice': unitPrice * qty,
        'extraQuantities': _buildExtraQuantities(item['extraQuantities']),
      };
    }).toList();
  }

  /// Firma estable de la configuracion de toppings/extras de un item del
  /// snapshot de pago (`cartItems`), usada para no fusionar en la misma
  /// linea dos configuraciones distintas del mismo producto.
  String _configurationSignature(Map<String, dynamic> item) {
    final toppings = (item['toppings'] as List?) ?? const [];
    final toppingIds = toppings
        .map((t) => (t as Map)['toppingId'])
        .map((id) => id.toString())
        .toList()
      ..sort();

    final extras = (item['extraQuantities'] as Map?) ?? const {};
    final extraKeys = extras.keys.map((k) => k.toString()).toList()..sort();

    return '${toppingIds.join(',')}|${extraKeys.join(',')}';
  }

  /// Convierte los toppings elegidos (formato interno de `cartItems`) al
  /// formato que espera el backend por item de orden.
  List<Map<String, dynamic>> _buildSelectedToppings(dynamic rawToppings) {
    if (rawToppings is! List) return const [];

    return rawToppings.whereType<Map>().map((raw) {
      final subToppings = ((raw['subToppings'] as List?) ?? const [])
          .whereType<Map>()
          .map((sub) => {
                'id': sub['id'],
                'name': sub['name'],
                'priority': 0,
                'price': (sub['price'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();

      return {
        'topping': {
          'id': raw['toppingId'],
          'name': raw['toppingName'],
          'priority': 0,
          'type': raw['type'],
          'minLimit': raw['minLimit'],
          'maxLimit': raw['maxLimit'],
          'subToppings': subToppings,
        },
        'selectedSubToppings': subToppings,
        'quantity': 1,
      };
    }).toList();
  }

  /// Convierte `extraQuantities` (ya viene con claves de texto desde
  /// `home_page.dart`) tal cual, tolerando ausencia.
  Map<String, dynamic> _buildExtraQuantities(dynamic rawExtraQuantities) {
    if (rawExtraQuantities is! Map) return const {};
    return Map<String, dynamic>.from(rawExtraQuantities);
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
    return items.fold(0.0,
        (sum, item) => sum + ((item['totalPrice'] as num?)?.toDouble() ?? 0.0));
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
