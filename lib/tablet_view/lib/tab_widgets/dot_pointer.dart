import 'package:flutter/material.dart';

import '../tab_constants/colors.dart';

class DotPointer extends StatelessWidget {
  final int pageCount;
  final int selectedIndex;
  final Color primaryColor;
  final Color secondaryColor;
  const DotPointer({
    super.key,
    required this.pageCount,
    required this.selectedIndex,
    this.primaryColor = AppColors.tertiary,
    this.secondaryColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: pageCount,
        itemBuilder: (_, index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOutCubicEmphasized,
            decoration: BoxDecoration(
              color: selectedIndex == index
                  ? primaryColor
                  : secondaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            margin: EdgeInsets.all(3),
            width: selectedIndex == index ? 6 : 5,
            height: selectedIndex == index ? 6 : 5,
          );
        },
      ),
    );
  }
}
