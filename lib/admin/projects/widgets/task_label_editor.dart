import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/widgets/text_widget.dart';

import '../../../models/projects_models.dart';

class TaskDraftLabel {
  final int id;
  final String name;
  final String colorHex;

  const TaskDraftLabel({
    required this.id,
    required this.name,
    required this.colorHex,
  });
}

List<TaskDraftLabel> buildInitialTaskDraftLabels({
  required List<ProjectLabelModel> projectLabels,
  required List<ProjectTaskLabel> taskLabels,
}) {
  final merged = <TaskDraftLabel>[];
  final seenById = <int>{};
  final seenByName = <String>{};

  for (final label in projectLabels) {
    final name = label.name.trim();
    if (name.isEmpty) continue;
    final normalizedName = name.toLowerCase();
    if (label.id > 0 && seenById.contains(label.id)) continue;
    if (seenByName.contains(normalizedName)) continue;

    merged.add(
      TaskDraftLabel(id: label.id, name: label.name, colorHex: label.color),
    );
    if (label.id > 0) seenById.add(label.id);
    seenByName.add(normalizedName);
  }

  for (final label in taskLabels) {
    final name = label.name.trim();
    if (name.isEmpty) continue;
    final normalizedName = name.toLowerCase();
    if (label.id > 0 && seenById.contains(label.id)) continue;
    if (seenByName.contains(normalizedName)) continue;

    merged.add(
      TaskDraftLabel(id: label.id, name: label.name, colorHex: label.color),
    );
    if (label.id > 0) seenById.add(label.id);
    seenByName.add(normalizedName);
  }

  return merged;
}

Widget buildSelectedTaskLabelChips({
  required List<TaskDraftLabel> labels,
  required Set<int> selectedLabelIds,
  required Widget Function(String label, Color color, VoidCallback? onRemove)
  chipBuilder,
  required Color Function(String hex) colorFromHex,
  required VoidCallback onSelectionChanged,
}) {
  final selectedLabels = labels
      .where((label) => selectedLabelIds.contains(label.id))
      .toList();

  if (selectedLabels.isEmpty) {
    return const SizedBox.shrink();
  }

  return Wrap(
    spacing: 6.w,
    runSpacing: 6.h,
    children: [
      for (final label in selectedLabels)
        chipBuilder(
          label.name,
          colorFromHex(label.colorHex),
          label.id > 0
              ? () {
                  selectedLabelIds.remove(label.id);
                  onSelectionChanged();
                }
              : null,
        ),
    ],
  );
}

