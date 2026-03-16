import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'loaders.dart';

class ImageWidget extends StatelessWidget {
  final String image;
  final double? width;
  final double? height;
  final double? scale;
  final BoxFit? fit;
  final Alignment? alignment;
  final Color? color;
  final bool svgString;
  final bool showLoad;
  final Widget? errorWidget;
  const ImageWidget({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.scale,
    this.color,
    this.svgString = false,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.showLoad = true,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) return errorWidget ?? _errorWidget();
    if (image.startsWith('http')) {
      return _showNetworkImage();
    } else if (isFile(image)) {
      return _fileImage();
    } else if (svgString) {
      return _svgStringImage();
    } else {
      return _showAssetImage();
    }
  }

  Widget _showNetworkImage() {
    if (image.endsWith('.svg')) {
      const srcIn = BlendMode.srcIn;
      final clr = color == null ? null : ColorFilter.mode(color!, srcIn);
      return SvgPicture.network(
        image,
        fit: fit!,
        height: height,
        width: width,
        alignment: alignment!,
        colorFilter: clr,
        placeholderBuilder: showLoad ? (context) => showLoader() : null,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: image,
        fit: fit,
        height: height,
        width: width,
        alignment: alignment!,
        color: color,
        placeholder: showLoad ? (context, url) => showLoader(size: 15) : null,
        errorWidget: (context, url, error) => errorWidget ?? _errorWidget(),
      );
    }
  }

  Icon _errorWidget() => Icon(Icons.error, size: 26);

  Widget _showAssetImage() {
    if (image.endsWith('.svg')) {
      const srcIn = BlendMode.srcIn;
      final clr = color == null ? null : ColorFilter.mode(color!, srcIn);
      return SvgPicture.asset(
        image,
        fit: fit!,
        height: height,
        width: width,
        alignment: alignment!,
        colorFilter: clr,
      );
    } else {
      return Image.asset(
        image,
        fit: fit,
        height: height,
        width: width,
        scale: scale,
        alignment: alignment!,
        color: color,
        errorBuilder: (context, error, st) => errorWidget ?? _errorWidget(),
      );
    }
  }

  Widget _svgStringImage() {
    return SvgPicture.string(
      image,
      height: height,
      width: width,
      alignment: alignment!,
    );
  }

  Widget _fileImage() {
    return Image.file(
      File(image),
      fit: fit,
      height: height,
      width: width,
      alignment: alignment!,
      color: color,
    );
  }

  bool isFile(String imagePath) {
    return imagePath.startsWith('file://') ||
        imagePath.startsWith('/storage/') ||
        imagePath.startsWith('/data/');
  }
}
