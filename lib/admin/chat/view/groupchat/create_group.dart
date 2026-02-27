import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:provider/provider.dart';

import '../../../../constants/colors.dart';
import '../../../../constants/paths.dart';
import '../../../../models/search_modals.dart';
import '../../../../services/helpers.dart';
import '../../../../widgets/image_widget.dart';
import '../../../../widgets/loaders.dart';
import '../../../../widgets/spacers.dart';
import '../../../../widgets/text_widget.dart';
import '../../../../widgets/toasts.dart';

class CreateChatGroup extends StatefulWidget {
  final VoidCallback? onSuccess;
  const CreateChatGroup({super.key, this.onSuccess});

  @override
  State<CreateChatGroup> createState() => CreateChatGroupState();
}

class CreateChatGroupState extends State<CreateChatGroup> {
  final _formKey = GlobalKey<FormState>();
  final _searchCntrler = TextEditingController();
  final _groupNameCntrler = TextEditingController();
  bool pickingFile = false;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    // Clear any leftover selected users / search results from a previous session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatPro>().clearGroupCreationState();
      }
    });
  }

  @override
  void dispose() {
    _searchCntrler.dispose();
    _groupNameCntrler.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    if (pickingFile) return;
    pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => selectedImage = File(result.files.single.path!));
      }
    } catch (e) {
      printData(title: 'from pickImage', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  Future<void> _onSave() async {
    final chatPro = getChatPro(context);
    if (_groupNameCntrler.text.trim().isEmpty) {
      showToast(message: "Group name is required");
      return;
    }
    if (chatPro.selectedUsers.length < 2) {
      showToast(message: "Select at least 2 members");
      return;
    }
    final userIds = chatPro.selectedUsers.map((e) => e.id).toList();
    FocusScope.of(context).unfocus();
    final success = await chatPro.createGroup(
      title: _groupNameCntrler.text.trim(),
      userIds: userIds,
      image: selectedImage,
      context: context,
    );
    if (!mounted) return;
    if (success) {
      showToast(message: "Group Created Successfully");
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.only(top: 40.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          ),
          child: SafeArea(
            top: true,
            child: Column(
              children: [
                _header(context),
                // ── Scrollable body: everything between header and buttons ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Spacers.sb20(),
                          _profileImageSection(),
                          Spacers.sb20(),
                          _buildLabel("Group Name"),
                          Spacers.sb8(),
                          _groupNameField(),
                          Spacers.sb15(),
                          _buildLabel("Add Members"),
                          Spacers.sb8(),
                          _searchField(),
                          Spacers.sb8(),
                          // Search results: constrained height with internal scroll
                          Consumer<ChatPro>(
                            builder: (context, pro, _) {
                              final isSearching =
                                  pro.isLoading ||
                                  pro.searchResults.isNotEmpty ||
                                  _searchCntrler.text.isNotEmpty;
                              if (!isSearching) return const SizedBox.shrink();
                              return _buildSearchArea(pro);
                            },
                          ),
                          // Selected members list below search results
                          Consumer<ChatPro>(
                            builder: (context, pro, _) =>
                                _buildSelectedMembersList(pro),
                          ),
                          Spacers.sb20(),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottomButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Row(
        children: [
          Expanded(
            child: TextWidget(
              text: "Create Group",
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              context.read<ChatPro>().clearGroupCreationState();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: EdgeInsets.all(4.w),
              child: Icon(Icons.close, size: 24.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile Image ──────────────────────────────────────────────────────────

  Widget _profileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: AssetImage(Paths.user),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFCC00),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Spacers.sb8(),
          GestureDetector(
            onTap: pickImage,
            child: TextWidget(
              text: "Add group photo",
              fontSize: 13,
              color: Colors.blueGrey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Group Name Field ───────────────────────────────────────────────────────

  Widget _groupNameField() {
    return TextField(
      controller: _groupNameCntrler,
      decoration: _inputDecoration("Enter group name"),
      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
    );
  }

  // ─── Search Field ───────────────────────────────────────────────────────────

  Widget _searchField() {
    return Consumer<ChatPro>(
      builder: (context, pro, _) {
        return TextField(
          controller: _searchCntrler,
          onChanged: pro.onSearchChanged,
          decoration: _inputDecoration("Search users").copyWith(
            suffixIcon: _searchCntrler.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      _searchCntrler.clear();
                      pro.onSearchChanged('');
                    },
                  )
                : null,
          ),
          style: TextStyle(fontSize: 14.sp, color: Colors.black87),
        );
      },
    );
  }

  // ─── Search Results ─────────────────────────────────────────────────────────

  Widget _buildSearchArea(ChatPro pro) {
    // Search results / placeholder
    if (_searchCntrler.text.isEmpty && pro.searchResults.isEmpty) {
      return const SizedBox.shrink();
    }
    if (pro.isLoading) return _placeholderCard(null, loading: true);
    if (pro.searchResults.isEmpty && _searchCntrler.text.isNotEmpty) {
      return _placeholderCard("No results found");
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 220.h),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: pro.searchResults.length,
        separatorBuilder: (_, _) => Spacers.sb5(),
        itemBuilder: (context, index) {
          final user = pro.searchResults[index];
          final isSelected = pro.selectedUsers.any((u) => u.id == user.id);
          return GestureDetector(
            onTap: () => pro.toggleUserSelection(user),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected ? AppColors.btnClr : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50.r),
                    child: ImageWidget(
                      image: user.image != null && user.image!.isNotEmpty
                          ? user.image!
                          : Paths.user,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Spacers.sbw10(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: user.fullName,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        if (user.email != null && user.email!.isNotEmpty)
                          TextWidget(
                            text: user.email!,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade500,
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.shade50,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Selected Members List ──────────────────────────────────────────────────

  Widget _buildSelectedMembersList(ChatPro pro) {
    if (pro.selectedUsers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spacers.sb15(),
        _buildLabel("Added Members (${pro.selectedUsers.length})"),
        Spacers.sb8(),
        ...pro.selectedUsers.map((user) => _selectedMemberTile(user, pro)),
      ],
    );
  }

  Widget _selectedMemberTile(SearchUsers user, ChatPro pro) {
    final statusText = user.isOnline
        ? 'Online'
        : user.lastSeenAt != null
        ? 'Last seen ${_formatLastSeen(user.lastSeenAt!)}'
        : user.email ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          // Avatar with online dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50.r),
                child: ImageWidget(
                  image: user.image != null && user.image!.isNotEmpty
                      ? user.image!
                      : Paths.user,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isOnline ? Colors.green : Colors.grey.shade400,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          Spacers.sbw12(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: user.fullName,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                Spacers.sb2(),
                TextWidget(
                  text: statusText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: user.isOnline ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => pro.removeSelectedUser(user),
            child: ImageWidget(
              image: Paths.delete,
              width: 18.w,
              height: 18.h,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Show actual date for older
    final month = [
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
    ][lastSeen.month - 1];
    return '$month ${lastSeen.day}';
  }

  Widget _placeholderCard(String? text, {bool loading = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: loading
            ? showLoader()
            : TextWidget(
                text: text ?? '',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
      ),
    );
  }

  // ─── Bottom Buttons ─────────────────────────────────────────────────────────

  Widget _bottomButtons(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              height: 44,
              textColor: AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              showBorder: true,
              buttonColor: Colors.white,
              stadium: false,
              borderRadius: 22,
              borderWidth: 1.5,
              title: 'Cancel',
              onTap: () {
                context.read<ChatPro>().clearGroupCreationState();
                Navigator.of(context).pop();
              },
            ),
          ),
          Spacers.sbw12(),
          Expanded(
            child: CustomButton(
              height: 44,
              title: 'Create Group',
              onTap: _onSave,
              buttonColor: AppColors.btnClr,
              textColor: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              stadium: false,
              borderRadius: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return TextWidget(
      text: text,
      color: Colors.black87,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.grey),
      ),
    );
  }
}
