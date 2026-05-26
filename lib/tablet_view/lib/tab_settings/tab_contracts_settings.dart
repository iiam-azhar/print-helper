import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/models/contract_template_model.dart';
import 'package:print_helper/models/standard_rule_model.dart';
import 'package:print_helper/models/contracts_models.dart';
import 'package:print_helper/models/checklist_model.dart';
import 'package:print_helper/widgets/rule_icon.dart';
import 'package:print_helper/admin/settings/contracts_dialog_sections.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_pro.dart';
import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';
import '../tab_services/api_routes.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_toasts.dart';
import 'edit_template_dialog_tablet.dart';

class ContractsSettingsTablet extends StatefulWidget {
  const ContractsSettingsTablet({super.key});

  @override
  State<ContractsSettingsTablet> createState() =>
      _ContractsSettingsTabletState();
}

class _ContractsSettingsTabletState extends State<ContractsSettingsTablet> {
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
  bool _onboardingExpanded = true;
  bool _trainingExpanded = true;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section tabs (always visible)
            _buildSectionTabs(),
            // Content based on active section
            if (_activeSection == 0)
              ..._buildContractsContentWithStickyPagination()
            else if (_activeSection == 1)
              Expanded(
                child: SingleChildScrollView(child: _buildTemplatesContent()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: _activeSection == 2
                      ? _buildSpecialistStandardsContent()
                      : _activeSection == 3
                      ? _buildClientStandardsContent()
                      : _buildCheckListsContent(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_sections.length, (index) {
            final isActive = _activeSection == index;
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _activeSection = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
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

  List<Widget> _buildContractsContentWithStickyPagination() {
    return [
      Expanded(
        child: Consumer<AdminPro>(
          builder: (context, pro, _) {
            final rows = pro.contracts;
            final clientUnsigned =
                (pro.clientTotal - pro.clientAgreementsSigned)
                    .clamp(0, pro.clientTotal)
                    .toInt();
            final specialistUnsigned =
                (pro.specialistTotal - pro.specialistContractsSigned)
                    .clamp(0, pro.specialistTotal)
                    .toInt();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
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
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        SizedBox(width: 8),
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
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          title: 'CLIENT AGREEMENTS',
                          value: '${pro.clientTotal}',
                          subtitle: '$clientUnsigned unsigned',
                          topColor: const Color(0xFF22C55E),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          title: 'SPECIALIST CONTRACTS',
                          value: '${pro.specialistTotal}',
                          subtitle: '$specialistUnsigned unsigned',
                          topColor: const Color(0xFF22C55E),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          title: 'UNSIGNED',
                          value: '${pro.totalUnsigned}',
                          subtitle: pro.oldestUnsignedText.trim().isEmpty
                              ? 'No overdue contracts'
                              : pro.oldestUnsignedText,
                          topColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  if (pro.contractsLoad && rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: TextWidget(
                        text: 'No contracts found',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    _buildContractsTable(rows),
                ],
              ),
            );
          },
        ),
      ),
      // Sticky pagination at the bottom
      Consumer<AdminPro>(
        builder: (context, pro, _) {
          if (pro.contracts.isEmpty) return const SizedBox.shrink();
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: _buildTabletPagination(pro),
          );
        },
      ),
    ];
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
          padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'These rules display in the specialist portal. Changes appear immediately.',
                buttonLabel: 'Add Rule',
                onTap: _showAddRuleDialog,
              ),
              SizedBox(height: 14),
              if (pro.specialistRules.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
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
                _buildRulesTable(pro.specialistRules, 'specialist'),
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
        final isCompact = constraints.maxWidth < 540;
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
              SizedBox(height: 12),
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
            SizedBox(width: 10),
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

  
  Widget _greenAddButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 16),
            SizedBox(width: 4),
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
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Align(
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 12),
            child: TextWidget(
              text: 'No templates found',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final useTwoColumns = screenWidth >= 720;
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
                    padding: EdgeInsets.only(bottom: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _templateCard(left, hasBottomMargin: false),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: right != null
                                ? _templateCard(right, hasBottomMargin: false)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
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
      margin: hasBottomMargin ? EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Top content group ──────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — no LayoutBuilder; tablet cards are always wide enough
              TextWidget(
                text: item.name,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 2),
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
              const SizedBox(height: 12),
              _templateTextBlock(label: 'Variables', text: item.variablesText),
              const SizedBox(height: 8),
              _templateTextBlock(label: 'Clauses', text: item.clausesText),
            ],
          ),

          // ── Bottom button ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: _editTemplateButton(
                onTap: () => _showEditTemplateDialog(item),
              ),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(10),
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
    await showEditTemplateDialogTablet(context, item);
  }

