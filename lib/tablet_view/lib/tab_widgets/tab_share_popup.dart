import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_text_widget.dart'
    as tab_text;

class TabSharePopup extends StatelessWidget {
  final VoidCallback onEmail;
  final VoidCallback onChat;

  const TabSharePopup({super.key, required this.onEmail, required this.onChat});

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onEmail,
    required VoidCallback onChat,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return TabSharePopup(onEmail: onEmail, onChat: onChat);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const tab_text.TextWidget(
                text: 'Share',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 10),
              const tab_text.TextWidget(
                text:
                    'Choose where you want to share this item now. More apps can be added here later.',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xff6f7785),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onEmail();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xffcfd4dc)),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xfff1f3f7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.mail,
                                size: 22,
                                color: Color(0xff4e596c),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const tab_text.TextWidget(
                                    text: 'Email',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: 4),
                                  const tab_text.TextWidget(
                                    text: 'Send via email',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xff6f7785),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onChat();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xfff3e275)),
                          color: const Color(0xfffffbea),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xfff3e275),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.chat_bubble_2,
                                size: 22,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const tab_text.TextWidget(
                                    text: 'Chat',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  const SizedBox(height: 4),
                                  const tab_text.TextWidget(
                                    text: 'Share to conversation',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xff6f7785),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
