import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:print_helper/admin/settings/contracts_dialog_sections.dart';
import 'package:print_helper/models/standard_rule_model.dart';
import 'package:print_helper/services/api_service.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_text_widget.dart' as tab;
import 'package:print_helper/widgets/toasts.dart';

Future<bool?> showStandardRuleDialogTablet(
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
  bool isSaving = false;

  // Refresh categories from API before showing dialog
  await ContractsDialogSections.refreshCategories(context);

  if (!context.mounted) return null;

  return await showDialog<bool?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 680,
                ),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      color: Colors.black,
                      child: Row(
                        children: [
                          tab.TextWidget(
                            text: dialogTitle,
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

                    // Scrollable Form Fields
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _tabDialogLabel('CATEGORY'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _tabBuildDropdown(
                                    value: selectedCategory,
                                    hint: 'Select Category',
                                    items: ContractsDialogSections.categoryOptions,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setStateDialog(() {
                                          selectedCategory = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    await ContractsDialogSections.showManageCategoriesDialog(dialogContext);
                                    if (dialogContext.mounted) {
                                      await ContractsDialogSections.refreshCategories(dialogContext);
                                      setStateDialog(() {});
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const tab.TextWidget(
                                      text: 'Manage',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                _tabDialogLabel(titleLabel),
                                const tab.TextWidget(
                                  text: ' *',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _tabDialogInputLike(
                              controller: titleCtrl,
                              hint: titleHint,
                            ),
                            const SizedBox(height: 14),

                            _tabDialogLabel(descriptionLabel),
                            const SizedBox(height: 6),
                            _tabDialogInputLike(
                              controller: descCtrl,
                              hint: descriptionHint,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _tabDialogLabel('ICON'),
                                      const SizedBox(height: 6),
                                      _tabBuildDropdown(
                                        value: selectedIcon,
                                        items: ContractsDialogSections.iconOptions,
                                        iconColor: ContractsDialogSections.getColorFromValue(
                                          selectedColor,
                                          const Color(0xFF6B7280),
                                        ),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setStateDialog(() {
                                              selectedIcon = val;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _tabDialogLabel('ICON COLOR'),
                                      const SizedBox(height: 6),
                                      _tabBuildDropdown(
                                        value: selectedColor,
                                        items: ContractsDialogSections.colorOptions,
                                        onChanged: (val) {
                                          if (val != null) {
                                            setStateDialog(() {
                                              selectedColor = val;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── PICKER ──────────────────────────────
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _tabDialogLabel('PICKER'),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () {
                                        _showStandardRuleColorPickerDialog(
                                          context,
                                          selectedColor,
                                          (colorVal) {
                                            setStateDialog(() {
                                              selectedColor = colorVal;
                                            });
                                          },
                                        );
                                      },
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: ContractsDialogSections.getColorFromValue(
                                            selectedColor,
                                            const Color(0xFF3B82F6),
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFD1D5DB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Preview Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final svgUrl = ContractsDialogSections.getSvgUrlFromValue(
                                          selectedIcon,
                                        );
                                        final color = ContractsDialogSections.getColorFromValue(
                                          selectedColor,
                                          const Color(0xFF3B82F6),
                                        );
                                        if (svgUrl != null && svgUrl.isNotEmpty) {
                                          return SvgPicture.network(
                                            svgUrl,
                                            width: 16,
                                            height: 16,
                                            colorFilter: ColorFilter.mode(
                                              color,
                                              BlendMode.srcIn,
                                            ),
                                          );
                                        }
                                        return Icon(
                                          Icons.security_outlined,
                                          size: 16,
                                          color: color,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const tab.TextWidget(
                                    text: 'Preview',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Active Checkbox
                            GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  isActive = !isActive;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: isActive,
                                      activeColor: const Color(0xFF3B82F6),
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          isActive = value ?? false;
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const tab.TextWidget(
                                    text: 'Active',
                                    fontSize: 12,
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

                    // Actions Row Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: isSaving
                                ? null
                                : () async {
                                    if (selectedCategory == null) {
                                      showToast(message: 'Please select a category');
                                      return;
                                    }
                                    final title = titleCtrl.text.trim();
                                    if (title.isEmpty) {
                                      showToast(message: 'Please enter a title');
                                      return;
                                    }
                                    final desc = descCtrl.text.trim();

                                    setStateDialog(() {
                                      isSaving = true;
                                    });

                                    try {
                                      final payload = {
                                        "rule_type": ruleType,
                                        "category_id": int.tryParse(selectedCategory!),
                                        "icon": selectedIcon,
                                        "icon_color": selectedColor,
                                        "title": title,
                                        "description": desc,
                                        "is_active": isActive,
                                      };

                                      debugPrint("RULE UPDATE BODY: $payload");

                                      final token = await ContractsDialogSections.getHeaders();
                                      final res = await ApiService().postDataToApi(
                                        api: existingRule != null
                                            ? 'rules/${existingRule.id}'
                                            : 'rules',
                                        isPut: existingRule != null,
                                        headers: token,
                                        payload: payload,
                                        showRes: true,
                                      );

                                      debugPrint("RULE UPDATE RESPONSE: $res");

                                      if (res != null) {
                                        if (res['success'] == true) {
                                          showToast(
                                            message: existingRule != null
                                                ? 'Rule updated successfully'
                                                : 'Rule added successfully',
                                          );
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext, true);
                                          }
                                        } else {
                                          showToast(
                                            message: res['message'] ??
                                                (existingRule != null
                                                    ? 'Failed to update rule'
                                                    : 'Failed to add rule'),
                                          );
                                        }
                                      } else {
                                        showToast(message: 'No response from server');
                                      }
                                    } catch (e) {
                                      showToast(message: e.toString());
                                    } finally {
                                      if (dialogContext.mounted) {
                                        setStateDialog(() {
                                          isSaving = false;
                                        });
                                      }
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSaving ? const Color(0xFF9CA3AF) : const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : tab.TextWidget(
                                      text: addButtonLabel,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(6),
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
    },
  );
}

void _showStandardRuleColorPickerDialog(
  BuildContext context,
  String currentColor,
  ValueChanged<String> onColorSelected,
) {
  Color parsedCurrentColor = const Color(0xFF3B82F6);
  if (currentColor.startsWith('#')) {
    parsedCurrentColor = Color(int.parse(currentColor.replaceAll('#', '0xFF')));
  } else {
    parsedCurrentColor = ContractsDialogSections.getColorFromValue(
      currentColor,
      const Color(0xFF3B82F6),
    );
  }
  Color tempColor = parsedCurrentColor;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return DefaultTabController(
            length: 2,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const tab.TextWidget(
                          text: 'Select Icon Color',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: Color(0xFF3B82F6),
                      unselectedLabelColor: Color(0xFF6B7280),
                      indicatorColor: Color(0xFF3B82F6),
                      tabs: [Tab(text: 'Presets'), Tab(text: 'Custom')],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 310,
                      child: TabBarView(
                        children: [
                          // ── Presets ───────────────────────────────────
                          SingleChildScrollView(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: ContractsDialogSections.colorOptions.map((item) {
                                final hexStr = item['hex'] ?? '#3B82F6';
                                final label = item['label'] ?? '';
                                final value = item['value'] ?? '';
                                final color = Color(
                                  int.parse(hexStr.replaceAll('#', '0xFF')),
                                );
                                final isSelected = currentColor == value ||
                                    currentColor.toLowerCase() ==
                                        hexStr.toLowerCase();
                                final useDarkCheck =
                                    color.computeLuminance() > 0.6;
                                return Tooltip(
                                  message: label,
                                  child: GestureDetector(
                                    onTap: () {
                                      onColorSelected(value);
                                      Navigator.pop(dialogContext);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.black
                                              : const Color(0xFFE5E7EB),
                                          width: isSelected ? 3 : 1.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withAlpha(102),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              color: useDarkCheck
                                                  ? Colors.black87
                                                  : Colors.white,
                                              size: 20,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // ── Custom Color ─────────────────────────────
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: ColorPicker(
                                    pickerColor: tempColor,
                                    onColorChanged: (color) {
                                      setStateDialog(() => tempColor = color);
                                    },
                                    enableAlpha: false,
                                    displayThumbColor: true,
                                    paletteType: PaletteType.hsvWithHue,
                                    pickerAreaHeightPercent: 0.35,
                                    labelTypes: const [],
                                    colorPickerWidth: 220,
                                    portraitOnly: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const tab.TextWidget(
                                        text: 'Cancel',
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        final hex =
                                            '#${tempColor.toARGB32().toRadixString(16).substring(2, 8)}';
                                        onColorSelected(hex);
                                        Navigator.pop(dialogContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      child: const tab.TextWidget(
                                        text: 'Select',
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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
Widget _tabDialogLabel(String text) {
  return tab.TextWidget(
    text: text,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF6B7280),
  );
}

Widget _tabDialogInputLike({
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
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
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}

Widget _tabBuildDropdown({
  required String? value,
  required List<Map<String, String>> items,
  required ValueChanged<String?> onChanged,
  Color? iconColor,
  String? hint,
}) {
  List<Map<String, String>> dropdownItems = List.from(items);
  if (value != null && value.isNotEmpty) {
    final hasValue = items.any((item) => item['value'] == value);
    if (!hasValue) {
      dropdownItems.add({
        'label': 'Custom Color ($value)',
        'value': value,
        'hex': value.startsWith('#') ? value : '#3B82F6',
      });
    }
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD1D5DB)),
      color: Colors.white,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        menuMaxHeight: 350,
        hint: hint != null
            ? tab.TextWidget(
                text: hint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              )
            : null,
        isExpanded: true,
        isDense: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(6),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Color(0xFF6B7280),
        ),
        items: dropdownItems.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Row(
              children: [
                if (item.containsKey('svg_url') && item['svg_url']!.isNotEmpty) ...[
                  SvgPicture.network(
                    item['svg_url']!,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      iconColor ?? const Color(0xFF6B7280),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (item.containsKey('hex')) ...[
                  Container(
                    width: 14,
                    height: 14,
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
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: tab.TextWidget(
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

Future<void> showManageCategoriesDialogTablet(BuildContext context) async {
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
            ContractsDialogSections.refreshCategories(context).then((_) {
              if (dialogContext.mounted) {
                setState(() => isInitialLoading = false);
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 500,
                ),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      color: Colors.black,
                      child: Row(
                        children: [
                          const tab.TextWidget(
                            text: 'Manage Categories',
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

                    // Scrollable Category list
                    Flexible(
                      child: isInitialLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (ContractsDialogSections.categoryOptions.isNotEmpty) ...[
                                    ...ContractsDialogSections.categoryOptions.map((cat) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: tab.TextWidget(
                                                text: cat['label'] ?? '',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF111827),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  editingId = cat['value'];
                                                  categoryCtrl.text = cat['label'] ?? '';
                                                });
                                              },
                                              child: const tab.TextWidget(
                                                text: 'Edit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
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
                                                        final headers = await ContractsDialogSections.getHeaders();
                                                        final res = await ApiService().postDataToApi(
                                                          api: 'rule-categories/$id',
                                                          isDelete: true,
                                                          headers: headers,
                                                          showRes: true,
                                                        );

                                                        if (res != null && res['success'] == true) {
                                                          setState(() {
                                                            ContractsDialogSections.categoryOptions
                                                                .removeWhere((e) => e['value'] == id);
                                                          });
                                                          showToast(message: 'Category deleted successfully');
                                                        }
                                                      } catch (e) {
                                                        // Handle error
                                                      } finally {
                                                        if (dialogContext.mounted) {
                                                          setState(() {
                                                            isAdding = false;
                                                          });
                                                        }
                                                      }
                                                    },
                                              child: const tab.TextWidget(
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

                    // Add/Edit Box at the bottom
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 1,
                            color: const Color(0xFFE5E7EB),
                            margin: const EdgeInsets.only(bottom: 12),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: categoryCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'New category name',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                          final headers = await ContractsDialogSections.getHeaders();
                                          final res = await ApiService().postDataToApi(
                                            api: editingId != null
                                                ? 'rule-categories/$editingId'
                                                : 'rule-categories',
                                            isPut: editingId != null,
                                            headers: headers,
                                            payload: {'name': name},
                                            showRes: true,
                                          );

                                          if (res != null && res['success'] == true) {
                                            if (editingId != null) {
                                              final index = ContractsDialogSections.categoryOptions
                                                  .indexWhere((e) => e['value'] == editingId);
                                              if (index != -1) {
                                                setState(() {
                                                  ContractsDialogSections.categoryOptions[index]['label'] = name;
                                                });
                                              }
                                            } else {
                                              final cat = res['category'];
                                              if (cat != null) {
                                                setState(() {
                                                  ContractsDialogSections.categoryOptions.add({
                                                    "value": cat['id'].toString(),
                                                    "label": cat['name'].toString(),
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
                                          if (dialogContext.mounted) {
                                            setState(() {
                                              isAdding = false;
                                            });
                                          }
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdding
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: isAdding
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : tab.TextWidget(
                                          text: editingId != null ? 'Save' : 'Add',
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
