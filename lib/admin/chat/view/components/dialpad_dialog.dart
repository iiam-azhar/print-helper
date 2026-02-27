import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../widgets/text_widget.dart';
import '../../../../widgets/spacers.dart';
import '../../../../constants/colors.dart';

class DialPadDialog extends StatefulWidget {
  final String fromNumber;
  final Function(String toNumber) onCall;

  const DialPadDialog({
    super.key,
    required this.fromNumber,
    required this.onCall,
  });

  @override
  State<DialPadDialog> createState() => _DialPadDialogState();
}

class _DialPadDialogState extends State<DialPadDialog> {
  String _number = "";
  final _scrollController = ScrollController();

  final Map<String, String> _abcMapping = {
    "1": "",
    "2": "ABC",
    "3": "DEF",
    "4": "GHI",
    "5": "JKL",
    "6": "MNO",
    "7": "PQRS",
    "8": "TUV",
    "9": "WXYZ",
    "*": "",
    "0": "+",
    "#": "",
  };

  void _onKeyTap(String key) {
    setState(() {
      _number += key;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onDelete() {
    if (_number.isNotEmpty) {
      setState(() {
        _number = _number.substring(0, _number.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 1.sw,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextWidget(
              text: "Calling From",
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            TextWidget(
              text: widget.fromNumber,
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            Spacers.sb20(),
            Container(
              height: 50.h,
              alignment: Alignment.center,
              child: GestureDetector(
                onLongPress: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null &&
                      data.text != null &&
                      data.text!.isNotEmpty) {
                    setState(() {
                      final clean = data.text!.replaceAll(
                        RegExp(r'[^0-9+\*\#]'),
                        '',
                      );
                      _number += clean;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });
                  }
                },
                behavior:
                    HitTestBehavior.translucent, // Allow tap on empty space
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: _number.isEmpty
                      ? TextWidget(
                          text: "Enter Number",
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade300,
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: TextWidget(
                            text: _number,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                ),
              ),
            ),
            Spacers.sb20(),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              mainAxisSpacing: 10.h,
              crossAxisSpacing: 10.w,
              physics: const NeverScrollableScrollPhysics(),
              children: _abcMapping.entries.map((entry) {
                return Material(
                  color: Colors.grey.shade100,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => _onKeyTap(entry.key),
                    onLongPress: entry.key == "0"
                        ? () {
                            setState(() {
                              _number += "+";
                            });
                            _scrollToEnd();
                          }
                        : null,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextWidget(
                            text: entry.key,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                          if (entry.value.isNotEmpty)
                            TextWidget(
                              text: entry.value,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Spacers.sb30(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(width: 48.w),
                GestureDetector(
                  onTap: () {
                    if (_number.isNotEmpty) {
                      Navigator.pop(context);
                      widget.onCall(_number);
                    }
                  },
                  child: Container(
                    height: 65.h,
                    width: 65.h,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 10.r,
                          offset: Offset(0, 5.h),
                        ),
                      ],
                    ),
                    child: Icon(Icons.call, color: Colors.white, size: 30.sp),
                  ),
                ),
                IconButton(
                  onPressed: _onDelete,
                  onLongPress: () {
                    setState(() {
                      _number = "";
                    });
                  },
                  icon: Icon(
                    Icons.backspace_outlined,
                    size: 26.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            Spacers.sb10(),
          ],
        ),
      ),
    );
  }
}
