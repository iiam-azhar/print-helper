import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../widgets/text_widget.dart';

class ReminderMesgBubble extends StatelessWidget {
  final String title;
  final String description;
  final String? buttonLabel;
  final String? buttonUrl;
  final String event;
  final String metaText;
  final IconData statusIcon;
  final Color statusColor;
  final bool isMe;

  const ReminderMesgBubble({
    super.key,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.buttonUrl,
    required this.event,
    required this.metaText,
    required this.statusIcon,
    required this.statusColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5), // Light red background
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: const Color(0xFFFFD6D6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF3D32),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.notifications_none_outlined,
                  color: Colors.white,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: event.toUpperCase(),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF3D32),
                    ),
                    SizedBox(height: 4.h),
                    TextWidget(
                      text: title,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          TextWidget(
            text: description,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
          if (buttonLabel != null && buttonLabel!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  if (buttonUrl != null && buttonUrl!.isNotEmpty) {
                    final uri = Uri.parse(buttonUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF3D32),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: TextWidget(
                  text: buttonLabel!,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: TextWidget(
                  text: metaText,
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (isMe) ...[
                SizedBox(width: 5.w),
                Icon(statusIcon, size: 14.sp, color: statusColor),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
