import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:provider/provider.dart';

import '../../../../constants/colors.dart';
import '../../../../constants/paths.dart';
import '../../models/chat_group_model.dart';
import '../../../../services/helpers.dart';
import '../../../../widgets/image_widget.dart';
import '../../../../widgets/loaders.dart';
import '../../../../widgets/spacers.dart';
import '../../../../widgets/text_widget.dart';
import '../../../../widgets/toasts.dart';

class EditChatGroup extends StatefulWidget {
  final int conversationId;
  const EditChatGroup({super.key, required this.conversationId});

  @override
  State<EditChatGroup> createState() => EditChatGroupState();
}

class EditChatGroupState extends State<EditChatGroup> {
  final _formKey = GlobalKey<FormState>();
  final _searchCntrler = TextEditingController();
  final _groupNameCntrler = TextEditingController();
  GroupDetail? group;
  bool isInitialLoading = true;
  bool pickingFile = false;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatPro = getChatPro(context);
      final result = await chatPro.getGroupDetails(widget.conversationId);
      if (!mounted || result == null) return;
      group = result;
      _groupNameCntrler.text = result.title;
      // Pre-populate selectedUsers from current participants
      chatPro.clearGroupCreationState();
      setState(() {
        isInitialLoading = false;
      });
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
        selectedImage = File(result.files.single.path!);
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

    // Build member list: existing participants + any newly selected users
    final existingIds =
        group?.participants.map((e) => e.id).toList() ?? <int>[];
    final newIds = chatPro.selectedUsers.map((e) => e.id).toList();
    final allIds = {...existingIds, ...newIds}.toList();

    if (allIds.length < 2) {
      showToast(message: "A group must have at least 2 members");
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await chatPro.updateGroup(
      conversationId: widget.conversationId,
      title: _groupNameCntrler.text.trim(),
      userIds: allIds,
      image: selectedImage,
    );
    if (!mounted) return;
    if (success) {
      showToast(message: "Group updated successfully");
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
                Expanded(
                  child: isInitialLoading
                      ? Center(child: showLoader())
                      : SingleChildScrollView(
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
                                Consumer<ChatPro>(
                                  builder: (context, pro, _) {
                                    return _buildSearchArea(pro);
                                  },
                                ),
                                Spacers.sb15(),
                                if (group != null) _buildMemberList(),
                                Spacers.sb25(),
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
              text: "Edit Group",
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
                    image: _avatarImage(),
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

  DecorationImage? _avatarImage() {
    if (selectedImage != null) {
      return DecorationImage(
        image: FileImage(selectedImage!),
        fit: BoxFit.cover,
      );
    }
    if (group?.image != null && group!.image!.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(group!.image!),
        fit: BoxFit.cover,
      );
    }
    return DecorationImage(image: AssetImage(Paths.user), fit: BoxFit.contain);
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

  // ─── Search Results / Placeholder ──────────────────────────────────────────

  Widget _buildSearchArea(ChatPro pro) {
    // Show nothing when not searching
    if (_searchCntrler.text.isEmpty && pro.searchResults.isEmpty) {
      return _placeholderCard("Start typing to find users");
    }

    if (pro.isLoading) {
      return _placeholderCard(null, loading: true);
    }

    if (pro.searchResults.isEmpty && _searchCntrler.text.isNotEmpty) {
      return _placeholderCard("No results found");
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 260.h),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: pro.searchResults.length,
        separatorBuilder: (_, __) => Spacers.sb5(),
        itemBuilder: (context, index) {
          final user = pro.searchResults[index];
          final isSelected = pro.selectedUsers.any((u) => u.id == user.id);
          // Also mark already-in-group members
          final alreadyInGroup =
              group?.participants.any((p) => p.id == user.id) ?? false;
          return GestureDetector(
            onTap: alreadyInGroup ? null : () => pro.toggleUserSelection(user),
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
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Spacers.sbw10(),
                  Expanded(
                    child: TextWidget(
                      text: user.fullName,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (alreadyInGroup)
                    TextWidget(
                      text: "Already added",
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    )
                  else if (isSelected)
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

  // ─── Current Member List ────────────────────────────────────────────────────

  Widget _buildMemberList() {
    final participants = group!.participants;
    if (participants.isEmpty) return const SizedBox.shrink();

    // final chatPro = getChatPro(context);
    final currentUserId = getAuthPro(context).user?.id;
    final isCurrentUserAdmin =
        currentUserId != null && group!.adminIds.contains(currentUserId);

    return Column(
      children: participants
          .map(
            (p) => _memberTile(
              p,
              isCurrentUserAdmin: isCurrentUserAdmin,
              currentUserId: currentUserId,
            ),
          )
          .toList(),
    );
  }

  Widget _memberTile(
    GroupParticipant p, {
    bool isCurrentUserAdmin = false,
    int? currentUserId,
  }) {
    final isAdmin = group!.adminIds.contains(p.id) || p.isAdmin;
    final isSelf = p.id == currentUserId;
    final showDelete = isCurrentUserAdmin && !isSelf;
    final statusText = p.isOnline
        ? "Online"
        : p.lastSeenAt != null
        ? "Last seen ${_formatLastSeen(p.lastSeenAt!)}"
        : "Offline";
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
                  image: p.image != null && p.image!.isNotEmpty
                      ? p.image!
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
                    color: p.isOnline ? Colors.green : Colors.grey.shade400,
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
                  text: p.fullName,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                Spacers.sb2(),
                TextWidget(
                  text: statusText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: p.isOnline ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFCC00), Color(0xFFFFAA00)],
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 13.sp, color: Colors.white),
                  SizedBox(width: 3.w),
                  Text(
                    "Admin",
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          if (showDelete) ...[
            Spacers.sbw8(),
            GestureDetector(
              onTap: () => _confirmRemoveMember(p),
              child: ImageWidget(image: Paths.delete, width: 22, height: 22),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemoveMember(GroupParticipant p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              padding: EdgeInsets.fromLTRB(24.w, 24.h, 16.w, 8.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: "Remove ${p.fullName} from the group?",
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const TextWidget(
                          text: "Cancel",
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: TextWidget(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          text: "Remove",
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    // Remove the user from the local group state so it reflects in the UI
    setState(() {
      group!.participants.removeWhere((m) => m.id == p.id);
    });
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${(diff.inDays / 7).floor()}w ago";
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
              title: 'Update',
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
