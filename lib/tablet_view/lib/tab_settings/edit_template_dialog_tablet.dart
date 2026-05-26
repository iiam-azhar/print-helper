import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:print_helper/models/contract_template_model.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/utils/quill_html_converter.dart';
import 'package:print_helper/widgets/quill_editor_widget.dart';
import 'package:provider/provider.dart';

import '../tab_widgets/tab_text_widget.dart' as tab;

Future<void> showEditTemplateDialogTablet(
  BuildContext context,
  ContractTemplateModel item,
) async {
  final nameCtrl = TextEditingController(text: item.name);
  final versionCtrl = TextEditingController(
    text: item.version.replaceAll('v', ''),
  );
  final existingContent = item.content ?? '';
  final Document quillDoc;
  if (existingContent.isNotEmpty) {
    final delta = HtmlToDelta().convert(existingContent);
    quillDoc = Document.fromDelta(delta);
  } else {
    quillDoc = Document();
  }
  final quillCtrl = QuillController(
    document: quillDoc,
    selection: const TextSelection.collapsed(offset: 0),
  );
  final variables = item.variables;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 28,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 680,
              maxHeight: 700,
            ),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  color: Colors.black,
                  child: Row(
                    children: [
                      const tab.TextWidget(
                        text: 'Edit Template',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Body ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Template Name
                        _tabTemplateLabel('TEMPLATE NAME'),
                        const SizedBox(height: 6),
                        _tabTemplateField(controller: nameCtrl),
                        const SizedBox(height: 12),

                        // Version
                        _tabTemplateLabel('VERSION'),
                        const SizedBox(height: 6),
                        _tabTemplateField(controller: versionCtrl),
                        const SizedBox(height: 14),

                        // Template Content
                        _tabTemplateLabel('TEMPLATE CONTENT'),
                        const SizedBox(height: 6),
                        QuillEditorWidget(
                          controller: quillCtrl,
                          placeholder: 'Enter template content...',
                        ),
                        const SizedBox(height: 14),

                        // Available Variables
                        _tabTemplateLabel('AVAILABLE VARIABLES'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFD1D5DB),
                            ),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: variables
                                .map(
                                  (e) => GestureDetector(
                                    onTap: () {
                                      final sel = quillCtrl.selection;
                                      final index = sel.isValid
                                          ? sel.baseOffset
                                          : quillCtrl.document.length - 1;
                                      quillCtrl.document.insert(
                                        index,
                                        '{$e}',
                                      );
                                      quillCtrl.updateSelection(
                                        TextSelection.collapsed(
                                          offset: index + '{$e}'.length,
                                        ),
                                        ChangeSource.local,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFD1D5DB),
                                        ),
                                      ),
                                      child: tab.TextWidget(
                                        text: '{$e}',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const tab.TextWidget(
                          text: 'Tap a variable to insert it at the cursor.',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Footer Actions ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                          context.read<AdminPro>().saveTemplate(
                            type: item.type,
                            name: nameCtrl.text.trim(),
                            version: versionCtrl.text.trim(),
                            content: quillDeltaToHtml(
                              quillCtrl.document.toDelta().toJson(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const tab.TextWidget(
                            text: 'Save Template',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const tab.TextWidget(
                            text: 'Cancel',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  quillCtrl.dispose();
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _tabTemplateLabel(String text) {
  return tab.TextWidget(
    text: text,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF6B7280),
  );
}

Widget _tabTemplateField({required TextEditingController controller}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
      ),
    ),
    style: const TextStyle(
      color: Color(0xFF111827),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
}
