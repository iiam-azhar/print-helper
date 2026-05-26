import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/providers/email_pro.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:provider/provider.dart';

class MobileEmailComposeScreen extends StatefulWidget {
  final String initialTo;
  final String initialSubject;
  final String initialBody;
  final String initialReplyToId;

  const MobileEmailComposeScreen({
    super.key,
    this.initialTo = '',
    this.initialSubject = '',
    this.initialBody = '',
    this.initialReplyToId = '',
  });

  @override
  State<MobileEmailComposeScreen> createState() =>
      _MobileEmailComposeScreenState();
}

class _MobileEmailComposeScreenState extends State<MobileEmailComposeScreen> {
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  final List<String> _toEmails = [];
  final List<String> _ccEmails = [];
  final List<String> _bccEmails = [];
  final List<Map<String, String>> _attachments = [];

  bool _showCc = false;
  bool _showBcc = false;
  bool _isSending = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTo.isNotEmpty) {
      _toEmails.addAll(
        widget.initialTo
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    if (widget.initialSubject.isNotEmpty) {
      _subjectController.text = widget.initialSubject;
    }
    if (widget.initialBody.isNotEmpty) {
      _bodyController.text = widget.initialBody;
    }
  }

  bool get _hasContent =>
      _toEmails.isNotEmpty ||
      _ccEmails.isNotEmpty ||
      _bccEmails.isNotEmpty ||
      _subjectController.text.trim().isNotEmpty ||
      _bodyController.text.trim().isNotEmpty ||
      _attachments.isNotEmpty;

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  static const int _maxFileSizeBytes = 500 * 1024; // 500 KB

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final List<String> rejected = [];
    final List<Map<String, String>> accepted = [];

    for (final file in result.files) {
      final size = file.size;
      if (size > _maxFileSizeBytes) {
        rejected.add(file.name);
      } else {
        accepted.add({'name': file.name, 'path': file.path ?? ''});
      }
    }

    if (accepted.isNotEmpty) {
      setState(() => _attachments.addAll(accepted));
    }

    if (rejected.isNotEmpty) {
      showToast(
        message:
            '${rejected.length} file${rejected.length > 1 ? 's' : ''} exceeded the 500 KB limit and ${rejected.length > 1 ? 'were' : 'was'} not attached.',
      );
    }
  }

  Future<void> _send() async {
    if (_toEmails.isEmpty) {
      showToast(message: 'Please add at least one recipient');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      showToast(message: 'Please enter a subject');
      return;
    }
    setState(() => _isSending = true);
    final success = await context.read<EmailPro>().sendMail(
      context,
      to: _toEmails.join(','),
      cc: _ccEmails.join(','),
      bcc: _bccEmails.join(','),
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      inReplyToId: widget.initialReplyToId,
      attachments: _attachments,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) Navigator.pop(context);
  }

  Future<void> _saveDraft() async {
    setState(() => _isSavingDraft = true);
    final success = await context.read<EmailPro>().saveDraft(
      context,
      to: _toEmails.join(','),
      cc: _ccEmails.join(','),
      bcc: _bccEmails.join(','),
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      attachments: _attachments,
    );
    if (!mounted) return;
    setState(() => _isSavingDraft = false);
    if (success) Navigator.pop(context);
  }

  Future<bool> _onBackPressed() async {
    if (!_hasContent) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Save draft?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Do you want to save this email as a draft before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              'Discard',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              'Save Draft',
              style: TextStyle(
                color: AppColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _saveDraft();
      return false; // _saveDraft already pops
    }
    return result == 'discard';
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0xFFADB5BD), fontSize: 14.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _onBackPressed();
        if (canLeave && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE5E7EB), height: 1),
          ),
          title: Text(
            widget.initialSubject.startsWith('Fwd:')
                ? 'Forward Email'
                : widget.initialReplyToId.isNotEmpty
                ? 'Reply Email'
                : 'New Email',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              final canLeave = await _onBackPressed();
              if (canLeave && mounted) Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 8.w),
                Icon(CupertinoIcons.back, color: AppColors.amber, size: 20.sp),
                Text(
                  'Back',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          leadingWidth: 90.w,
          actions: [
            // Save Draft button
            if (_isSavingDraft)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.amber,
                  ),
                ),
              )
            else
              CupertinoButton(
                padding: EdgeInsets.only(right: 4.w, left: 8.w),
                onPressed: _saveDraft,
                child: Text(
                  'Save Draft',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // To field
              _ComposeEmailField(
                controller: _toController,
                emails: _toEmails,
                onChanged: (v) => setState(() {
                  _toEmails
                    ..clear()
                    ..addAll(v);
                }),
                hintText: 'To',
              ),
              SizedBox(height: 8.h),

              // CC / BCC toggles
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showCc = !_showCc),
                    child: Text(
                      _showCc ? 'Hide CC' : 'Add CC',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  GestureDetector(
                    onTap: () => setState(() => _showBcc = !_showBcc),
                    child: Text(
                      _showBcc ? 'Hide BCC' : 'Add BCC',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (_showCc) ...[
                SizedBox(height: 8.h),
                _ComposeEmailField(
                  controller: _ccController,
                  emails: _ccEmails,
                  onChanged: (v) => setState(() {
                    _ccEmails
                      ..clear()
                      ..addAll(v);
                  }),
                  hintText: 'CC',
                ),
              ],

              if (_showBcc) ...[
                SizedBox(height: 8.h),
                _ComposeEmailField(
                  controller: _bccController,
                  emails: _bccEmails,
                  onChanged: (v) => setState(() {
                    _bccEmails
                      ..clear()
                      ..addAll(v);
                  }),
                  hintText: 'BCC',
                ),
              ],

              SizedBox(height: 10.h),
              TextField(
                controller: _subjectController,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF111827),
                ),
                decoration: _fieldDecoration('Subject'),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _bodyController,
                maxLines: 9,
                minLines: 9,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF111827),
                ),
                decoration: _fieldDecoration('Message').copyWith(
                  contentPadding: EdgeInsets.all(14.w),
                  alignLabelWithHint: true,
                ),
              ),
              SizedBox(height: 14.h),

              // Attach files button
              GestureDetector(
                onTap: _pickFiles,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 11.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 18.sp,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Attach files',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_attachments.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _attachments.asMap().entries.map((entry) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 14.sp,
                            color: AppColors.amber,
                          ),
                          SizedBox(width: 5.w),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 160.w),
                            child: Text(
                              entry.value['name'] ?? 'Attachment',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () => setState(
                              () => _attachments.removeAt(entry.key),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14.sp,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    disabledBackgroundColor: AppColors.amber.withValues(
                      alpha: 0.6,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: _isSending
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 18.sp,
                          color: Colors.white,
                        ),
                  label: Text(
                    'Send Mail',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // PopScope
    );
  }
}