  Widget _templateTextBlock({required String label, required String text}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
          children: [
            TextSpan(
              text: text,
              style: TextStyle(
                fontSize: 12,
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
          padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'These standards display in the client portal. Changes appear immediately.',
                buttonLabel: 'Add Standard',
                onTap: _showAddStandardDialog,
              ),
              SizedBox(height: 14),
              if (pro.clientRules.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
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
                _buildRulesTable(pro.clientRules, 'client'),
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

  Future<void> _showEditStandardDialog(
    StandardRuleModel rule,
    String type,
  ) async {
    final res = await ContractsDialogSections.showEditStandardDialog(
      context,
      rule,
    );
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

        final onboardingLists = pro.checklists
            .where((item) => !item.listType.toLowerCase().contains('training'))
            .toList();
        final trainingLists = pro.checklists
            .where((item) => item.listType.toLowerCase().contains('training'))
            .toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionIntro(
                message:
                    'Onboarding and training checklists are grouped below. Expand or collapse each section. Icons use the colors you set.',
                buttonLabel: 'Add Check List',
                onTap: _showAddCheckListDialog,
              ),
              const SizedBox(height: 14),
              if (pro.checklists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: TextWidget(
                      text: 'No checklists found.',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else ...[
                _buildCollapsibleSection(
                  title: 'Onboarding checklists',
                  count: onboardingLists.length,
                  isExpanded: _onboardingExpanded,
                  isTraining: false,
                  items: onboardingLists,
                  onToggle: () => setState(
                    () => _onboardingExpanded = !_onboardingExpanded,
                  ),
                ),
                _buildCollapsibleSection(
                  title: 'Training checklists',
                  count: trainingLists.length,
                  isExpanded: _trainingExpanded,
                  isTraining: true,
                  items: trainingLists,
                  onToggle: () =>
                      setState(() => _trainingExpanded = !_trainingExpanded),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required int count,
    required bool isExpanded,
    required bool isTraining,
    required List<ChecklistModel> items,
    required VoidCallback onToggle,
  }) {
    final headerBgColor = isTraining
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFEFF6FF);
    final headerTextColor = isTraining
        ? const Color(0xFF15803D)
        : const Color(0xFF1D4ED8);
    final borderColor = isTraining
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFDBEAFE);
    final iconData = isTraining
        ? Icons.school_outlined
        : Icons.assignment_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          // Header Row
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(11))
                    : BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(iconData, color: headerTextColor, size: 20),
                  const SizedBox(width: 8),
                  TextWidget(
                    text: '$title ($count)',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: headerTextColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: TextWidget(
                    text: 'No checklists in this section.',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                  ),
                ),
              )
            else ...[
              // Table Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 80,
                      child: TextWidget(
                        text: 'ICON',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextWidget(
                        text: 'NAME',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextWidget(
                        text: 'USER TYPES',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextWidget(
                        text: 'ITEMS',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextWidget(
                          text: 'ACTIONS',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Table Body Rows
              ...List.generate(items.length, (index) {
                final item = items[index];
                final userTypesList = item.userType
                    .split(RegExp(r'[\s,]+'))
                    .where((s) => s.isNotEmpty)
                    .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ICON cell
                          SizedBox(
                            width: 80,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _sectionIcon(
                                icon: item.iconName,
                                svgUrl: item.iconSvgUrl,
                                colorHex: item.colorHex,
                              ),
                            ),
                          ),

                          // NAME cell
                          Expanded(
                            flex: 3,
                            child: TextWidget(
                              text: item.name,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          // USER TYPES cell
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: userTypesList.map((type) {
                                return _softChip(
                                  label: type,
                                  backgroundColor: const Color(0xFFF4F4F5),
                                  textColor: Colors.grey.shade700,
                                );
                              }).toList(),
                            ),
                          ),

                          // ITEMS cell
                          Expanded(
                            flex: 2,
                            child: TextWidget(
                              text: '${item.itemsCount} items',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          // ACTIONS cell
                          SizedBox(
                            width: 220,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final res =
                                        await ContractsDialogSections.showAddCheckListDialog(
                                          context,
                                          existingChecklist: item,
                                        );
                                    if (res == true) {
                                      if (mounted) {
                                        context
                                            .read<AdminPro>()
                                            .getChecklists();
                                      }
                                    }
                                  },
                                  child: SizedBox(
                                    width: 95,
                                    child: _outlineActionButton(
                                      label: 'Edit',
                                      color: const Color(0xFF4B5563),
                                      imagePath: Paths.edit,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Checklist'),
                                        content: const Text(
                                          'Are you sure you want to delete this checklist?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
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
                                            .deleteChecklist(item.id);
                                        if (!mounted) return;
                                        Loaders.hide(); // Hide loader
                                        if (res) {
                                          context
                                              .read<AdminPro>()
                                              .getChecklists();
                                        }
                                      } catch (e) {
                                        if (mounted) Loaders.hide();
                                      }
                                    }
                                  },
                                  child: SizedBox(
                                    width: 95,
                                    child: _outlineActionButton(
                                      label: 'Delete',
                                      color: const Color(0xFFEF4444),
                                      imagePath: Paths.delete,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < items.length - 1)
                      const Divider(height: 1, color: Color(0xFFEFF1F3)),
                  ],
                );
              }),
            ],
          ],
        ],
      ),
    );
  }


  Widget _sectionIcon({String? icon, String? svgUrl, String? colorHex}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: svgUrl != null && svgUrl.isNotEmpty
          ? SvgPicture.network(
              svgUrl,
              width: 20,
              height: 20,
              placeholderBuilder: (context) => SizedBox(
                width: 14,
                height: 14,
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
          : Text(icon ?? '', style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildRulesTable(List<StandardRuleModel> rules, String type) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                SizedBox(
                  width: 60,
                  child: TextWidget(
                    text: 'ICON',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextWidget(
                    text: 'TITLE',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextWidget(
                    text: 'CATEGORY',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Expanded(
                  child: TextWidget(
                    text: 'PREVIEW',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextWidget(
                    text: 'ACTIVE',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextWidget(
                    text: 'ACTIONS',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Table Body Rows
          ...List.generate(rules.length, (index) {
            final rule = rules[index];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ICON Column
                      SizedBox(
                        width: 60,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RuleIcon(
                            svgUrl: rule.iconSvgUrl,
                            colorHex: rule.colorHex,
                            size: 20,
                          ),
                        ),
                      ),
                      // TITLE Column
                      SizedBox(
                        width: 160,
                        child: TextWidget(
                          text: rule.title,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      // CATEGORY Column
                      SizedBox(
                        width: 160,
                        child: TextWidget(
                          text:
                              rule.categoryName == null ||
                                  rule.categoryName!.isEmpty
                              ? 'Uncategorized'
                              : rule.categoryName!,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      // PREVIEW Column
                      Expanded(
                        child: TextWidget(
                          text: rule.description,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade500,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 60,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildToggleSwitch(rule, type),
                        ),
                      ),
                      // ACTIONS Column
                      SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showEditStandardDialog(rule, type),
                              child: SizedBox(
                                width: 70,
                                child: _outlineActionButton(
                                  label: 'Edit',
                                  color: const Color(0xFF4B5563),
                                  imagePath: Paths.edit,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _deleteRule(rule.id, type),
                              child: SizedBox(
                                width: 70,
                                child: _outlineActionButton(
                                  label: 'Delete',
                                  color: const Color(0xFFEF4444),
                                  imagePath: Paths.delete,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < rules.length - 1)
                  Divider(height: 1, color: Colors.grey.shade200),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _softChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextWidget(
        text: label,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDelete ? const Color(0xFFFFF1F2) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDelete ? const Color(0xFFFECDD3) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ImageWidget(image: imagePath, width: 11, height: 11),
          SizedBox(width: 3),
          TextWidget(
            text: label,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color topColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: topColor, width: 4)),
      ),
      child: Card(
        margin: EdgeInsets.only(top: 0, bottom: 2, left: 1, right: 1),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: title,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(height: 4),
                  TextWidget(
                    text: value,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  SizedBox(height: 2),
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

  Widget _buildTabletPagination(AdminPro pro) {
    if (pro.contractsLastPage <= 1 && !pro.isContractsLoadingMore) {
      return const SizedBox.shrink();
    }

    if (pro.isContractsLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: const CircularProgressIndicator(),
      );
    }

    List<Widget> pageButtons = [];

    // Add first and previous
    pageButtons.add(
      _pageBtn(
        icon: Icons.keyboard_double_arrow_left,
        disabled: pro.contractsCurrentPage == 1,
        onTap: () => _goToPage(pro, 1),
      ),
    );
    pageButtons.add(
      _pageBtn(
        icon: Icons.keyboard_arrow_left,
        disabled: pro.contractsCurrentPage == 1,
        onTap: () => _goToPage(pro, pro.contractsCurrentPage - 1),
      ),
    );

    // Simple display logic for a few pages
    for (int i = 1; i <= pro.contractsLastPage; i++) {
      if (i == 1 ||
          i == pro.contractsLastPage ||
          (i >= pro.contractsCurrentPage - 2 &&
              i <= pro.contractsCurrentPage + 2)) {
        pageButtons.add(
          _pageBtnText(
            page: i,
            isActive: pro.contractsCurrentPage == i,
            onTap: () => _goToPage(pro, i),
          ),
        );
      } else if (i == pro.contractsCurrentPage - 3 ||
          i == pro.contractsCurrentPage + 3) {
        pageButtons.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: TextWidget(
              text: '...',
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    // Add next and last
    pageButtons.add(
      _pageBtn(
        icon: Icons.keyboard_arrow_right,
        disabled: pro.contractsCurrentPage == pro.contractsLastPage,
        onTap: () => _goToPage(pro, pro.contractsCurrentPage + 1),
      ),
    );
    pageButtons.add(
      _pageBtn(
        icon: Icons.keyboard_double_arrow_right,
        disabled: pro.contractsCurrentPage == pro.contractsLastPage,
        onTap: () => _goToPage(pro, pro.contractsLastPage),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: pageButtons,
      ),
    );
  }

  void _goToPage(AdminPro pro, int page) {
    if (page < 1 ||
        page > pro.contractsLastPage ||
        page == pro.contractsCurrentPage) {
      return;
    }
    context.read<AdminPro>().getContracts(
      ctx: context,
      page: page,
      loadMore: false,
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? Colors.grey.shade400 : Colors.black87,
        ),
      ),
    );
  }

  Widget _pageBtnText({
    required int page,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC107) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? const Color(0xFFFFC107) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: TextWidget(
            text: '$page',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildContractsTable(List<ContractAgreementModel> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          dataRowMaxHeight: 65,
          dataRowMinHeight: 60,
          horizontalMargin: 16,
          columnSpacing: 16,
          columns: const [
            DataColumn(
              label: TextWidget(
                text: 'NAME',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            DataColumn(
              label: TextWidget(
                text: 'TYPE',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            DataColumn(
              label: TextWidget(
                text: 'SIGNED',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            DataColumn(
              label: TextWidget(
                text: 'IP ADDRESS',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            DataColumn(
              label: TextWidget(
                text: 'TEMPLATE',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            DataColumn(
              label: TextWidget(
                text: 'ACTION',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
          rows: rows.map((row) {
            final isSigned = row.isSigned;
            final bgColor = isSigned
                ? Colors.transparent
                : const Color(0xFFFEF2F2);
            return DataRow(
              color: WidgetStateProperty.all(bgColor),
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextWidget(
                        text: row.name,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      SizedBox(height: 2),
                      TextWidget(
                        text: row.subtitle,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                DataCell(
                  _typeChip(
                    label: row.type,
                    color: row.type.toLowerCase() == 'client'
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFFEF3C7),
                    textColor: row.type.toLowerCase() == 'client'
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFA16207),
                  ),
                ),
                DataCell(
                  TextWidget(
                    text: _formatSignedDate(row.signedAt),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSigned ? Colors.black : const Color(0xFFEF4444),
                  ),
                ),
                DataCell(
                  TextWidget(
                    text: row.ipAddress ?? '-',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                DataCell(
                  TextWidget(
                    text: row.template.isEmpty ? '-' : row.template,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                DataCell(
                  isSigned
                      ? _pdfActionButtonSmall(row: row)
                      : _reminderActionButtonSmall(row),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _reminderActionButtonSmall(ContractAgreementModel row) {
    return GestureDetector(
      onTap: () {
        context.read<AdminPro>().sendContractReminder(row.id);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_none,
          size: 16,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  Widget _pdfActionButtonSmall({required ContractAgreementModel row}) {
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

        context.read<AdminPro>().downloadContractPdf(
          url: fullUrl,
          fileName: fileName,
        );
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.download_rounded,
          size: 16,
          color: Colors.grey.shade700,
        ),
      ),
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
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

}
