import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool fill;
  const ProductCard({super.key, required this.product, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final hasOffer = product.oldPrice != null;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF0D0D1A)),
        if (product.urlImage.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              product.urlImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const _Placeholder(),
            ),
          )
        else
          const _Placeholder(),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xEE000000), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.only(top: 120, bottom: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isWide ? 32 : 26,
                  ),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isWide ? 16 : 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              if (hasOffer)
                const _Badge(label: 'Oferta', color: Color(0xFF6B7BF7)),
              if (hasOffer) const SizedBox(width: 6),
              _Badge(
                label: '${product.price} Bs',
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: fill
            ? stack
            : AspectRatio(
                aspectRatio: isWide ? 16 / 10 : 4 / 5,
                child: stack,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.fastfood, color: Colors.white24, size: 80),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
