import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/settings_models.dart';
import '../../providers/setting_pro.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';

class FileSettingsMobile extends StatefulWidget {
  const FileSettingsMobile({super.key});

  @override
  State<FileSettingsMobile> createState() => _FileSettingsMobileState();
}

class _FileSettingsMobileState extends State<FileSettingsMobile> {
  final TextEditingController _maxUploadController = TextEditingController();
  final TextEditingController _adminLimitController = TextEditingController();
  final TextEditingController _staffLimitController = TextEditingController();
  final TextEditingController _clientLimitController = TextEditingController();
  final TextEditingController _customerLimitController =
      TextEditingController();
  List<FileExtensionItem> _extensions = [];
  String _signature = '';

  static const String _adminRoleId = '1';
  static const String _staffRoleId = '2';
  static const String _clientRoleId = '4';
  static const String _customerRoleId = '5';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsPro>().fileSettings;
    final signature = _buildSignature(settings);
    if (_signature != signature) {
      _signature = signature;
      _hydrateControllers(settings);
    }
  }

  @override
  void dispose() {
    _maxUploadController.dispose();
    _adminLimitController.dispose();
    _staffLimitController.dispose();
    _clientLimitController.dispose();
    _customerLimitController.dispose();
    super.dispose();
  }

  void _hydrateControllers(FileSettingsConfig settings) {
    _maxUploadController.text = settings.maxUploadSizeMb.toString();
    _adminLimitController.text = (settings.storageLimitsMb[_adminRoleId] ?? 0)
        .toString();
    _staffLimitController.text = (settings.storageLimitsMb[_staffRoleId] ?? 0)
        .toString();
    _clientLimitController.text = (settings.storageLimitsMb[_clientRoleId] ?? 0)
        .toString();
    _customerLimitController.text =
        (settings.storageLimitsMb[_customerRoleId] ?? 0).toString();
    _extensions = settings.allowedExtensions.map((e) => e.copyWith()).toList();
  }

  String _buildSignature(FileSettingsConfig settings) {
    final limits = settings.storageLimitsMb;
    final extJoined = settings.allowedExtensions
        .map((e) => '${e.extension}:${e.icon ?? ''}')
        .join(',');
    return '${settings.maxUploadSizeMb}|${limits[_adminRoleId]}|${limits[_staffRoleId]}|${limits[_clientRoleId]}|${limits[_customerRoleId]}|$extJoined';
  }

  int _parseInt(String value, int fallback) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  String _normalizeExtension(String raw) {
    var ext = raw.trim().toLowerCase();
    if (ext.startsWith('.')) {
      ext = ext.substring(1);
    }
    return ext;
  }

  void _addExtensionDialog() {
    final ctrl = TextEditingController();
    String? svgFileName;
    String? svgFilePath;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setStateDialog) {
            final mediaQuery = MediaQuery.of(sheetContext);
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: AppColors.formHint,
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        TextWidget(
                          text: 'Add File Extension',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                        SizedBox(height: 18.h),
                        TextWidget(
                          text: 'Extension',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.txtClr1,
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: ctrl,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Example: pdf',
                            filled: true,
                            fillColor: AppColors.fill,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppColors.formHint,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppColors.formHint,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppColors.formHint,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        TextWidget(
                          text: 'Upload SVG Icon',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.txtClr1,
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.fill,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.formHint),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      final picked = await FilePicker.platform
                                          .pickFiles(
                                            allowMultiple: false,
                                            type: FileType.custom,
                                            allowedExtensions: const ['svg'],
                                            withData: false,
                                          );
                                      if (picked != null &&
                                          picked.files.isNotEmpty &&
                                          picked.files.first.name
                                              .toLowerCase()
                                              .endsWith('.svg')) {
                                        setStateDialog(() {
                                          svgFileName = picked.files.first.name;
                                          svgFilePath = picked.files.first.path;
                                        });
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.txtClr1,
                                      side: const BorderSide(
                                        color: AppColors.formHint,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 10.h,
                                      ),
                                    ),
                                    child: TextWidget(
                                      text: 'Choose SVG',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.txtClr1,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: TextWidget(
                                      text: svgFileName ?? 'No file chosen',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.hint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10.h),
                              const TextWidget(
                                text:
                                    'Recommended: simple monochrome SVG, up to 512KB.',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.hint,
                              ),
                              if (svgFilePath != null &&
                                  svgFilePath!.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Container(
                                    width: 54.w,
                                    height: 54.h,
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(10.r),
                                      border: Border.all(
                                        color: AppColors.formHint,
                                      ),
                                    ),
                                    child: SvgPicture.file(
                                      File(svgFilePath!),
                                      fit: BoxFit.contain,
                                      placeholderBuilder: (context) =>
                                          const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 102.w,
                              child: CustomButton(
                                title: 'Cancel',
                                onTap: () => Navigator.pop(sheetContext),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                buttonColor: AppColors.white,
                                textColor: AppColors.black,
                                borderColor: AppColors.formHint,
                                showBorder: true,
                                borderRadius: 12,
                                stadium: false,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            SizedBox(
                              width: 78.w,
                              child: CustomButton(
                                title: 'Add',
                                onTap: () {
                                  final ext = _normalizeExtension(ctrl.text);
                                  if (ext.isEmpty) {
                                    showToast(
                                      message: 'Please enter an extension',
                                    );
                                    return;
                                  }
                                  if (svgFilePath == null ||
                                      svgFilePath!.isEmpty) {
                                    showToast(
                                      message: 'Please choose an SVG icon',
                                    );
                                    return;
                                  }
                                  if (_extensions.any(
                                    (e) => e.extension == ext,
                                  )) {
                                    showToast(
                                      message: 'Extension already added',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _extensions.add(
                                      FileExtensionItem(
                                        extension: ext,
                                        localFilePath: svgFilePath,
                                      ),
                                    );
                                  });
                                  Navigator.pop(sheetContext);
                                },
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                buttonColor: AppColors.primary,
                                textColor: AppColors.black,
                                borderRadius: 12,
                                stadium: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final pro = context.read<SettingsPro>();
    final current = pro.fileSettings;

    final maxUpload = _parseInt(
      _maxUploadController.text,
      current.maxUploadSizeMb,
    );
    final admin = _parseInt(
      _adminLimitController.text,
      current.storageLimitsMb[_adminRoleId] ?? 0,
    );
    final staff = _parseInt(
      _staffLimitController.text,
      current.storageLimitsMb[_staffRoleId] ?? 0,
    );
    final client = _parseInt(
      _clientLimitController.text,
      current.storageLimitsMb[_clientRoleId] ?? 0,
    );
    final customer = _parseInt(
      _customerLimitController.text,
      current.storageLimitsMb[_customerRoleId] ?? 0,
    );

    if (maxUpload <= 0 ||
        admin <= 0 ||
        staff <= 0 ||
        client <= 0 ||
        customer <= 0) {
      showToast(message: 'All limits must be greater than 0');
      return;
    }

    final updated = FileSettingsConfig(
      maxUploadSizeMb: maxUpload,
      storageLimitsMb: {
        _adminRoleId: admin,
        _staffRoleId: staff,
        _clientRoleId: client,
        _customerRoleId: customer,
      },
      allowedExtensions: _extensions.map((e) => e.copyWith()).toList(),
    );

    pro.updateFileSettingsLocal(updated);
    await pro.saveFileSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsPro>(
      builder: (context, pro, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCard(
                title: 'File Settings',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: 'Maximum Upload Size',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: 180.w,
                      child: Row(
                        children: [
                          Expanded(child: _numberField(_maxUploadController)),
                          SizedBox(width: 8.h),
                          Expanded(
                            child: const TextWidget(
                              text: 'MB',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              _buildCard(
                title: 'Storage Limit (Per Role)',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _roleField(
                            label: 'Admin',
                            controller: _adminLimitController,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _roleField(
                            label: 'Staff',
                            controller: _staffLimitController,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: _roleField(
                            label: 'Client',
                            controller: _clientLimitController,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _roleField(
                            label: 'Customer',
                            controller: _customerLimitController,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              _buildCard(
                title: 'Allowed File Extensions',
                trailing: GestureDetector(
                  onTap: _addExtensionDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const TextWidget(
                      text: 'Add Extension',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: _extensions.isEmpty
                    ? SizedBox(
                        height: 70.h,
                        child: const Center(
                          child: TextWidget(
                            text: 'No extensions added',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.hint,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _extensions.map((ext) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.fill,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: AppColors.formHint),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30.w,
                                  height: 30.h,
                                  child:
                                      ext.localFilePath != null &&
                                          ext.localFilePath!.isNotEmpty
                                      ? SvgPicture.file(
                                          File(ext.localFilePath!),
                                          fit: BoxFit.contain,
                                          placeholderBuilder: (context) =>
                                              const SizedBox.shrink(),
                                        )
                                      : ext.icon != null && ext.icon!.isNotEmpty
                                      ? ImageWidget(
                                          image: ext.icon!,
                                          errorWidget: TextWidget(
                                            text: ext.extension,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      : TextWidget(
                                          text: ext.extension,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                ),
                                SizedBox(height: 2.w),
                                TextWidget(
                                  text: ext.extension,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                SizedBox(height: 6.w),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _extensions.remove(ext);
                                    });
                                  },
                                  child: ImageWidget(
                                    image: Paths.delete,
                                    width: 16,
                                    height: 16,
                                    color: AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              SizedBox(height: 16.h),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 160.w,
                  child: CustomButton(
                    title: pro.fileSettingsSaving
                        ? 'Saving...'
                        : 'Save Settings',
                    onTap: pro.fileSettingsSaving ? null : _save,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    buttonColor: AppColors.primary,
                    textColor: AppColors.black,
                    stadium: false,
                    borderRadius: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.formHint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextWidget(
                  text: title,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.txtClr1,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _roleField({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.formHint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(text: label, fontSize: 14, fontWeight: FontWeight.w600),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _numberField(controller)),
              SizedBox(width: 8.w),
              const TextWidget(
                text: 'MB',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.hint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.formHint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
      ),
    );
  }
}
