import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_text_widget.dart';

class TabReminderMesgBubble extends StatelessWidget {
  final String title;
  final String description;
  final String? buttonLabel;
  final String? buttonUrl;
  final String event;
  final String metaText;
  final IconData statusIcon;
  final Color statusColor;
  final bool isMe;

  const TabReminderMesgBubble({
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5), // Light red background
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFD6D6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF3D32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
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
          const SizedBox(height: 10),
          TextWidget(
            text: description,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
          if (buttonLabel != null && buttonLabel!.isNotEmpty) ...[
            const SizedBox(height: 14),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 10),
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
                const SizedBox(width: 5),
                Icon(statusIcon, size: 14, color: statusColor),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
