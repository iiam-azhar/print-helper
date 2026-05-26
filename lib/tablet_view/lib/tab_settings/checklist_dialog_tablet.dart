import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/admin/settings/contracts_dialog_sections.dart';
import 'package:print_helper/models/checklist_model.dart';
import 'package:print_helper/services/api_service.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_text_widget.dart'
    as tab;
import 'package:print_helper/widgets/toasts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<bool?> showAddCheckListDialogTablet(
  BuildContext context, {
  ChecklistModel? existingChecklist,
}) async {
  final nameCtrl = TextEditingController(text: existingChecklist?.name);
  String? selectedType = existingChecklist?.listType;
  String? selectedIcon = existingChecklist?.icon;
  String? selectedColor = existingChecklist?.iconColor;
  final List<TextEditingController> itemCtrls = existingChecklist != null
      ? existingChecklist.items
            .map((e) => TextEditingController(text: e))
            .toList()
      : [TextEditingController()];

  String? nameError;
  String? typeError;
  String? userTypeError;
  bool isCreating = false;

  // Refresh options from API
  await ContractsDialogSections.refreshChecklistOptions(context);

  if (!context.mounted) return null;

  final colorVal = selectedColor;
  if (colorVal != null && colorVal.startsWith('#')) {
    final match = ContractsDialogSections.checkListColors.firstWhere(
      (e) => e['hex']?.toLowerCase() == colorVal.toLowerCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      selectedColor = match['value'];
    }
  }

  final List<String> selectedUserTypes = existingChecklist != null
      ? existingChecklist.userType
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .toList()
      : [];

  return await showDialog<bool?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                  maxHeight: 750,
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
                        vertical: 12,
                      ),
                      color: Colors.black,
                      child: Row(
                        children: [
                          tab.TextWidget(
                            text: existingChecklist != null
                                ? 'Edit Check List'
                                : 'Add New Check List',
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
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body Scroll Area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checklist Name
                            Row(
                              children: [
                                _tabDialogLabel('CHECK LIST NAME'),
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
                              controller: nameCtrl,
                              hint: 'e.g. Client Onboarding',
                              errorText: nameError,
                              onChanged: (_) {
                                if (nameError != null) {
                                  setState(() => nameError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Type
                            Row(
                              children: [
                                _tabDialogLabel('TYPE'),
                                const tab.TextWidget(
                                  text: ' *',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _tabBuildDropdown(
                              value: selectedType,
                              hint: 'Select Type',
                              items: ContractsDialogSections.checkListTypes,
                              onChanged: (val) {
                                setState(() {
                                  selectedType = val;
                                  typeError = null;
                                });
                              },
                            ),
                            if (typeError != null) _tabErrorText(typeError!),
                            const SizedBox(height: 16),

                            // Applies to User Types Checkbox Container
                            Row(
                              children: [
                                _tabDialogLabel('APPLIES TO USER TYPES'),
                                const tab.TextWidget(
                                  text: ' *',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const tab.TextWidget(
                              text:
                                  'Select one or more roles that share this checklist.',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                ),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: ContractsDialogSections
                                    .checkListUserTypes
                                    .map((ut) {
                                      final val = ut['value'] ?? '';
                                      final label = ut['label'] ?? '';
                                      final isChecked = selectedUserTypes.any(
                                        (e) => e.trim().toLowerCase() == val.trim().toLowerCase(),
                                      );
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isChecked) {
                                              selectedUserTypes.removeWhere(
                                                (e) => e.trim().toLowerCase() == val.trim().toLowerCase(),
                                              );
                                            } else {
                                              selectedUserTypes.removeWhere(
                                                (e) => e.trim().toLowerCase() == val.trim().toLowerCase(),
                                              );
                                              selectedUserTypes.add(val);
                                            }
                                            userTypeError = null;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Checkbox(
                                                  value: isChecked,
                                                  activeColor: const Color(
                                                    0xFF22C55E,
                                                  ),
                                                  onChanged: (bool? checked) {
                                                    setState(() {
                                                      if (checked == true) {
                                                        selectedUserTypes.removeWhere(
                                                          (e) => e.trim().toLowerCase() == val.trim().toLowerCase(),
                                                        );
                                                        selectedUserTypes.add(val);
                                                      } else {
                                                        selectedUserTypes.removeWhere(
                                                          (e) => e.trim().toLowerCase() == val.trim().toLowerCase(),
                                                        );
                                                      }
                                                      userTypeError = null;
                                                    });
                                                  },
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              tab.TextWidget(
                                                text: label,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF1F2937),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                            if (userTypeError != null)
                              _tabErrorText(userTypeError!),
                            const SizedBox(height: 16),

                            // Icon, Icon Color, Picker
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _tabDialogLabel('ICON'),
                                      const SizedBox(height: 6),
                                      _tabBuildDropdown(
                                        value: selectedIcon,
                                        hint: 'Select Icon',
                                        items: ContractsDialogSections
                                            .checkListIcons,
                                        iconColor:
                                            ContractsDialogSections.getColorFromValue(
                                              selectedColor ?? '',
                                              const Color(0xFF6B7280),
                                            ),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedIcon = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _tabDialogLabel('ICON COLOR'),
                                      const SizedBox(height: 6),
                                      _tabBuildDropdown(
                                        value: selectedColor,
                                        hint: 'Select Color',
                                        items: ContractsDialogSections
                                            .checkListColors,
                                        onChanged: (val) {
                                          setState(() {
                                            selectedColor = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _tabDialogLabel('PICKER'),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () {
                                        _showColorPickerDialog(
                                          context,
                                          selectedColor,
                                          (colorVal) {
                                            setState(() {
                                              selectedColor = colorVal;
                                            });
                                          },
                                        );
                                      },
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color:
                                              ContractsDialogSections.getColorFromValue(
                                                selectedColor ?? '',
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
                                    child:
                                        ContractsDialogSections.buildChecklistPreviewIcon(
                                          selectedIcon,
                                          selectedColor,
                                          customSize: 16,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  const tab.TextWidget(
                                    text: 'Checklist Preview',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Items
                            _tabDialogLabel('CHECK LIST ITEMS'),
                            const SizedBox(height: 8),
                            ...List.generate(itemCtrls.length, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _tabDialogInputLike(
                                        controller: itemCtrls[index],
                                        hint: 'Item name...',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        if (itemCtrls.length <= 1) return;
                                        setState(() {
                                          itemCtrls.removeAt(index);
                                        });
                                      },
                                      child: Center(
                                        child: ImageWidget(
                                          image: Paths.delete,
                                          width: 10,
                                          height: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  itemCtrls.add(TextEditingController());
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: tab.TextWidget(
                                    text: '+ Add Item',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider and Action Buttons
                    Container(height: 1, color: const Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: isCreating
                                ? null
                                : () async {
                                    final name = nameCtrl.text.trim();
                                    bool hasError = false;

                                    if (name.isEmpty) {
                                      setState(
                                        () => nameError = 'Name is required',
                                      );
                                      hasError = true;
                                    }
                                    if (selectedType == null) {
                                      setState(
                                        () => typeError = 'Type is required',
                                      );
                                      hasError = true;
                                    }
                                    if (selectedUserTypes.isEmpty) {
                                      setState(
                                        () => userTypeError =
                                            'User type is required',
                                      );
                                      hasError = true;
                                    }

                                    if (hasError) return;

                                    setState(() {
                                      isCreating = true;
                                    });

                                    try {
                                      final items = itemCtrls
                                          .map((c) => c.text.trim())
                                          .where((t) => t.isNotEmpty)
                                          .toList();

                                      final selectedColorHex = ContractsDialogSections.checkListColors.firstWhere(
                                        (e) => e['value'] == selectedColor,
                                        orElse: () => {},
                                      )['hex'] ?? selectedColor;

                                      final payload = {
                                        "name": name,
                                        "list_type": selectedType,
                                        "user_types": selectedUserTypes,
                                        "icon": selectedIcon,
                                        "icon_color": selectedColorHex,
                                        "items": items,
                                      };

                                      debugPrint(
                                        "${existingChecklist != null ? 'UPDATE' : 'CREATE'} CHECKLIST BODY: $payload",
                                      );

                                      final res = await ApiService().postDataToApi(
                                        api: existingChecklist != null
                                            ? 'checklists/${existingChecklist.id}'
                                            : 'checklists',
                                        isPut: existingChecklist != null,
                                        headers:
                                            await ContractsDialogSections.getHeaders(),
                                        payload: payload,
                                        showRes: true,
                                      );

                                      debugPrint(
                                        "${existingChecklist != null ? 'UPDATE' : 'CREATE'} CHECKLIST RESPONSE: $res",
                                      );

                                      if (res != null &&
                                          res['success'] == true) {
                                        showToast(
                                          message: existingChecklist != null
                                              ? 'Checklist updated successfully'
                                              : 'Checklist created successfully',
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext, true);
                                        }
                                      } else {
                                        showToast(
                                          message:
                                              res?['message'] ??
                                              'Failed to ${existingChecklist != null ? 'update' : 'create'} checklist',
                                        );
                                      }
                                    } catch (e) {
                                      showToast(message: e.toString());
                                    } finally {
                                      if (dialogContext.mounted) {
                                        setState(() {
                                          isCreating = false;
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
                                color: isCreating
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: isCreating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : tab.TextWidget(
                                        text: existingChecklist != null
                                            ? 'Update Check List'
                                            : 'Create Check List',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                              child: const Center(
                                child: tab.TextWidget(
                                  text: 'Cancel',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
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

Widget _tabDialogLabel(String text) {
  return tab.TextWidget(
    text: text,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF6B7280),
  );
}

Widget _tabErrorText(String message) {
  return Padding(
    padding: const EdgeInsets.only(top: 4, left: 4),
    child: tab.TextWidget(
      text: message,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: const Color(0xFFEF4444),
    ),
  );
}

Widget _tabDialogInputLike({
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
      errorStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Color(0xFFEF4444),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
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
                if (item.containsKey('svg_url') &&
                    item['svg_url']!.isNotEmpty) ...[
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

void _showColorPickerDialog(
  BuildContext context,
  String? currentColor,
  ValueChanged<String> onColorSelected,
) {
  Color parsedCurrentColor = const Color(0xFF3B82F6);
  if (currentColor != null) {
    if (currentColor.startsWith('#')) {
      parsedCurrentColor = Color(int.parse(currentColor.replaceAll('#', '0xFF')));
    } else {
      parsedCurrentColor = ContractsDialogSections.getColorFromValue(
        currentColor,
        const Color(0xFF3B82F6),
      );
    }
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
                      tabs: [
                        Tab(text: 'Presets'),
                        Tab(text: 'Custom'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 310,
                      child: TabBarView(
                        children: [
                          // Tab 1: Presets
                          SingleChildScrollView(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: ContractsDialogSections.checkListColors.map((item) {
                                final hexStr = item['hex'] ?? '#3B82F6';
                                final label = item['label'] ?? '';
                                final value = item['value'] ?? '';
                                final color = Color(
                                  int.parse(hexStr.replaceAll('#', '0xFF')),
                                );
                                final isSelected = currentColor == value ||
                                    (currentColor != null &&
                                        currentColor.toLowerCase() == hexStr.toLowerCase());
                                final useDarkCheck = color.computeLuminance() > 0.6;

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
                                                )
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

                          // Tab 2: Custom Color
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: ColorPicker(
                                    pickerColor: tempColor,
                                    onColorChanged: (color) {
                                      setStateDialog(() {
                                        tempColor = color;
                                      });
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
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                      },
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
