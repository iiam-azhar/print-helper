import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../models/standard_rule_model.dart';
import '../../models/checklist_model.dart';

import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';
import 'checklist_dialog_mobile.dart';
import 'package:print_helper/tablet_view/lib/tab_settings/checklist_dialog_tablet.dart';
import 'package:print_helper/tablet_view/lib/tab_settings/standard_rule_dialog_tablet.dart';

class ContractsDialogSections {
  static List<Map<String, String>> get checkListTypes => _checkListTypes;
  static List<Map<String, String>> get checkListUserTypes => _checkListUserTypes;
  static List<Map<String, String>> get checkListIcons => _checkListIcons;
  static List<Map<String, String>> get checkListColors => _checkListColors;
  static List<Map<String, String>> get categoryOptions => _categoryOptions;
  static List<Map<String, String>> get iconOptions => _iconOptions;
  static List<Map<String, String>> get colorOptions => _colorOptions;
  static Future<Map<String, String>> getHeaders() => _headers();
  static Future<void> refreshChecklistOptions(BuildContext context) => _refreshChecklistOptions(context);
  static Future<void> refreshCategories(BuildContext context) => _refreshCategories(context);
  static Color getColorFromValue(String value, Color defaultColor) => _getColorFromValue(value, defaultColor);
  static String? getSvgUrlFromValue(String value) => _getSvgUrlFromValue(value);
  static Widget buildChecklistPreviewIcon(String? icon, String? color, {double? customSize}) =>
      _buildChecklistPreviewIcon(icon, color, customSize: customSize);

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool?> showAddRuleDialog(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 650;
    if (isTablet) {
      return showStandardRuleDialogTablet(
        context,
        ruleType: 'specialist',
        dialogTitle: 'Add New Rule',
        titleLabel: 'RULE TITLE',
        titleHint: 'e.g. Weekly Earnings Floor',
        descriptionLabel: 'RULE DESCRIPTION',
        descriptionHint: 'Describe the rule for specialists...',
        addButtonLabel: 'Add Rule',
        secondaryColorLabel: 'Green',
        secondaryColorValue: const Color(0xFF10B981),
      );
    }
    return _showRuleDialog(
      context,
      ruleType: 'specialist',
      dialogTitle: 'Add New Rule',
      titleLabel: 'RULE TITLE',
      titleHint: 'e.g. Weekly Earnings Floor',
      descriptionLabel: 'RULE DESCRIPTION',
      descriptionHint: 'Describe the rule for specialists...',
      addButtonLabel: 'Add Rule',
      secondaryColorLabel: 'Green',
      secondaryColorValue: const Color(0xFF10B981),
    );
  }

  static Future<bool?> showAddStandardDialog(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 650;
    if (isTablet) {
      return showStandardRuleDialogTablet(
        context,
        ruleType: 'client',
        dialogTitle: 'Add New Standard',
        titleLabel: 'STANDARD TITLE',
        titleHint: 'e.g. Project Deposit Required',
        descriptionLabel: 'DESCRIPTION',
        descriptionHint: 'Describe this standard for clients...',
        addButtonLabel: 'Add Standard',
        secondaryColorLabel: 'Red',
        secondaryColorValue: const Color(0xFFDC2626),
      );
    }
    return _showRuleDialog(
      context,
      ruleType: 'client',
      dialogTitle: 'Add New Standard',
      titleLabel: 'STANDARD TITLE',
      titleHint: 'e.g. Project Deposit Required',
      descriptionLabel: 'DESCRIPTION',
      descriptionHint: 'Describe this standard for clients...',
      addButtonLabel: 'Add Standard',
      secondaryColorLabel: 'Red',
      secondaryColorValue: const Color(0xFFDC2626),
    );
  }

