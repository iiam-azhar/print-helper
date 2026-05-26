import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays a rule icon fetched from [svgUrl] (the `icon_svg_url` API field).
/// Tints the SVG with [colorHex] when provided (e.g. "#ef4444").
/// Falls back to a generic [Icons.info_outline] if the URL is absent.
class RuleIcon extends StatelessWidget {
  final String? svgUrl;
  final String? colorHex;
  final double size;

  const RuleIcon({
    super.key,
    required this.svgUrl,
    this.colorHex,
    this.size = 20,
  });

  static Color? _hexToColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.trim().toLowerCase();
    if (cleaned.isEmpty) return null;
    cleaned = cleaned.replaceFirst('#', '').replaceFirst('0x', '');
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
      cleaned = 'ff$cleaned';
    } else if (cleaned.length == 6) {
      cleaned = 'ff$cleaned';
    } else if (cleaned.length == 8) {
      // already full AARRGGBB — use as-is
    } else {
      return null;
    }
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(cleaned)) return null;
    try {
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = svgUrl;
    final color = _hexToColor(colorHex) ?? const Color(0xFF22C55E);

    if (url == null || url.isEmpty) {
      return Icon(Icons.info_outline, size: size, color: color);
    }

    return SvgPicture.network(
      url,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) =>
          Icon(Icons.info_outline, size: size, color: color),
    );
  }
}
