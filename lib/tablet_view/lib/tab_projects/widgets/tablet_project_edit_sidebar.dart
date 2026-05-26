import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/project_pro.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/projects_models.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_image_widget.dart';

class TabletProjectEditSidebar extends StatefulWidget {
  final ProjectModel project;

  const TabletProjectEditSidebar({super.key, required this.project});

  static Future<bool?> show(BuildContext context, ProjectModel project) {
    return showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'ProjectEditPopup',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(
        alpha: 0.1,
      ), // Lighter barrier like image
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 32, right: 14),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
              child: FadeTransition(
                opacity: anim1,
                child: TabletProjectEditSidebar(project: project),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TabletProjectEditSidebar> createState() =>
      _TabletProjectEditSidebarState();
}

class _TabletProjectEditSidebarState extends State<TabletProjectEditSidebar> {
  final _nameController = TextEditingController();
  final _clientKey = GlobalKey();
  final _customerKey = GlobalKey();
  int? _selectedClientId;
  int? _selectedCustomerId;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.project.name;
    _selectedClientId = widget.project.clientId > 0
        ? widget.project.clientId
        : null;
    _selectedCustomerId = widget.project.customerId > 0
        ? widget.project.customerId
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<ProjectPro>();
      pro.getProjectClientOptions();
      pro.getProjectCustomerOptions();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final pro = context.read<ProjectPro>();

      final success = await pro.updateProjectCoreFields(
        projectId: widget.project.numericId,
        name: name,
        clientId: _selectedClientId ?? 0,
        customerId: _selectedCustomerId ?? 0,
        clientName: _getLabelById(pro.projectClientOptions, _selectedClientId),
        customerName: _getLabelById(
          pro.projectCustomerOptions,
          _selectedCustomerId,
        ),
      );

      if (success && mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String? _getLabelById(List<Map<String, String>> options, int? id) {
    if (id == null) return null;
    try {
      final found = options.firstWhere(
        (o) => int.tryParse(o['id'] ?? '') == id,
      );
      return found['label'];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    // Account for top padding (32) and some bottom clearance (20)
    final maxPopupHeight = screenHeight - bottomInset - 52;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        constraints: BoxConstraints(maxHeight: maxPopupHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE9E9EF)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(
                      'Project Name',
                      _nameController,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    _buildSelectionField(
                      'Assign Client',
                      _clientKey,
                      context.watch<ProjectPro>().projectClientOptions,
                      _selectedClientId,
                      (id) => setState(() => _selectedClientId = id),
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    _buildSelectionField(
                      'Assign Customer',
                      _customerKey,
                      context.watch<ProjectPro>().projectCustomerOptions,
                      _selectedCustomerId,
                      (id) => setState(() => _selectedCustomerId = id),
                    ),
                    const SizedBox(height: 20),
                    Center(child: _buildUpdateButton()),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          ImageWidget(
            image: Paths.task,
            width: 10,
            height: 10,
            color: const Color(0xFF1F1F27),
          ),
          const SizedBox(width: 10),
          const Text(
            'Project',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1F27),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              CupertinoIcons.xmark,
              size: 18,
              color: Color(0xFF98A0AC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (required)
                const TextSpan(
                  text: '* ',
                  style: TextStyle(
                    color: Color(0xFFE45B45),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F27),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Type $label',
            hintStyle: const TextStyle(color: Color(0xFF98A0AC), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E2E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E2E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionField(
    String label,
    GlobalKey key,
    List<Map<String, String>> options,
    int? selectedId,
    ValueChanged<int?> onSelected, {
    bool required = false,
  }) {
    final selectedOption = options.firstWhere(
      (o) => int.tryParse(o['id'] ?? '') == selectedId,
      orElse: () => {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (required)
                const TextSpan(
                  text: '* ',
                  style: TextStyle(
                    color: Color(0xFFE45B45),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F27),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          key: key,
          onTap: () => _showPicker(key, label, options, onSelected),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E2E8)),
            ),
            child: Row(
              children: [
                if (selectedOption.isNotEmpty &&
                    selectedOption['id'] != '') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: label.contains('Client')
                          ? const Color(0xFFFFD541)
                          : const Color(
                              0xFFFFD541,
                            ), // Matching yellow from image
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: ImageWidget(
                            image:
                                (selectedOption['image']
                                        ?.toString()
                                        .isNotEmpty ==
                                    true)
                                ? selectedOption['image']!
                                : (label.contains('Client')
                                          ? widget.project.clientImage
                                          : widget.project.customerImage)
                                      .isNotEmpty
                                ? (label.contains('Client')
                                      ? widget.project.clientImage
                                      : widget.project.customerImage)
                                : Paths.user,
                            width: 8,
                            height: 8,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedOption['label'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F27),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onSelected(null),
                          child: const Icon(
                            CupertinoIcons.trash,
                            size: 14,
                            color: Color(0xFF1F1F27),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Text(
                    'Select',
                    style: TextStyle(color: Color(0xFF98A0AC), fontSize: 13),
                  ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: Color(0xFF98A0AC),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(
    GlobalKey key,
    String title,
    List<Map<String, String>> options,
    ValueChanged<int?> onSelected,
  ) {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final filteredOptions = options.where((o) => o['id'] != '').toList();

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height + 4,
        position.dx + size.width,
        position.dy + size.height + 400,
      ),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: filteredOptions.map((option) {
        return PopupMenuItem<int>(
          value: int.tryParse(option['id'] ?? ''),
          height: 48,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: ImageWidget(
                  image: (option['image']?.toString().isNotEmpty == true)
                      ? option['image']!
                      : Paths.user,
                  width: 8,
                  height: 8,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                option['label'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F1F27),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        onSelected(value);
      }
    });
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: 100,
      height: 33,
      child: ElevatedButton(
        onPressed: _isBusy ? null : _handleUpdate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1ECB5C),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: showLoader(color: Colors.white),
              )
            : const Text(
                'Update',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