// ─── Chip-based email recipient input ────────────────────────────────────────

class _ComposeEmailField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> emails;
  final ValueChanged<List<String>> onChanged;
  final String hintText;

  const _ComposeEmailField({
    required this.controller,
    required this.emails,
    required this.onChanged,
    required this.hintText,
  });

  @override
  State<_ComposeEmailField> createState() => _ComposeEmailFieldState();
}

class _ComposeEmailFieldState extends State<_ComposeEmailField> {
  void _addEmail() {
    final value = widget.controller.text.trim().replaceAll(',', '');
    if (value.isEmpty) return;
    final exists = widget.emails.any(
      (e) => e.toLowerCase() == value.toLowerCase(),
    );
    if (!exists) widget.onChanged([...widget.emails, value]);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 6.w,
        runSpacing: 6.h,
        children: [
          ...widget.emails.map(
            (email) => Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: () {
                      final updated = List<String>.from(widget.emails)
                        ..remove(email);
                      widget.onChanged(updated);
                    },
                    child: Icon(
                      Icons.close,
                      size: 13.sp,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 190.w,
            child: TextField(
              controller: widget.controller,
              onSubmitted: (_) => _addEmail(),
              onChanged: (value) {
                if (value.endsWith(',') || value.endsWith(' ')) _addEmail();
              },
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF111827)),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.emails.isEmpty ? widget.hintText : '',
                hintStyle: TextStyle(
                  color: const Color(0xFFADB5BD),
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