  static Future<bool?> showEditStandardDialog(
    BuildContext context,
    StandardRuleModel rule,
  ) {
    final isTablet = MediaQuery.of(context).size.width > 650;
    if (isTablet) {
      return showStandardRuleDialogTablet(
        context,
        ruleType: rule.ruleType,
        dialogTitle: 'Edit Standard Rule',
        titleLabel: 'RULE TITLE',
        titleHint: 'Update rule title',
        descriptionLabel: 'DESCRIPTION',
        descriptionHint: 'Update rule description',
        addButtonLabel: 'Save Changes',
        secondaryColorLabel: 'RULE COLOR',
        secondaryColorValue: const Color(0xFF6366F1),
        existingRule: rule,
      );
    }
    return _showRuleDialog(
      context,
      ruleType: rule.ruleType,
      dialogTitle: 'Edit Standard Rule',
      titleLabel: 'RULE TITLE',
      titleHint: 'Update rule title',
      descriptionLabel: 'DESCRIPTION',
      descriptionHint: 'Update rule description',
      addButtonLabel: 'Save Changes',
      secondaryColorLabel: 'RULE COLOR',
      secondaryColorValue: const Color(0xFF6366F1),
      existingRule: rule,
    );
  }

  static Future<bool?> showAddCheckListDialog(
    BuildContext context, {
    ChecklistModel? existingChecklist,
  }) async {
    final isTablet = MediaQuery.of(context).size.width > 650;
    if (isTablet) {
      return await showAddCheckListDialogTablet(
        context,
        existingChecklist: existingChecklist,
      );
    } else {
      return await showAddCheckListDialogMobile(
        context,
        existingChecklist: existingChecklist,
      );
    }
  }

