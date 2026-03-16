import 'package:flutter/material.dart';

class CustomWaveform extends StatelessWidget {
  final List<double> samples;
  final int activeSamples;
  final Color inactiveColor;
  final Color activeColor;

  const CustomWaveform({
    super.key,
    required this.samples,
    required this.activeSamples,
    required this.inactiveColor,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return Container(color: Colors.transparent);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: List.generate(samples.length, (index) {
        final isActive = index < activeSamples;
        final normalizedHeight = samples[index].clamp(0.1, 1.0);
        final height = normalizedHeight * 28;

        return Expanded(
          child: Center(
            child: Container(
              width: 2.5,
              height: height,
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(1.25),
              ),
            ),
          ),
        );
      }),
    );
  }
}
