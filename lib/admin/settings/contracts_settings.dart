import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import '../../widgets/quill_editor_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/colors.dart';
import '../../models/contract_template_model.dart';
import '../../models/standard_rule_model.dart';
import '../../models/contracts_models.dart';
import '../../models/checklist_model.dart';
import '../../constants/paths.dart';
import '../../providers/admin_pro.dart';
import '../../utils/quill_html_converter.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/rule_icon.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/loaders.dart';
import '../../widgets/toasts.dart';
import '../../services/api_routes.dart';
import 'contracts_dialog_sections.dart';

class ContractsSettingsMobile extends StatefulWidget {
  const ContractsSettingsMobile({super.key});

  @override
  State<ContractsSettingsMobile> createState() =>
      _ContractsSettingsMobileState();
}

class _ContractsSettingsMobileState extends State<ContractsSettingsMobile> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  final List<String> _sections = const [
    'Contracts & Agreements',
    'Templates',
    'Specialist Standards',
    'Client Standards',
    'Check Lists',
  ];

  int _activeSection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminPro>().getContracts(ctx: context, page: 1);
      context.read<AdminPro>().getTemplates();
      context.read<AdminPro>().getRules(type: 'specialist');
      context.read<AdminPro>().getRules(type: 'client');
      context.read<AdminPro>().getChecklists();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ChecklistModel> _getCheckLists() {
    return context.read<AdminPro>().checklists;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 18.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section tabs
            _buildSectionTabs(),
            // Content based on active section
            if (_activeSection == 0)
              _buildContractsContent()
            else if (_activeSection == 1)
              _buildTemplatesContent()
            else if (_activeSection == 2)
              _buildSpecialistStandardsContent()
            else if (_activeSection == 3)
              _buildClientStandardsContent()
            else
              _buildCheckListsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_sections.length, (index) {
            final isActive = _activeSection == index;
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () => setState(() => _activeSection = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: isActive
                          ? Colors.grey.shade300
                          : Colors.transparent,
                    ),
                  ),
                  child: TextWidget(
                    text: _sections[index],
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContractsContent() {
    return Consumer<AdminPro>(
      builder: (context, pro, _) {
        final rows = pro.contracts;
        final clientUnsigned = (pro.clientTotal - pro.clientAgreementsSigned)
            .clamp(0, pro.clientTotal)
            .toInt();
        final specialistUnsigned =
            (pro.specialistTotal - pro.specialistContractsSigned)
                .clamp(0, pro.specialistTotal)
                .toInt();

        return Padding(
          padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 220.w,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            if (!mounted) return;
                            context.read<AdminPro>().getContracts(
                              ctx: context,
                              page: 1,
                              search: value,
                            );
                          },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade500,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _searchDebounce?.cancel();
                        if (!mounted) return;
                        context.read<AdminPro>().getContracts(
                          ctx: context,
                          page: 1,
                          search: '',
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextWidget(
                          text: 'Clear',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 12.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _summaryCard(
                      width: 230.w,
                      title: 'CLIENT AGREEMENTS',
                      value: '${pro.clientTotal}',
                      subtitle: '$clientUnsigned unsigned',
                      topColor: const Color(0xFF22C55E),
                    ),
                    SizedBox(width: 8.w),
                    _summaryCard(
                      width: 230.w,
                      title: 'SPECIALIST CONTRACTS',
                      value: '${pro.specialistTotal}',
                      subtitle: '$specialistUnsigned unsigned',
                      topColor: const Color(0xFF22C55E),
                    ),
                    SizedBox(width: 8.w),
                    _summaryCard(
                      width: 230.w,
                      title: 'UNSIGNED',
                      value: '${pro.totalUnsigned}',
                      subtitle: pro.oldestUnsignedText.trim().isEmpty
                          ? 'No overdue contracts'
                          : pro.oldestUnsignedText,
                      topColor: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              if (pro.contractsLoad && rows.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (rows.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: TextWidget(
                    text: 'No contracts found',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                )
              else
                Column(
                  children: [
                    ...List.generate(rows.length, (index) {
                      return _contractCard(rows[index]);
                    }),
                    SizedBox(height: 4.h),
                    _buildContractsPagination(pro),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecialistStandardsContent() {
    return Consumer<AdminPro>(
      builder: (context, pro, _) {
        if (pro.specialistRulesLoad) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'These rules display in the specialist portal. Changes appear immediately.',
                buttonLabel: 'Add Rule',
                onTap: _showAddRuleDialog,
              ),
              SizedBox(height: 14.h),
              if (pro.specialistRules.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: TextWidget(
                      text: 'No specialist rules found.',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                Column(
                  children: pro.specialistRules
                      .map((rule) => _specialistStandardRuleCard(rule))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionIntro({
    required String message,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 540.w;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: message,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: _greenAddButton(label: buttonLabel, onTap: onTap),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: TextWidget(
                text: message,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                maxLines: 2,
              ),
            ),
            SizedBox(width: 10.w),
            _greenAddButton(label: buttonLabel, onTap: onTap),
          ],
        );
      },
    );
  }

  Future<void> _showAddRuleDialog() async {
    final res = await ContractsDialogSections.showAddRuleDialog(context);
    if (res == true) {
      if (mounted) {
        context.read<AdminPro>().getRules(type: 'specialist');
      }
    }
  }

  Future<void> _showManageCategoriesDialog() async {
    await ContractsDialogSections.showManageCategoriesDialog(context);
  }

  Widget _greenAddButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 16),
            SizedBox(width: 4.w),
            TextWidget(
              text: label,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _specialistStandardRuleCard(final StandardRuleModel rule) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ruleIconBox(rule),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: rule.title,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    SizedBox(height: 6.h),
                    if (rule.categoryName != null) ...[
                      _softChip(
                        label: rule.categoryName!.isEmpty
                            ? 'Uncategorized'
                            : rule.categoryName!,
                        backgroundColor: const Color(0xFFF4F4F5),
                        textColor: Colors.grey.shade700,
                      ),
                    ] else ...[
                      _softChip(
                        label: 'Uncategorized',
                        backgroundColor: const Color(0xFFF4F4F5),
                        textColor: Colors.grey.shade700,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _buildToggleSwitch(rule, 'specialist'),
            ],
          ),
          SizedBox(height: 8.h),
          TextWidget(
            text: rule.description,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
            maxLines: 3,
          ),
          SizedBox(height: 12.h),
          _sectionActionRow(rule, 'specialist'),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch(StandardRuleModel rule, String type) {
    final isActive = rule.isActive;
    return GestureDetector(
      onTap: () {
        context.read<AdminPro>().toggleRuleStatus(
              ruleId: rule.id,
              newStatus: !rule.isActive,
              type: type,
            );
      },
      child: Container(
        width: 48.w,
        height: 29,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Align(
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 2.w),
            width: 23.w,
            height: 23.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesContent() {
    return Consumer<AdminPro>(
      builder: (context, pro, _) {
        if (pro.templatesLoad) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final templates = [
          if (pro.clientTemplate != null) pro.clientTemplate!,
          if (pro.staffTemplate != null) pro.staffTemplate!,
        ];
        if (templates.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 12.w),
            child: TextWidget(
              text: 'No templates found',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 12.h),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 720.w;
              if (!useTwoColumns) {
                return Column(
                  children: List.generate(templates.length, (index) {
                    return _templateCard(templates[index]);
                  }),
                );
              }
              final List<Widget> rows = [];
              for (int i = 0; i < templates.length; i += 2) {
                final left = templates[i];
                final right = i + 1 < templates.length
                    ? templates[i + 1]
                    : null;
                rows.add(
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _templateCard(left, hasBottomMargin: false),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: right != null
                              ? _templateCard(right, hasBottomMargin: false)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
        );
      },
    );
  }

  Widget _templateCard(
    ContractTemplateModel item, {
    bool hasBottomMargin = true,
  }) {
    return Container(
      margin: hasBottomMargin ? EdgeInsets.only(bottom: 12.h) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 330.w;
              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: item.name,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        TextWidget(
                          text: 'Template ${item.versionLabel}',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                        TextWidget(
                          text: ' · ${item.statusLabel}',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF22C55E),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: item.name,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                TextWidget(
                                  text: 'Template ${item.versionLabel}',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                                TextWidget(
                                  text: ' · ${item.statusLabel}',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF22C55E),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12.h),
          _templateTextBlock(label: 'Variables', text: item.variablesText),
          SizedBox(height: 8.h),
          _templateTextBlock(label: 'Clauses', text: item.clausesText),
          SizedBox(height: 10.h),
          Center(
            child: _editTemplateButton(
              onTap: () => _showEditTemplateDialog(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editTemplateButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: const TextWidget(
          text: 'Edit Template',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showEditTemplateDialog(ContractTemplateModel item) async {
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: DraggableScrollableSheet(
                initialChildSize: 0.92,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollController) {
                  return ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20.r),
                    ),
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            color: Colors.black,
                            child: Row(
                              children: [
                                const TextWidget(
                                  text: 'Edit Template',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => Navigator.pop(sheetContext),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                18.w,
                                18.h,
                                18.w,
                                12.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _editDialogField(
                                    label: 'TEMPLATE NAME',
                                    controller: nameCtrl,
                                  ),
                                  SizedBox(height: 12.h),
                                  _editDialogField(
                                    label: 'VERSION',
                                    controller: versionCtrl,
                                  ),
                                  SizedBox(height: 14.h),
                                  TextWidget(
                                    text: 'TEMPLATE CONTENT',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                  SizedBox(height: 6.h),
                                  QuillEditorWidget(
                                    controller: quillCtrl,
                                    placeholder: 'Enter template content...',
                                  ),
                                  SizedBox(height: 14.h),
                                  TextWidget(
                                    text: 'AVAILABLE VARIABLES',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                  SizedBox(height: 6.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(10.w),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: const Color(0xFFD1D5DB),
                                      ),
                                      color: const Color(0xFFF9FAFB),
                                    ),
                                    child: Wrap(
                                      spacing: 8.w,
                                      runSpacing: 8.h,
                                      children: variables
                                          .map(
                                            (e) => GestureDetector(
                                              onTap: () {
                                                final sel = quillCtrl.selection;
                                                final index = sel.isValid
                                                    ? sel.baseOffset
                                                    : quillCtrl
                                                              .document
                                                              .length -
                                                          1;
                                                quillCtrl.document.insert(
                                                  index,
                                                  '{$e}',
                                                );
                                                quillCtrl.updateSelection(
                                                  TextSelection.collapsed(
                                                    offset:
                                                        index + '{$e}'.length,
                                                  ),
                                                  ChangeSource.local,
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        4.r,
                                                      ),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFD1D5DB,
                                                    ),
                                                  ),
                                                ),
                                                child: TextWidget(
                                                  text: '{$e}',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(
                                                    0xFF111827,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  TextWidget(
                                    text:
                                        'Tap a variable to insert it at the cursor.',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                  SizedBox(height: 20.h),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              18.w,
                              0,
                              18.w,
                              MediaQuery.of(sheetContext).padding.bottom + 14.h,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetContext);
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18.w,
                                      vertical: 9.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: const TextWidget(
                                      text: 'Save Template',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                GestureDetector(
                                  onTap: () => Navigator.pop(sheetContext),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18.w,
                                      vertical: 9.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: const TextWidget(
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
                  );
                },
              ),
            );
          },
        );
      },
    );
    quillCtrl.dispose();
  }

  Widget _editDialogField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editorTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF111827) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF111827) : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownPreview(String raw) {
    if (raw.trim().isEmpty) {
      return Text(
        'Nothing to preview.',
        style: TextStyle(
          fontSize: 12.sp,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final lines = raw.split('\n');
    final spans = <Widget>[];
    for (final line in lines) {
      spans.add(_renderMarkdownLine(line));
      spans.add(SizedBox(height: 4.h));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  Widget _renderMarkdownLine(String line) {
    if (line.startsWith('### ')) {
      return Text(
        line.substring(4),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111827),
        ),
      );
    } else if (line.startsWith('## ')) {
      return Text(
        line.substring(3),
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111827),
        ),
      );
    } else if (line.startsWith('# ')) {
      return Text(
        line.substring(2),
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111827),
        ),
      );
    } else {
      return Text.rich(
        _parseInlineMarkdown(line),
        style: TextStyle(fontSize: 12.sp, color: const Color(0xFF374151)),
      );
    }
  }

  TextSpan _parseInlineMarkdown(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|\[(.+?)\]\((.+?)\)',
    );
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (m.group(2) != null) {
        // __underline__
        spans.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        );
      } else if (m.group(3) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(4) != null) {
        // [text](url)
        spans.add(
          TextSpan(
            text: m.group(4),
            style: const TextStyle(
              color: Color(0xFF2563EB),
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(children: spans);
  }

  void _applyHeadingStyle(TextEditingController ctrl, String style) {
    final text = ctrl.text;
    final sel = ctrl.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    int lineStart = offset > 0 ? text.lastIndexOf('\n', offset - 1) : -1;
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = text.indexOf('\n', offset);
    if (lineEnd == -1) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);
    final stripped = line.replaceFirst(RegExp(r'^#{1,3} '), '');
    String prefix = '';
    if (style == 'Heading 1') {
      prefix = '# ';
    } else if (style == 'Heading 2')
      prefix = '## ';
    else if (style == 'Heading 3')
      prefix = '### ';
    final newLine = '$prefix$stripped';
    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    ctrl.value = ctrl.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
  }

  void _insertWrap(TextEditingController ctrl, String before, String after) {
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (!sel.isValid || sel.isCollapsed) {
      final offset = sel.isValid ? sel.baseOffset : text.length;
      final newText = text.replaceRange(offset, offset, '$before$after');
      ctrl.value = ctrl.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + before.length),
      );
    } else {
      final selected = sel.textInside(text);
      final newText = text.replaceRange(
        sel.start,
        sel.end,
        '$before$selected$after',
      );
      ctrl.value = ctrl.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + before.length + selected.length + after.length,
        ),
      );
    }
  }

  void _insertAtCursor(TextEditingController ctrl, String insert) {
    final sel = ctrl.selection;
    final text = ctrl.text;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    final end = sel.isValid ? sel.extentOffset : offset;
    final newText = text.replaceRange(offset, end, insert);
    ctrl.value = ctrl.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + insert.length),
    );
  }

  Future<void> _showLinkDialog(
    BuildContext ctx,
    TextEditingController contentCtrl,
  ) async {
    final urlCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Insert Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(labelText: 'Link Text'),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final linkText = textCtrl.text.isNotEmpty
                  ? textCtrl.text
                  : urlCtrl.text;
              _insertAtCursor(contentCtrl, '[$linkText](${urlCtrl.text})');
              Navigator.pop(c);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  Widget _toolbarIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(right: 10.w),
        child: Icon(
          icon,
          size: 15.sp,
          color: onTap != null
              ? const Color(0xFF1F2937)
              : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Widget _templateTextBlock({required String label, required String text}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
          children: [
            TextSpan(
              text: text,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientStandardsContent() {
    return Consumer<AdminPro>(
      builder: (context, pro, _) {
        if (pro.clientRulesLoad) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'These standards display in the client portal. Changes appear immediately.',
                buttonLabel: 'Add Standard',
                onTap: _showAddStandardDialog,
              ),
              SizedBox(height: 14.h),
              if (pro.clientRules.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: TextWidget(
                      text: 'No client standards found.',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                Column(
                  children: pro.clientRules
                      .map((rule) => _clientStandardCard(rule))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddStandardDialog() async {
    final res = await ContractsDialogSections.showAddStandardDialog(context);
    if (res == true) {
      if (mounted) {
        context.read<AdminPro>().getRules(type: 'client');
      }
    }
  }

  Future<void> _showEditStandardDialog(StandardRuleModel rule, String type) async {
    final res = await ContractsDialogSections.showEditStandardDialog(context, rule);
    if (res == true) {
      if (mounted) {
        context.read<AdminPro>().getRules(type: type);
      }
    }
  }

  Future<void> _showAddCheckListDialog() async {
    final res = await ContractsDialogSections.showAddCheckListDialog(context);
    if (res == true) {
      if (mounted) {
        context.read<AdminPro>().getChecklists();
      }
    }
  }

  Widget _buildCheckListsContent() {
    return Consumer<AdminPro>(
      builder: (context, pro, _) {
        if (pro.checklistsLoad) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'Manage onboarding and training checklists for different user types.',
                buttonLabel: 'Add Check List',
                onTap: _showAddCheckListDialog,
              ),
              SizedBox(height: 14.h),
              if (pro.checklists.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: TextWidget(
                      text: 'No checklists found.',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                Column(
                  children: pro.checklists.map((item) {
                    return _checkListCard(item);
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _clientStandardCard(final StandardRuleModel rule) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ruleIconBox(rule),
              SizedBox(width: 12.w),
              Expanded(child: _clientStandardPrimaryInfo(rule)),
              SizedBox(width: 12.w),
              _buildToggleSwitch(rule, 'client'),
            ],
          ),
          SizedBox(height: 8.h),
          TextWidget(
            text: rule.description,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
            maxLines: 2,
          ),
          SizedBox(height: 10.h),
          _sectionActionRow(rule, 'client'),
        ],
      ),
    );
  }

  Widget _clientStandardPrimaryInfo(StandardRuleModel rule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: rule.title, fontSize: 14, fontWeight: FontWeight.w700),
        SizedBox(height: 6.h),
        _softChip(
          label: rule.categoryName ?? 'Uncategorized',
          backgroundColor: const Color(0xFFF4F4F5),
          textColor: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _checkListCard(final ChecklistModel item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD7DCE2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionIcon(
                icon: item.iconName,
                svgUrl: item.iconSvgUrl,
                colorHex: item.colorHex,
              ),
              SizedBox(width: 12.w),
              Expanded(child: _checkListPrimaryInfo(item)),
            ],
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(left: 56.w),
            child: _checkListMetaBar(item.itemsCount),
          ),
          SizedBox(height: 12.h),
          _checkListActionRow(item),
        ],
      ),
    );
  }

  Widget _checkListPrimaryInfo(ChecklistModel item) {
    bool isTraining = item.listType.toLowerCase().contains('training');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: item.name, fontSize: 14, fontWeight: FontWeight.w700),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _checkListInfoPill(
              label: 'Type',
              value: item.listType,
              backgroundColor: isTraining ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
              valueColor: isTraining ? const Color(0xFF92400E) : const Color(0xFF2563EB),
            ),
            _checkListInfoPill(
              label: 'User Type',
              value: item.userType,
              backgroundColor: const Color(0xFFF4F4F5),
              valueColor: Colors.grey.shade700,
            ),
          ],
        ),
      ],
    );
  }

  Widget _ruleIconBox(StandardRuleModel rule) {
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: RuleIcon(
        svgUrl: rule.iconSvgUrl,
        colorHex: rule.colorHex,
        size: 20,
      ),
    );
  }

  Widget _sectionIcon({String? icon, String? svgUrl, String? colorHex}) {
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: svgUrl != null && svgUrl.isNotEmpty
          ? SvgPicture.network(
              svgUrl,
              width: 20.sp,
              height: 20.sp,
              placeholderBuilder: (context) => SizedBox(
                width: 14.sp,
                height: 14.sp,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              colorFilter: ColorFilter.mode(
                colorHex != null
                    ? Color(int.parse(colorHex.replaceAll('#', '0xFF')))
                    : const Color(0xFF6B7280),
                BlendMode.srcIn,
              ),
            )
          : Text(icon ?? '', style: TextStyle(fontSize: 18.sp)),
    );
  }

  Widget _checkListMetaBar(int count) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _checkListInfoPill(
          label: 'Items',
          value: '$count items',
          backgroundColor: const Color(0xFFEEF0F3),
          valueColor: const Color(0xFF6B7280),
        ),
      ],
    );
  }

  Widget _checkListInfoPill({
    required String label,
    required String value,
    required Color backgroundColor,
    required Color valueColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextWidget(
            text: '$label: ',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
          TextWidget(
            text: value,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ],
      ),
    );
  }

  Widget _itemsBadge(int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: TextWidget(
        text: '$count items',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280),
      ),
    );
  }

  Widget _checkListActionRow(ChecklistModel checklist) {
    return Row(
      children: [
        Expanded(
          child: _checkListActionButton(
            label: 'Edit',
            bgColor: const Color(0xFFE9EAEC),
            textColor: const Color(0xFF6B7280),
            imagePath: Paths.edit,
            onTap: () async {
              final res = await ContractsDialogSections.showAddCheckListDialog(
                context,
                existingChecklist: checklist,
              );
              if (res == true) {
                if (mounted) {
                  context.read<AdminPro>().getChecklists();
                }
              }
            },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _checkListActionButton(
            label: 'Delete',
            bgColor: const Color(0xFFFBEAEC),
            textColor: const Color(0xFFEF4444),
            imagePath: Paths.delete,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Checklist'),
                  content: const Text(
                      'Are you sure you want to delete this checklist?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!mounted) return;
                Loaders.show();
                try {
                  final res = await context
                      .read<AdminPro>()
                      .deleteChecklist(checklist.id);
                  if (!mounted) return;
                  Loaders.hide(); // Hide loader
                  if (res) {
                    context.read<AdminPro>().getChecklists();
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(context);
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _checkListActionButton({
    required String label,
    required Color bgColor,
    required Color textColor,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ImageWidget(image: imagePath, width: 14, height: 14),
            SizedBox(width: 6.w),
            TextWidget(
              text: label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _softChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: TextWidget(
        text: label,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  Widget _sectionActionRow(StandardRuleModel rule, String type) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showEditStandardDialog(rule, type),
            child: _outlineActionButton(
              label: 'Edit',
              color: const Color(0xFF4B5563),
              imagePath: Paths.edit,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: GestureDetector(
            onTap: () => _deleteRule(rule.id, type),
            child: _outlineActionButton(
              label: 'Delete',
              color: const Color(0xFFEF4444),
              imagePath: Paths.delete,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteRule(int id, String type) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (res == true) {
      if (mounted) {
        context.read<AdminPro>().deleteRule(id, type);
      }
    }
  }

  Widget _outlineActionButton({
    required String label,
    required Color color,
    required String imagePath,
  }) {
    final isDelete = color == const Color(0xFFEF4444);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: isDelete ? const Color(0xFFFFF1F2) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isDelete ? const Color(0xFFFECDD3) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ImageWidget(image: imagePath, width: 14, height: 14),
          SizedBox(width: 6.w),
          TextWidget(
            text: label,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required Color topColor,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          top: BorderSide(color: topColor, width: 4.w),
        ),
      ),
      child: Card(
        margin: EdgeInsets.only(top: 0, bottom: 2, left: 1, right: 1),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: title,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(height: 4.h),
                  TextWidget(
                    text: value,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  SizedBox(height: 2.h),
                  TextWidget(
                    text: subtitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsPagination(AdminPro pro) {
    final hasMore = pro.contractsCurrentPage < pro.contractsLastPage;
    if (!hasMore && !pro.isContractsLoadingMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Column(
        children: [
          if (pro.isContractsLoadingMore)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: const CircularProgressIndicator(),
            )
          else
            GestureDetector(
              onTap: () {
                context.read<AdminPro>().getContracts(
                  ctx: context,
                  page: pro.contractsCurrentPage + 1,
                  loadMore: true,
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.expand_more, size: 18.sp, color: Colors.black87),
                    SizedBox(width: 6.w),
                    const TextWidget(
                      text: 'Load more',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 6.h),
          TextWidget(
            text:
                'Page ${pro.contractsCurrentPage} of ${pro.contractsLastPage}',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _contractCard(final ContractAgreementModel row) {
    final bgColor = row.isSigned ? Colors.white : const Color(0xFFFFF4F4);
    final signedLabel = _formatSignedDate(row.signedAt);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: row.isSigned ? Colors.grey.shade300 : const Color(0xFFFFD6D6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: row.name,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      SizedBox(height: 2.h),
                      TextWidget(
                        text: row.subtitle,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _typeChip(
                  label: row.type,
                  color: row.type.toLowerCase() == 'client'
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  textColor: row.type.toLowerCase() == 'client'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFA16207),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _infoRow(
                        label: 'Signed',
                        value: signedLabel,
                        isAlert: !row.isSigned,
                      ),
                    ),
                    Expanded(
                      child: _infoRow(
                        label: 'Template',
                        value: row.template.isEmpty ? '-' : row.template,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _infoRow(label: 'IP Address', value: row.ipAddress ?? '-'),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: row.isSigned
                      ? _pdfActionButton(row: row)
                      : _reminderActionButton(row),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool isAlert = false,
  }) {
    return Row(
      children: [
        TextWidget(
          text: '$label: ',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        Expanded(
          child: TextWidget(
            text: value,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isAlert ? const Color(0xFFEF4444) : Colors.black,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatSignedDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Not signed';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
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
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  Widget _typeChip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: TextWidget(
          text: label,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _pdfActionButton({required ContractAgreementModel row}) {
    return GestureDetector(
      onTap: () {
        final parts = row.id.split('_');
        if (parts.length < 2) {
          showToast(message: 'Invalid contract ID');
          return;
        }

        final typeKey = parts[0].toLowerCase();
        final numericId = parts[1];

        final endpoint = typeKey == 'client'
            ? 'clients/$numericId/agreement-pdf'
            : 'accounts/$numericId/agreement-pdf';

        final fullUrl = '${ApiRoutes.baseUrl}$endpoint';
        final fileName = 'Contract_${row.id}';
        debugPrint("PDF DOWNLOAD URL: $fullUrl");

        context.read<AdminPro>().downloadContractPdf(
              url: fullUrl,
              fileName: fileName,
            );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_rounded,
              size: 16.sp,
              color: Colors.grey.shade700,
            ),
            SizedBox(width: 6.w),
            TextWidget(
              text: 'Download PDF',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderActionButton(ContractAgreementModel row) {
    return GestureDetector(
      onTap: () {
        final agreementId = row.id;
        context.read<AdminPro>().sendContractReminder(agreementId);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_rounded, size: 16.sp, color: Colors.white),
            SizedBox(width: 6.w),
            const TextWidget(
              text: 'Send Reminder',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
