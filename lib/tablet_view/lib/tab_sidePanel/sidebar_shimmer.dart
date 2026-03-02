import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SideBarShimmer extends StatelessWidget {
  final bool collapsed;

  const SideBarShimmer({super.key, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 80.0 : 300.0;
    return Container(
      width: width,
      height: double.infinity,
      color: Colors.black, // same as sidebar base
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            // Logo shimmer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
              child: Container(
                width: collapsed ? 50 : 140,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Menu items shimmer
            ...List.generate(6, (_) => _menuShimmer(collapsed)),

            const Spacer(),

            // Bottom user shimmer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Container(width: 100, height: 14, color: Colors.white),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuShimmer(bool collapsed) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 0 : 20,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 14),
            Container(width: 120, height: 14, color: Colors.white),
          ],
        ],
      ),
    );
  }
}
