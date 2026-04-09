import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/models/settings_models.dart';
import 'package:print_helper/providers/setting_pro.dart';
import 'package:provider/provider.dart';

import '../tab_constants/colors.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_toasts.dart';

class FileSettingsTablet extends StatefulWidget {
  const FileSettingsTablet({super.key});

  @override
  State<FileSettingsTablet> createState() => _FileSettingsTabletState();
}

class _FileSettingsTabletState extends State<FileSettingsTablet> {
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
        .map((e) => '${e.extension}:${e.icon ?? ''}:${e.localFilePath ?? ''}')
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

  Future<void> _addExtensionDialog() async {
    final ctrl = TextEditingController();
    String? svgFileName;
    String? svgFilePath;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TextWidget(
                        text: 'Add File Extension',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                      const SizedBox(height: 18),
                      const TextWidget(
                        text: 'Extension',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.txtClr1,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: 'Example: pdf',
                          filled: true,
                          fillColor: AppColors.fill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.formHint,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.formHint,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.formHint,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const TextWidget(
                        text: 'Upload SVG Icon',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.txtClr1,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(14),
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
                                        picked.files.first.path != null) {
                                      setDialogState(() {
                                        svgFileName = picked.files.first.name;
                                        svgFilePath = picked.files.first.path;
                                      });
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.black,
                                    side: const BorderSide(
                                      color: AppColors.formHint,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const TextWidget(
                                    text: 'Choose SVG',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextWidget(
                                    text: svgFileName ?? 'No file chosen',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.hint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const TextWidget(
                              text:
                                  'Recommended: simple monochrome SVG, up to 512KB.',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.hint,
                            ),
                            if (svgFilePath != null && svgFilePath!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.formHint,
                                    ),
                                  ),
                                  child: SvgPicture.file(
                                    File(svgFilePath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const TextWidget(
                              text: 'Cancel',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final ext = _normalizeExtension(ctrl.text);
                              if (ext.isEmpty) {
                                showToast(message: 'Please enter an extension');
                                return;
                              }
                              if (svgFilePath == null || svgFilePath!.isEmpty) {
                                showToast(message: 'Please choose an SVG icon');
                                return;
                              }
                              if (_extensions.any((e) => e.extension == ext)) {
                                showToast(message: 'Extension already added');
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
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const TextWidget(
                              text: 'Add',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
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
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(
                text: 'File Settings',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.txtClr1,
              ),
              const SizedBox(height: 14),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'Maximum Upload Size',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txtClr1,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 360,
                      child: _numberField(_maxUploadController),
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text:
                          '${_maxUploadController.text.isEmpty ? '0' : _maxUploadController.text} MB',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.hint,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'Storage Limit (Per Role)',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txtClr1,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _roleField(
                            label: 'Admin',
                            controller: _adminLimitController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _roleField(
                            label: 'Staff',
                            controller: _staffLimitController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _roleField(
                            label: 'Client',
                            controller: _clientLimitController,
                          ),
                        ),
                        const SizedBox(width: 12),
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
              const SizedBox(height: 18),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: TextWidget(
                            text: 'Allowed File Extensions',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.txtClr1,
                          ),
                        ),
                        GestureDetector(
                          onTap: _addExtensionDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const TextWidget(
                              text: 'Add Extension',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _extensions.isEmpty
                        ? Container(
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.formHint),
                            ),
                            child: const TextWidget(
                              text: 'No extensions added',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.hint,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final double maxWidth = constraints.maxWidth;
                              final int columns = maxWidth >= 1180
                                  ? 6
                                  : maxWidth >= 980
                                  ? 5
                                  : maxWidth >= 760
                                  ? 4
                                  : 3;
                              final double tileWidth =
                                  (maxWidth - ((columns - 1) * 12)) / columns;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _extensions.map((ext) {
                                  return Container(
                                    width: tileWidth,
                                    height: 78,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.formHint,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _extensions.remove(ext);
                                              });
                                            },
                                            child: const Icon(
                                              Icons.close,
                                              size: 13,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 38,
                                                height: 32,
                                                child: _extensionPreview(ext),
                                              ),
                                              const SizedBox(height: 6),
                                              TextWidget(
                                                text: '.${ext.extension}',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: pro.fileSettingsSaving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextWidget(
                      text: pro.fileSettingsSaving
                          ? 'Saving...'
                          : 'Save Settings',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _extensionPreview(FileExtensionItem ext) {
    if (ext.localFilePath != null && ext.localFilePath!.isNotEmpty) {
      return SvgPicture.file(File(ext.localFilePath!), fit: BoxFit.contain);
    }
    if (ext.icon != null && ext.icon!.isNotEmpty) {
      return ImageWidget(
        image: ext.icon!,
        fit: BoxFit.contain,
        errorWidget: Center(
          child: TextWidget(
            text: ext.extension.toUpperCase(),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      );
    }
    return Center(
      child: TextWidget(
        text: ext.extension.toUpperCase(),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.formHint),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _roleField({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.formHint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: label,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.txtClr1,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 90, child: _numberField(controller)),
              const SizedBox(width: 8),
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
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.formHint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
      ),
    );
  }
}
