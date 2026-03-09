// lib/widgets/fab_menu.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/text_widget.dart';

class FabMenu extends StatefulWidget {
  final VoidCallback? onUpload;
  final VoidCallback? onNewFolder;
  final VoidCallback? onCamera;

  const FabMenu({super.key, this.onUpload, this.onNewFolder, this.onCamera});

  @override
  State<FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<FabMenu> with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  bool open = false;

  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _removeOverlay();
    _anim.dispose();
    super.dispose();
  }

  void toggle() {
    if (open) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    open = true;
    _overlay = _buildOverlay();
    Overlay.of(context).insert(_overlay!);
    _anim.forward();
    setState(() {});
  }

  void _close() {
    open = false;
    _anim.reverse();
    Future.delayed(const Duration(milliseconds: 180), () {
      _removeOverlay();
    });
    setState(() {});
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: FadeTransition(
              opacity: _fade,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 90.h,
                        right: 12.w,
                        child: SlideTransition(
                          position: _slide,
                          child: _menu(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return open
        ? SizedBox()
        : FloatingActionButton(
            shape: const StadiumBorder(),
            backgroundColor: open ? AppColors.tr : AppColors.primary,
            onPressed: toggle,
            child: Icon(Icons.add, size: 32, color: Colors.white),
          );
  }

  Widget _menu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          mini: true,
          backgroundColor: AppColors.primary,
          onPressed: widget.onCamera,
          child: Icon(CupertinoIcons.camera, size: 24.sp, color: Colors.black),
        ),
        Spacers.sb10(),
        Material(
          color: Colors.white,
          elevation: 8,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: 170.w,
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _item(CupertinoIcons.cloud_upload, "Upload", widget.onUpload),
                Divider(height: 1),
                _item(CupertinoIcons.folder, "New Folder", widget.onNewFolder),
              ],
            ),
          ),
        ),
        Spacers.sb10(),
        FloatingActionButton(
          shape: const StadiumBorder(),
          backgroundColor: Colors.black,
          onPressed: toggle,
          child: Icon(Icons.close, size: 32, color: Colors.white),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: () {
        _close();
        if (onTap != null) onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Icon(icon, size: 24.sp, color: Colors.black87),
            Spacers.sbw12(),
            TextWidget(
              text: label,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
