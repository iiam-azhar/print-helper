import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/admin/settings/contracts_dialog_sections.dart';
import 'package:print_helper/models/checklist_model.dart';
import 'package:print_helper/services/api_service.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<bool?> showAddCheckListDialogMobile(
  BuildContext context, {
  ChecklistModel? existingChecklist,
}) async {
  final nameCtrl = TextEditingController(text: existingChecklist?.name);
  String? selectedType = existingChecklist?.listType;
  String? selectedUserType = existingChecklist?.userType;
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

  if (selectedUserType != null && selectedUserType.contains(',')) {
    selectedUserType = selectedUserType.split(',').first.trim();
  }

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
                              text: existingChecklist != null
                                  ? 'Edit Check List'
                                  : 'Add New Check List',
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
                              Row(
                                children: [
                                  _dialogLabel('CHECK LIST NAME'),
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
                                controller: nameCtrl,
                                hint: 'e.g. Client Onboarding',
                                errorText: nameError,
                                onChanged: (_) {
                                  if (nameError != null) {
                                    setState(() => nameError = null);
                                  }
                                },
                              ),
                              SizedBox(height: 14.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _dialogLabel('TYPE'),
                                            const TextWidget(
                                              text: ' *',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 7.h),
                                        _buildDropdown(
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
                                        if (typeError != null)
                                          _errorText(typeError!),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _dialogLabel('USER TYPE'),
                                            const TextWidget(
                                              text: ' *',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 7.h),
                                        _buildDropdown(
                                          value: selectedUserType,
                                          hint: 'Select user type...',
                                          items: ContractsDialogSections.checkListUserTypes,
                                          onChanged: (val) {
                                            setState(() {
                                              selectedUserType = val;
                                              userTypeError = null;
                                            });
                                          },
                                        ),
                                        if (userTypeError != null)
                                          _errorText(userTypeError!),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.h),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _dialogLabel('ICON'),
                                        SizedBox(height: 7.h),
                                        _buildDropdown(
                                          value: selectedIcon,
                                          hint: 'Select Icon',
                                          items: ContractsDialogSections.checkListIcons,
                                          iconColor: ContractsDialogSections.getColorFromValue(
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
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _dialogLabel('ICON COLOR'),
                                        SizedBox(height: 7.h),
                                        _buildDropdown(
                                          value: selectedColor,
                                          hint: 'Select Color',
                                          items: ContractsDialogSections.checkListColors,
                                          onChanged: (val) {
                                            setState(() {
                                              selectedColor = val;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _dialogLabel('PICKER'),
                                      SizedBox(height: 7.h),
                                      GestureDetector(
                                        onTap: () {
                                          _showColorPickerDialogMobile(
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
                                          width: 36.w,
                                          height: 36.w,
                                          decoration: BoxDecoration(
                                            color:
                                                ContractsDialogSections.getColorFromValue(
                                                  selectedColor ?? '',
                                                  const Color(0xFF3B82F6),
                                                ),
                                            borderRadius: BorderRadius.circular(6.r),
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
                              SizedBox(height: 14.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36.w,
                                      height: 36.w,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD1D5DB),
                                        ),
                                      ),
                                      child: ContractsDialogSections.buildChecklistPreviewIcon(
                                        selectedIcon,
                                        selectedColor,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    const TextWidget(
                                      text: 'Checklist Preview',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 14.h),
                              _dialogLabel('CHECK LIST ITEMS'),
                              SizedBox(height: 8.h),
                              ...List.generate(itemCtrls.length, (index) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _dialogInputLike(
                                          controller: itemCtrls[index],
                                          hint: 'Item name...',
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
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
                                            width: 12,
                                            height: 12,
                                            fit: BoxFit.contain,
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
                                  padding: EdgeInsets.symmetric(
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: const Center(
                                    child: TextWidget(
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
                      Container(height: 1.h, color: const Color(0xFFE5E7EB)),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          14.h,
                          20.w,
                          16.h + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: isCreating
                                    ? null
                                    : () async {
                                        final name = nameCtrl.text.trim();
                                        bool hasError = false;

                                        if (name.isEmpty) {
                                          setState(
                                            () => nameError =
                                                'Name is required',
                                          );
                                          hasError = true;
                                        }
                                        if (selectedType == null) {
                                          setState(
                                            () => typeError =
                                                'Type is required',
                                          );
                                          hasError = true;
                                        }
                                        if (selectedUserType == null) {
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
                                            "user_types": selectedUserType != null ? [selectedUserType] : [],
                                            "icon": selectedIcon,
                                            "icon_color": selectedColorHex,
                                            "items": items,
                                          };

                                          debugPrint(
                                            "${existingChecklist != null ? 'UPDATE' : 'CREATE'} CHECKLIST BODY: $payload",
                                          );

                                          final res = await ApiService()
                                              .postDataToApi(
                                                api: existingChecklist != null
                                                    ? 'checklists/${existingChecklist.id}'
                                                    : 'checklists',
                                                isPut:
                                                    existingChecklist != null,
                                                headers: await ContractsDialogSections.getHeaders(),
                                                payload: payload,
                                                showRes: true,
                                              );

                                          debugPrint(
                                            "${existingChecklist != null ? 'UPDATE' : 'CREATE'} CHECKLIST RESPONSE: $res",
                                          );

                                          if (res != null &&
                                              res['success'] == true) {
                                            showToast(
                                              message:
                                                  existingChecklist != null
                                                  ? 'Checklist updated successfully'
                                                  : 'Checklist created successfully',
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
                                                  res?['message'] ??
                                                  'Failed to ${existingChecklist != null ? 'update' : 'create'} checklist',
                                            );
                                          }
                                        } catch (e) {
                                          showToast(message: e.toString());
                                        } finally {
                                          if (sheetContext.mounted) {
                                            setState(() {
                                              isCreating = false;
                                            });
                                          }
                                        }
                                      },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCreating
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Center(
                                    child: isCreating
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
                                            text: existingChecklist != null
                                                ? 'Update Check List'
                                                : 'Create Check List',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(sheetContext),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: const Center(
                                    child: TextWidget(
                                      text: 'Cancel',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B5563),
                                    ),
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
              );
            },
          );
        },
      );
    },
  );
}

Widget _dialogLabel(String text) {
  return TextWidget(
    text: text,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF6B7280),
  );
}

Widget _errorText(String message) {
  return Padding(
    padding: EdgeInsets.only(top: 4.h, left: 4.w),
    child: TextWidget(
      text: message,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: const Color(0xFFEF4444),
    ),
  );
}

Widget _dialogInputLike({
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
        borderSide: const Color(0xFF9CA3AF) != Colors.transparent
            ? const BorderSide(color: Color(0xFF9CA3AF))
            : const BorderSide(color: Color(0xFFD1D5DB)),
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

Widget _buildDropdown({
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
        items: dropdownItems.map((item) {
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

void _showColorPickerDialogMobile(
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
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Container(
                width: 340.w,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Icon Color',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: Icon(
                            Icons.close,
                            size: 18.w,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TabBar(
                      labelColor: const Color(0xFF3B82F6),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFF3B82F6),
                      labelStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: TextStyle(fontSize: 12.sp),
                      tabs: const [
                        Tab(text: 'Presets'),
                        Tab(text: 'Custom'),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      height: 330.h,
                      child: TabBarView(
                        children: [
                          // Tab 1: Presets
                          SingleChildScrollView(
                            child: Wrap(
                              spacing: 12.w,
                              runSpacing: 12.h,
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
                                      width: 44.w,
                                      height: 44.w,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.black
                                              : const Color(0xFFE5E7EB),
                                          width: isSelected ? 3.w : 1.5.w,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withAlpha(102),
                                                  blurRadius: 6.r,
                                                  offset: Offset(0, 2.h),
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
                                              size: 20.w,
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
                                  width: 240.w,
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
                                    colorPickerWidth: 180,
                                    portraitOnly: true,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    ElevatedButton(
                                      onPressed: () {
                                        final hex =
                                            '#${tempColor.toARGB32().toRadixString(16).substring(2, 8)}';
                                        onColorSelected(hex);
                                        Navigator.pop(dialogContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 8.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Select',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
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
