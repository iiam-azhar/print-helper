import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../constants/colors.dart';

class MobileProjectsFormScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const MobileProjectsFormScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 30.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.w)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            12.h,
            16.w,
            16.h + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6DA),
                  borderRadius: BorderRadius.circular(99.w),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 18.sp),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileProjectsCreateFormBody extends StatelessWidget {
  const MobileProjectsCreateFormBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _InputField(label: 'Project Name', hint: 'Type Project Name'),
        const _InputField(label: 'Project ID', hint: 'Type Project ID'),
        const _InputField(label: 'Task', hint: 'Type Task'),
        const _InputField(
          label: 'Client / Company Name',
          hint: 'Type Client / Company Name',
        ),
        const _InputField(
          label: 'Customer / Company Name',
          hint: 'Type Customer / Company Name',
        ),
        const _InputField(label: 'Contact Name', hint: 'Type Contact Name'),
        const _InputField(
          label: 'Customer Last Name',
          hint: 'Type Customer Last Name',
        ),
        const _InputField(
          label: 'Assigned to Name',
          hint: 'Select',
          dropdown: true,
        ),
        const _InputField(
          label: 'Date Added',
          hint: 'January 13, 2026',
          icon: Icons.calendar_today_outlined,
        ),
        const _InputField(
          label: 'To',
          hint: 'January 19, 2026',
          icon: Icons.calendar_today_outlined,
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _actionButton(context, 'Clear', false),
            SizedBox(width: 10.w),
            _actionButton(context, 'Create New', true),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String text, bool filled) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(99.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: filled ? AppColors.btnClr : Colors.white,
          borderRadius: BorderRadius.circular(99.w),
          border: Border.all(
            color: filled ? AppColors.btnClr : const Color(0xFFD5D5DA),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class MobileProjectsFilterFormBody extends StatelessWidget {
  const MobileProjectsFilterFormBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _InputField(label: 'Status', hint: 'Select', dropdown: true),
        const _InputField(label: 'Sort by', hint: 'Select', dropdown: true),
        const _InputField(label: 'Late Tasks', hint: 'Yes / No', toggle: true),
        const _InputField(label: 'Project Name', hint: 'Type Project Name'),
        const _InputField(label: 'Project ID', hint: 'Type Project ID'),
        const _InputField(label: 'Task', hint: 'Type Task'),
        const _InputField(label: 'Client Name', hint: 'Type Client Name'),
        const _InputField(
          label: 'Customer Last Name',
          hint: 'Type Customer Last Name',
        ),
        const _InputField(
          label: 'Assigned to Name',
          hint: 'Select',
          dropdown: true,
        ),
        const _InputField(
          label: 'Date Added',
          hint: 'January 13, 2026',
          icon: Icons.calendar_today_outlined,
        ),
        const _InputField(
          label: 'To',
          hint: 'January 19, 2026',
          icon: Icons.calendar_today_outlined,
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _actionButton(context, 'Clear', false),
            SizedBox(width: 10.w),
            _actionButton(context, 'Save', true),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String text, bool filled) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(99.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: filled ? AppColors.btnClr : Colors.white,
          borderRadius: BorderRadius.circular(99.w),
          border: Border.all(
            color: filled ? AppColors.btnClr : const Color(0xFFD5D5DA),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final bool dropdown;
  final bool toggle;
  final IconData? icon;

  const _InputField({
    required this.label,
    required this.hint,
    this.dropdown = false,
    this.toggle = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF777780),
            ),
          ),
          SizedBox(height: 6.h),
          if (toggle)
            Row(
              children: [
                Text(
                  'No',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8.w),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeThumbColor: AppColors.btnClr,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Yes',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Container(
              height: 42.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(12.w),
                border: Border.all(color: const Color(0xFFE1E1E6)),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15.sp, color: const Color(0xFF8A8A95)),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFAAAAB3),
                      ),
                    ),
                  ),
                  if (dropdown)
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 13.sp,
                      color: const Color(0xFF8A8A95),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