Future<void> showTaskLabelEditorDialog({
  required BuildContext context,
  required List<TaskDraftLabel> labels,
  required Set<int> selectedLabelIds,
  required VoidCallback onChanged,
  required Color Function(String hex) colorFromHex,
  required Future<TaskDraftLabel?> Function(String name, String colorHex)
  onCreateLabel,
  required Future<bool> Function(int labelId) onDeleteLabel,
}) async {
  final newLabelController = TextEditingController();
  final palette = [
    const Color(0xFFD23B3B),
    const Color(0xFFE67E22),
    const Color(0xFFF1C40F),
    const Color(0xFF27AE60),
    const Color(0xFF2E86C1),
    const Color(0xFF8E44AD),
    const Color(0xFFE84393),
    const Color(0xFF95A5A6),
  ];

  Color selectedColor = palette.first;
  bool isCreating = false;
  final deletingLabelIds = <int>{};

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (popupContext) {
      return StatefulBuilder(
        builder: (context, setPopupState) {
          final availableLabels = labels;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 34.w),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 288.w,
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.w),
                border: Border.all(color: const Color(0xFFD7D7D7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextWidget(
                        text: 'Label (optional)',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(popupContext).pop(),
                          child: Container(
                            width: 20.w,
                            height: 20.h,
                            alignment: Alignment.center,
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 13.sp,
                              color: const Color(0xFF0C0C0C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  SizedBox(height: 5.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 120.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableLabels.length,
                      separatorBuilder: (_, _) => SizedBox(height: 4.h),
                      itemBuilder: (_, index) {
                        final label = availableLabels[index];
                        final isSelected = selectedLabelIds.contains(label.id);
                        final canDelete = label.id > 0;
                        final isDeleting = deletingLabelIds.contains(label.id);

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 7.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF1F3F7)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (isSelected) {
                                      selectedLabelIds.remove(label.id);
                                    } else {
                                      selectedLabelIds.add(label.id);
                                    }
                                    setPopupState(() {});
                                    onChanged();
                                  },
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 2.w,
                                      vertical: 2.h,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10.w,
                                          height: 10.h,
                                          decoration: BoxDecoration(
                                            color: colorFromHex(label.colorHex),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            label.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF353841),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? CupertinoIcons.checkmark_alt
                                              : CupertinoIcons.circle,
                                          size: 12.sp,
                                          color: isSelected
                                              ? const Color(0xFF2E86C1)
                                              : const Color(0xFFB7BCC5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              if (canDelete)
                                GestureDetector(
                                  onTap: isDeleting
                                      ? null
                                      : () async {
                                          setPopupState(
                                            () =>
                                                deletingLabelIds.add(label.id),
                                          );
                                          final deleted = await onDeleteLabel(
                                            label.id,
                                          );
                                          if (deleted) {
                                            labels.removeWhere(
                                              (item) => item.id == label.id,
                                            );
                                            selectedLabelIds.remove(label.id);
                                            onChanged();
                                          }
                                          setPopupState(
                                            () => deletingLabelIds.remove(
                                              label.id,
                                            ),
                                          );
                                        },
                                  child: Icon(
                                    CupertinoIcons.delete,
                                    size: 14.sp,
                                    color: const Color(0xFF8D919A),
                                  ),
                                )
                              else
                                SizedBox(width: 14.w),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(height: 10.h, color: const Color(0xFFD3D3D3)),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      for (final color in palette)
                        GestureDetector(
                          onTap: () =>
                              setPopupState(() => selectedColor = color),
                          child: Container(
                            margin: EdgeInsets.only(right: 7.w),
                            width: 18.w,
                            height: 18.h,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? const Color(0xFF22252B)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 30.h,
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6.w),
                            border: Border.all(color: const Color(0xFFD2D6DC)),
                          ),
                          child: TextField(
                            controller: newLabelController,
                            decoration: const InputDecoration(
                              hintText: 'New label',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: TextStyle(fontSize: 9.5.sp),
                          ),
                        ),
                      ),
                      SizedBox(width: 7.w),
                      SizedBox(
                        height: 30.h,
                        child: ElevatedButton(
                          onPressed: isCreating
                              ? null
                              : () async {
                                  final text = newLabelController.text.trim();
                                  if (text.isEmpty) return;

                                  final colorHex =
                                      '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

                                  setPopupState(() => isCreating = true);
                                  final createdLabel = await onCreateLabel(
                                    text,
                                    colorHex,
                                  );
                                  if (createdLabel == null) {
                                    setPopupState(() => isCreating = false);
                                    return;
                                  }

                                  final existingIndex = labels.indexWhere(
                                    (item) => item.id == createdLabel.id,
                                  );
                                  if (existingIndex >= 0) {
                                    labels[existingIndex] = createdLabel;
                                  } else {
                                    labels.add(createdLabel);
                                  }

                                  selectedLabelIds.add(createdLabel.id);
                                  newLabelController.clear();
                                  setPopupState(() => isCreating = false);
                                  onChanged();
                                },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFF0F1F5),
                            foregroundColor: const Color(0xFF4D5663),
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.w),
                              side: const BorderSide(color: Color(0xFFD2D6DC)),
                            ),
                          ),
                          child: Text(
                            isCreating ? 'Adding...' : 'Add',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  newLabelController.dispose();
}
