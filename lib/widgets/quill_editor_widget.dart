import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuillEditorWidget extends StatefulWidget {
  const QuillEditorWidget({
    super.key,
    required this.controller,
    this.editorHeight = 260,
    this.placeholder = 'Enter content...',
  });

  final QuillController controller;
  final double editorHeight;
  final String placeholder;

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          QuillSimpleToolbar(
            controller: widget.controller,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: true,
              showDividers: false,
              showFontFamily: false,
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showListBullets: true,
              showListCheck: false,
              showListNumbers: true,
              showLink: true,
              showUndo: false,
              showRedo: false,
              showClearFormat: false,
              showHeaderStyle: true,
              showBackgroundColorButton: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              toolbarRunSpacing: 0,
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: widget.editorHeight,
            child: QuillEditor.basic(
              controller: widget.controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                placeholder: widget.placeholder,
                padding: const EdgeInsets.all(12),
                expands: false,
                scrollable: true,
                autoFocus: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
