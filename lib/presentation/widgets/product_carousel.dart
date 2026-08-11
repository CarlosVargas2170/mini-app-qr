import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product.dart';
import '../bloc/home_cubit.dart';
import 'carousel_swipe_hint.dart';
import 'product_card.dart';

class ProductCarousel extends StatefulWidget {
  final List<Product> products;
  final int currentIndex;

  const ProductCarousel({
    super.key,
    required this.products,
    required this.currentIndex,
  });

  @override
  State<ProductCarousel> createState() => _ProductCarouselState();
}

class _ProductCarouselState extends State<ProductCarousel> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  /// Indice real del carrusel, actualizado solo en [onPageChanged].
  int _realIndex = 0;

  @override
  void initState() {
    super.initState();
    _realIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(ProductCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo anima si el indice cambio desde fuera (no por swipe del usuario)
    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex != _realIndex) {
      _realIndex = widget.currentIndex;
      // Usar addPostFrameCallback para asegurar que el PageController
      // interno del carrusel ya tiene clientes antes de animar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _carouselController.animateToPage(
            widget.currentIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: widget.products.length,
                itemBuilder: (context, index, realIndex) {
                  return ProductCard(
                      product: widget.products[index], fill: true);
                },
                options: CarouselOptions(
                  height: double.infinity,
                  viewportFraction: isWide ? 0.90 : 1.05,
                  initialPage: widget.currentIndex,
                  enableInfiniteScroll: widget.products.length > 1,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.2,
                  onPageChanged: (index, reason) {
                    _realIndex = index;
                    context.read<HomeCubit>().updateCurrentIndex(index);
                  },
                ),
              ),
              if (widget.products.length > 1)
                CarouselSwipeHint(
                  style: SwipeHintStyle.neon,
                  onPrevious: () => _carouselController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  onNext: () => _carouselController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                ),
            ],
          ),
        ),
        if (widget.products.length > 1) ...[
          const SizedBox(height: 12),
          _buildIndicators(widget.products.length, widget.currentIndex),
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
