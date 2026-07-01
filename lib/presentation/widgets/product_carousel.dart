import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product.dart';
import '../bloc/home_cubit.dart';
import 'product_card.dart';

class ProductCarousel extends StatelessWidget {
  final List<Product> products;
  final int currentIndex;

  const ProductCarousel({
    super.key,
    required this.products,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Column(
      children: [
        Expanded(
          child: CarouselSlider.builder(
            itemCount: products.length,
            itemBuilder: (context, index, realIndex) {
              return ProductCard(product: products[index], fill: true);
            },
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: isWide ? 0.90 : 1.05,
              initialPage: currentIndex,
              enableInfiniteScroll: products.length > 1,
              enlargeCenterPage: true,
              enlargeFactor: 0.2,
              onPageChanged: (index, reason) {
                context.read<HomeCubit>().updateCurrentIndex(index);
              },
            ),
          ),
        ),
        if (products.length > 1) ...[
          const SizedBox(height: 12),
          _buildIndicators(products.length, currentIndex),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildIndicators(int count, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF6B6B) : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
