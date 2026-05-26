import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:print_helper/admin/email/mobile_email_compose_screen.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/models/email_models.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileEmailDetailScreen extends StatefulWidget {
  final EmailMessage message;

  const MobileEmailDetailScreen({super.key, required this.message});

  @override
  State<MobileEmailDetailScreen> createState() =>
      _MobileEmailDetailScreenState();
}

class _MobileEmailDetailScreenState extends State<MobileEmailDetailScreen> {
  double _webViewHeight = 300;

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final url = attachment['download_url']?.toString();
    if (url == null || url.isEmpty) {
      showToast(message: 'Attachment URL not found');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[(dt.month - 1).clamp(0, 11)];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$month ${dt.day}, ${dt.year}, $hour12:$minute $amPm';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8),
              Icon(CupertinoIcons.back, color: AppColors.amber, size: 20),
              Text(
                'Back',
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 90,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.forward_to_inbox_rounded,
              color: Color(0xFF374151),
            ),
            tooltip: 'Forward',
            onPressed: () {
              final forwardSubject =
                  msg.subject.toLowerCase().startsWith('fwd:')
                  ? msg.subject
                  : 'Fwd: ${msg.subject}';
              final forwardBody =
                  '\n\n---------- Forwarded message ----------\n'
                  'From: ${msg.from}\n'
                  'Date: ${_formatDate(msg.date)}\n'
                  'Subject: ${msg.subject}\n'
                  'To: ${msg.to}\n\n'
                  '${msg.body.replaceAll(RegExp(r'<[^>]*>'), '')}';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileEmailComposeScreen(
                    initialSubject: forwardSubject,
                    initialBody: forwardBody,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.reply_rounded, color: Color(0xFF374151)),
            tooltip: 'Reply',
            onPressed: () {
              final replySubject = msg.subject.toLowerCase().startsWith('re:')
                  ? msg.subject
                  : 'Re: ${msg.subject}';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileEmailComposeScreen(
                    initialTo: msg.fromEmail.isNotEmpty
                        ? msg.fromEmail
                        : msg.from,
                    initialSubject: replySubject,
                    initialReplyToId: msg.id,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject
            Text(
              msg.subject.isEmpty ? '(No Subject)' : msg.subject,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),

            // Sender row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.amber.withValues(alpha: 0.15),
                  child: Text(
                    _initial(msg.from),
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.from,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To: ${msg.to}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(msg.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF3F4F6)),
            const SizedBox(height: 4),

            // HTML body via WebView
            SizedBox(
              height: _webViewHeight,
              child: InAppWebView(
                initialData: InAppWebViewInitialData(data: msg.body),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: false,
                  javaScriptEnabled: true,
                  disableVerticalScroll: true,
                  disableHorizontalScroll: false,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  supportZoom: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: false,
                ),
                onWebViewCreated: (controller) {
                  controller.addJavaScriptHandler(
                    handlerName: 'UpdateHeight',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        final h = double.tryParse(args[0].toString());
                        if (h != null && h > 0 && h != _webViewHeight) {
                          setState(() => _webViewHeight = h + 20);
                        }
                      }
                    },
                  );
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                    source: """
                    (function() {
                      // Inject viewport meta for proper mobile scaling
                      var existing = document.querySelector('meta[name="viewport"]');
                      if (!existing) {
                        var meta = document.createElement('meta');
                        meta.name = 'viewport';
                        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
                        document.head.appendChild(meta);
                      } else {
                        existing.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
                      }

                      // Force white background and remove excess spacing
                      var style = document.createElement('style');
                      style.textContent = 'html, body { background: #ffffff !important; margin: 0 !important; padding: 0 !important; }';
                      document.head.appendChild(style);

                      var sent = false;
                      function sendHeight() {
                        if (sent) return;
                        var height = Math.max(
                          document.body.scrollHeight,
                          document.documentElement.scrollHeight,
                          document.body.offsetHeight,
                          document.documentElement.offsetHeight
                        );
                        if (height > 0) {
                          sent = true;
                          window.flutter_inappwebview.callHandler('UpdateHeight', height);
                        }
                      }
                      setTimeout(sendHeight, 300);
                    })();
                  """,
                  );
                },
              ),
            ),

            // Attachments
            if (msg.attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'ATTACHMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              ...msg.attachments.map(
                (att) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: Color(0xFF374151),
                    ),
                  ),
                  title: Text(
                    (att['name'] ?? 'Attachment').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.amber,
                    ),
                    onPressed: () => _openAttachment(att),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
