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

  String _getCacheKey(String url) {
    if (url.contains('amazonaws.com') ||
        url.contains('X-Amz-') ||
        url.contains('response-content-')) {
      final index = url.indexOf('?');
      if (index != -1) {
        return url.substring(0, index);
      }
    }
    return url;
  }

  bool _isSvg(String path) {
    final cleanPath = path.toLowerCase().split('?').first;
    return cleanPath.endsWith('.svg');
  }

  Widget _showNetworkImage() {
    if (_isSvg(image)) {
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
        errorBuilder:
            (context, error, stackTrace) => errorWidget ?? _errorWidget(),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: image,
        cacheKey: _getCacheKey(image),
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

  Widget _errorWidget() => Image.asset(
    'assets/images/user.png',
    height: height,
    width: width,
    fit: fit ?? BoxFit.contain,
  );

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