  static Future<bool?> _showRuleDialog(
    BuildContext context, {
    required String ruleType,
    required String dialogTitle,
    required String titleLabel,
    required String titleHint,
    required String descriptionLabel,
    required String descriptionHint,
    required String addButtonLabel,
    required String secondaryColorLabel,
    required Color secondaryColorValue,
    StandardRuleModel? existingRule,
  }) async {
    final titleCtrl = TextEditingController(text: existingRule?.title);
    final descCtrl = TextEditingController(text: existingRule?.description);
    String? selectedCategory = existingRule?.categoryId?.toString();
    String selectedIcon = existingRule?.icon ?? 'fa-shield-halved';
    String selectedColor = existingRule?.iconColor ?? 'text-blue-500';
    bool isActive = existingRule?.isActive ?? true;
    bool isAdding = false;

    // Refresh categories from API before showing dialog
    await _refreshCategories(context);

    return await showModalBottomSheet<bool?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
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
                            horizontal: 20.w,
                            vertical: 14.h,
                          ),
                          color: Colors.black,
                          child: Row(
                            children: [
                              TextWidget(
                                text: dialogTitle,
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
                              20.w,
                              18.h,
                              20.w,
                              14.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dialogLabel('CATEGORY'),
                                SizedBox(height: 7.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        value: selectedCategory,
                                        hint: 'Select Category',
                                        items: _categoryOptions,
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              selectedCategory = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    GestureDetector(
                                      onTap: () =>
                                          showManageCategoriesDialog(context),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 9.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: const TextWidget(
                                          text: 'Manage',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14.h),
                                Row(
                                  children: [
                                    _dialogLabel(titleLabel),
                                    const TextWidget(
                                      text: ' *',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 7.h),
                                _dialogInputLike(
                                  controller: titleCtrl,
                                  hint: titleHint,
                                ),
                                SizedBox(height: 14.h),
                                _dialogLabel(descriptionLabel),
                                SizedBox(height: 7.h),
                                _dialogInputLike(
                                  controller: descCtrl,
                                  hint: descriptionHint,
                                  maxLines: 4,
                                ),
                                SizedBox(height: 14.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _dialogLabel('ICON'),
                                          SizedBox(height: 7.h),
                                          _buildDropdown(
                                            value: selectedIcon,
                                            items: _iconOptions,
                                            iconColor: _getColorFromValue(
                                              selectedColor,
                                              const Color(0xFF6B7280),
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  selectedIcon = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _dialogLabel('ICON COLOR'),
                                          SizedBox(height: 7.h),
                                          _buildDropdown(
                                            value: selectedColor,
                                            items: _colorOptions,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  selectedColor = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final svgUrl = _getSvgUrlFromValue(
                                            selectedIcon,
                                          );
                                          final color = _getColorFromValue(
                                            selectedColor,
                                            const Color(0xFF3B82F6),
                                          );
                                          if (svgUrl != null &&
                                              svgUrl.isNotEmpty) {
                                            return SvgPicture.network(
                                              svgUrl,
                                              width: 17.sp,
                                              height: 17.sp,
                                              colorFilter: ColorFilter.mode(
                                                color,
                                                BlendMode.srcIn,
                                              ),
                                            );
                                          }
                                          return Icon(
                                            Icons.security_outlined,
                                            size: 17.sp,
                                            color: color,
                                          );
                                        },
                                      ),
                                      SizedBox(width: 8.w),
                                      const TextWidget(
                                        text: 'Preview',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isActive = !isActive;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20.w,
                                        height: 20.w,
                                        child: Checkbox(
                                          value: isActive,
                                          activeColor: const Color(0xFF3B82F6),
                                          onChanged: (value) {
                                            setState(() {
                                              isActive = value ?? false;
                                            });
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      const TextWidget(
                                        text: 'Active',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF374151),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20.w,
                            14.h,
                            20.w,
                            16.h + MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: isAdding
                                    ? null
                                    : () async {
                                        if (selectedCategory == null) {
                                          showToast(
                                            message: 'Please select a category',
                                          );
                                          return;
                                        }
                                        final title = titleCtrl.text.trim();
                                        if (title.isEmpty) {
                                          showToast(
                                            message: 'Please enter a title',
                                          );
                                          return;
                                        }
                                        final desc = descCtrl.text.trim();

                                        setState(() {
                                          isAdding = true;
                                        });

                                        try {
                                          final payload = {
                                            "rule_type": ruleType,
                                            "category_id": int.tryParse(
                                              selectedCategory!,
                                            ),
                                            "icon": selectedIcon,
                                            "icon_color": selectedColor,
                                            "title": title,
                                            "description": desc,
                                            "is_active": isActive,
                                          };

                                          debugPrint(
                                            "RULE UPDATE BODY: $payload",
                                          );

                                          final res = await ApiService()
                                              .postDataToApi(
                                                api: existingRule != null
                                                    ? 'rules/${existingRule.id}'
                                                    : 'rules',
                                                isPut: existingRule != null,
                                                headers: await _headers(),
                                                payload: payload,
                                                showRes: true,
                                              );

                                          debugPrint(
                                            "RULE UPDATE RESPONSE: $res",
                                          );

                                          if (res != null) {
                                            if (res['success'] == true) {
                                              showToast(
                                                message: existingRule != null
                                                    ? 'Rule updated successfully'
                                                    : 'Rule added successfully',
                                              );
                                              if (sheetContext.mounted) {
                                                Navigator.pop(
                                                  sheetContext,
                                                  true,
                                                );
                                              }
                                            } else {
                                              showToast(
                                                message:
                                                    res['message'] ??
                                                    (existingRule != null
                                                        ? 'Failed to update rule'
                                                        : 'Failed to add rule'),
                                              );
                                            }
                                          } else {
                                            showToast(
                                              message:
                                                  'No response from server',
                                            );
                                          }
                                        } catch (e) {
                                          showToast(message: e.toString());
                                        } finally {
                                          if (sheetContext.mounted) {
                                            setState(() {
                                              isAdding = false;
                                            });
                                          }
                                        }
                                      },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdding
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: isAdding
                                      ? SizedBox(
                                          width: 14.sp,
                                          height: 14.sp,
                                          child:
                                              const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : TextWidget(
                                          text: addButtonLabel,
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
                                    horizontal: 20.w,
                                    vertical: 10.h,
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
            );
          },
        );
      },
    );
  }

  static Future<void> showManageCategoriesDialog(BuildContext context) async {
    final isTablet = MediaQuery.of(context).size.width > 650;
    if (isTablet) {
      return showManageCategoriesDialogTablet(context);
    }

    final categoryCtrl = TextEditingController();
    bool isInitialLoading = true;
    bool isAdding = false;
    String? editingId;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isInitialLoading) {
              _refreshCategories(context).then((_) {
                if (dialogContext.mounted) {
                  setState(() => isInitialLoading = false);
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 24.h,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 640.w,
                    maxHeight: 520.h,
                  ),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 14.h,
                        ),
                        color: Colors.black,
                        child: Row(
                          children: [
                            const TextWidget(
                              text: 'Manage Categories',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: isInitialLoading
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.h),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  20.w,
                                  14.h,
                                  20.w,
                                  0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_categoryOptions.isNotEmpty) ...[
                                      ..._categoryOptions.map((cat) {
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 14.h,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextWidget(
                                                  text: cat['label'] ?? '',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF111827,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    editingId = cat['value'];
                                                    categoryCtrl.text =
                                                        cat['label'] ?? '';
                                                  });
                                                },
                                                child: const TextWidget(
                                                  text: 'Edit',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                              GestureDetector(
                                                onTap: isAdding
                                                    ? null
                                                    : () async {
                                                        final id = cat['value'];
                                                        if (id == null) return;

                                                        setState(() {
                                                          isAdding = true;
                                                        });

                                                        try {
                                                          final res = await ApiService()
                                                              .postDataToApi(
                                                                api:
                                                                    'rule-categories/$id',
                                                                isDelete: true,
                                                                headers:
                                                                    await _headers(),
                                                                showRes: true,
                                                              );

                                                          if (res != null &&
                                                              res['success'] ==
                                                                  true) {
                                                            setState(() {
                                                              _categoryOptions
                                                                  .removeWhere(
                                                                    (e) =>
                                                                        e['value'] ==
                                                                        id,
                                                                  );
                                                            });
                                                            showToast(
                                                              message:
                                                                  'Category deleted successfully',
                                                            );
                                                          }
                                                        } catch (e) {
                                                          // Handle error
                                                        } finally {
                                                          setState(() {
                                                            isAdding = false;
                                                          });
                                                        }
                                                      },
                                                child: const TextWidget(
                                                  text: 'Delete',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFFEF4444),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 18.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 1.h,
                              color: const Color(0xFFD1D5DB),
                              margin: EdgeInsets.only(bottom: 14.h),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: categoryCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'New category name',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 10.h,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD1D5DB),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD1D5DB),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: const Color(0xFF111827),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                GestureDetector(
                                  onTap: isAdding
                                      ? null
                                      : () async {
                                          final name = categoryCtrl.text.trim();
                                          if (name.isEmpty) return;

                                          setState(() {
                                            isAdding = true;
                                          });

                                          try {
                                            final res = await ApiService()
                                                .postDataToApi(
                                                  api: editingId != null
                                                      ? 'rule-categories/$editingId'
                                                      : 'rule-categories',
                                                  isPut: editingId != null,
                                                  headers: await _headers(),
                                                  payload: {'name': name},
                                                  showRes: true,
                                                );

                                            if (res != null &&
                                                res['success'] == true) {
                                              if (editingId != null) {
                                                final index = _categoryOptions
                                                    .indexWhere(
                                                      (e) =>
                                                          e['value'] ==
                                                          editingId,
                                                    );
                                                if (index != -1) {
                                                  setState(() {
                                                    _categoryOptions[index]['label'] =
                                                        name;
                                                  });
                                                }
                                              } else {
                                                final cat = res['category'];
                                                if (cat != null) {
                                                  setState(() {
                                                    _categoryOptions.add({
                                                      "value": cat['id']
                                                          .toString(),
                                                      "label": cat['name']
                                                          .toString(),
                                                    });
                                                  });
                                                }
                                              }
                                              setState(() {
                                                editingId = null;
                                                categoryCtrl.clear();
                                              });
                                            }
                                          } catch (e) {
                                            // Handle error
                                          } finally {
                                            setState(() {
                                              isAdding = false;
                                            });
                                          }
                                        },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 9.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdding
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF22C55E),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: isAdding
                                        ? SizedBox(
                                            width: 14.sp,
                                            height: 14.sp,
                                            child:
                                                const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                          )
                                        : TextWidget(
                                            text: editingId != null
                                                ? 'Save'
                                                : 'Add',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
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
      },
    );
  }

  static final List<Map<String, String>> _categoryOptions = [];

  static Future<void> _refreshCategories(BuildContext context) async {
    try {
      final res = await ApiService().getDataFromApi(
        api: 'rule-categories',
        headers: await _headers(),
        showRes: false,
      );

      if (res != null && res['success'] == true) {
        final List<dynamic> categories = res['categories'] ?? [];
        _categoryOptions.clear();
        for (var cat in categories) {
          _categoryOptions.add({
            "value": cat['id'].toString(),
            "label": cat['name'].toString(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  static const List<Map<String, String>> _iconOptions = [
    {
      "value": "fa-shield-halved",
      "label": "Shield (Protection)",
      "name": "shield-halved",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/shield-halved.svg",
    },
    {
      "value": "fa-arrow-trend-up",
      "label": "Trend Up (Growth)",
      "name": "arrow-trend-up",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/arrow-trend-up.svg",
    },
    {
      "value": "fa-lock",
      "label": "Lock (Exclusive)",
      "name": "lock",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/lock.svg",
    },
    {
      "value": "fa-clock",
      "label": "Clock (Time)",
      "name": "clock",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/clock.svg",
    },
    {
      "value": "fa-ban",
      "label": "Ban (Restriction)",
      "name": "ban",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/ban.svg",
    },
    {
      "value": "fa-copyright",
      "label": "Copyright (IP)",
      "name": "copyright",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/copyright.svg",
    },
    {
      "value": "fa-triangle-exclamation",
      "label": "Warning",
      "name": "triangle-exclamation",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/triangle-exclamation.svg",
    },
    {
      "value": "fa-money-bill",
      "label": "Money (Payment)",
      "name": "money-bill",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/money-bill.svg",
    },
    {
      "value": "fa-star",
      "label": "Star",
      "name": "star",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/star.svg",
    },
    {
      "value": "fa-handshake",
      "label": "Handshake",
      "name": "handshake",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/handshake.svg",
    },
    {
      "value": "fa-user-tie",
      "label": "Professional",
      "name": "user-tie",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/user-tie.svg",
    },
    {
      "value": "fa-circle-check",
      "label": "Check Circle",
      "name": "circle-check",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/circle-check.svg",
    },
    {
      "value": "fa-circle-dot",
      "label": "Circle Dot",
      "name": "circle-dot",
      "svg_url":
          "https://cdn.jsdelivr.net/gh/FortAwesome/Font-Awesome@6.x/svgs/solid/circle-dot.svg",
    },
  ];

  static const List<Map<String, String>> _colorOptions = [
    {"value": "text-blue-500", "label": "Blue", "hex": "#3b82f6"},
    {"value": "text-blue-600", "label": "Blue (Dark)", "hex": "#2563eb"},
    {"value": "text-green-500", "label": "Green", "hex": "#22c55e"},
    {"value": "text-orange-500", "label": "Orange", "hex": "#f97316"},
    {"value": "text-red-500", "label": "Red", "hex": "#ef4444"},
    {"value": "text-yellow-500", "label": "Yellow", "hex": "#eab308"},
    {"value": "text-gray-500", "label": "Gray", "hex": "#6b7280"},
    {"value": "text-purple-500", "label": "Purple", "hex": "#a855f7"},
  ];

  static Color _getColorFromValue(String value, Color defaultColor) {
    if (value.startsWith('#')) {
      try {
        final hex = value.replaceAll('#', '0xFF');
        return Color(int.parse(hex));
      } catch (e) {
        return defaultColor;
      }
    }
    final colorMap = _colorOptions.firstWhere(
      (e) => e['value'] == value,
      orElse: () => {},
    );
    if (colorMap.containsKey('hex') && colorMap['hex'] != null) {
      return Color(int.parse(colorMap['hex']!.replaceAll('#', '0xFF')));
    }
    final checkListColorMap = _checkListColors.firstWhere(
      (e) => e['value'] == value,
      orElse: () => {},
    );
    if (checkListColorMap.containsKey('hex') && checkListColorMap['hex'] != null) {
      final hexStr = checkListColorMap['hex']!;
      if (hexStr.startsWith('#')) {
        return Color(int.parse(hexStr.replaceAll('#', '0xFF')));
      }
    }
    return defaultColor;
  }

  static String? _getSvgUrlFromValue(String value) {
    final iconMap = _iconOptions.firstWhere(
      (e) => e['value'] == value,
      orElse: () => {},
    );
    return iconMap['svg_url'];
  }

  static Widget _buildDropdown({
    required String? value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    Color? iconColor,
    String? hint,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          menuMaxHeight: 350.h,
          hint: hint != null
              ? TextWidget(
                  text: hint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                )
              : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 16.sp,
            color: const Color(0xFF6B7280),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['value'],
              child: Row(
                children: [
                  if (item.containsKey('svg_url') &&
                      item['svg_url']!.isNotEmpty) ...[
                    SvgPicture.network(
                      item['svg_url']!,
                      width: 16.sp,
                      height: 16.sp,
                      colorFilter: ColorFilter.mode(
                        iconColor ?? const Color(0xFF6B7280),
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  if (item.containsKey('hex')) ...[
                    Container(
                      width: 14.sp,
                      height: 14.sp,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(item['hex']!.replaceAll('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          width: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: TextWidget(
                      text: item['label'] ?? '',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF111827),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  static Widget _dialogLabel(String text) {
    return TextWidget(
      text: text,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF6B7280),
    );
  }

  static final List<Map<String, String>> _checkListTypes = [];
  static final List<Map<String, String>> _checkListUserTypes = [];
  static final List<Map<String, String>> _checkListIcons = [];
  static final List<Map<String, String>> _checkListColors = [];

  static Future<void> _refreshChecklistOptions(BuildContext context) async {
    try {
      final res = await ApiService().getDataFromApi(
        api: 'checklists/options',
        headers: await _headers(),
        showRes: false,
      );

      if (res != null && res['success'] == true) {
        _checkListTypes.clear();
        for (var t in (res['types'] ?? [])) {
          _checkListTypes.add({
            "value": t['value'].toString(),
            "label": t['label'].toString(),
          });
        }
        _checkListUserTypes.clear();
        for (var ut in (res['user_types'] ?? [])) {
          _checkListUserTypes.add({
            "value": ut['value'].toString(),
            "label": ut['label'].toString(),
          });
        }
        _checkListIcons.clear();
        for (var i in (res['icons'] ?? [])) {
          _checkListIcons.add({
            "value": i['value'].toString(),
            "label": i['label'].toString(),
            "svg_url": i['svg_url'].toString(),
          });
        }
        _checkListColors.clear();
        for (var c in (res['colors'] ?? [])) {
          _checkListColors.add({
            "value": c['value'].toString(),
            "label": c['label'].toString(),
            "hex": c['hex'].toString(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching checklist options: $e');
    }
  }

  static Widget _buildChecklistPreviewIcon(
    String? icon,
    String? color, {
    double? customSize,
  }) {
    final size = customSize ?? 18.sp;
    if (icon == null || icon.isEmpty) {
      return Icon(Icons.assignment, size: size, color: Colors.grey);
    }
    final svgUrl = _checkListIcons.firstWhere(
      (e) => e['value'] == icon,
      orElse: () => {},
    )['svg_url'];

    if (svgUrl != null && svgUrl.isNotEmpty) {
      return SvgPicture.network(
        svgUrl,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          _getColorFromValue(color ?? '', const Color(0xFF6B7280)),
          BlendMode.srcIn,
        ),
      );
    }
    return Icon(Icons.assignment, size: size, color: Colors.grey);
  }



  static Widget _dialogInputLike({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        errorStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFEF4444),
        ),
        hintStyle: TextStyle(
          color: const Color(0xFF9CA3AF),
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
      style: TextStyle(
        color: const Color(0xFF111827),
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
