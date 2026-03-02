import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../tab_utils/console_util.dart';
import '../../../tab_widgets/tab_custom_button.dart';
import 'package:provider/provider.dart';

import '../../../tab_constants/colors.dart';
import '../../../tab_constants/paths.dart';
import '../../../tab_services/helpers.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/loaders.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import '../../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';

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
  bool _isExpanded = true;
  bool pickingFile = false;
  File? selectedImage;
  bool formSubmitted = false;
  ChatPro? _chatPro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPro = getChatPro(context);
      _chatPro?.searchResults.clear();
      _chatPro?.selectedUsers.clear();
    });
  }

  @override
  void dispose() {
    _chatPro?.searchResults.clear();
    _chatPro?.selectedUsers.clear();
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
      if (mounted) {
        setState(() => pickingFile = false);
      } else {
        pickingFile = false;
      }
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
      // Conversations are already reloaded in ChatPro.createGroup
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _header(context),
          Divider(thickness: 1, color: Colors.grey.shade200, height: 0),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Spacers.sb20(),
                    profileImage(),
                    Spacers.sb10(),
                    TextWidget(
                      text: "Add group photo",
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    Spacers.sb20(),
                    _formBody(),
                    Spacers.sb30(),
                  ],
                ),
              ),
            ),
          ),
          _cancelSaveBtn(context),
        ],
      ),
    );
  }

  Widget _cancelSaveBtn(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              height: 40,
              title: 'Cancel',
              onTap: () {
                context.read<ChatPro>().clearGroupCreationState();
                Navigator.of(context).pop();
              },
              buttonColor: Colors.white,
              textColor: AppColors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              stadium: false,
              borderRadius: 12,
              borderColor: Colors.grey,
              showBorder: true,
              margin: EdgeInsets.zero,
            ),
          ),
          Spacers.sbw10(),
          Expanded(
            child: CustomButton(
              height: 40,
              title: 'Create Group',
              onTap: () => _onSave(),
              buttonColor: AppColors.primary,
              textColor: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              stadium: false,
              borderRadius: 12,
              margin: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formBody() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: "Group Name",
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          Spacers.sb8(),
          TextField(
            decoration: _inputDecoration("Enter group name"),
            controller: _groupNameCntrler,
          ),
          Spacers.sb15(),
          TextWidget(
            text: "Add Members",
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          Spacers.sb8(),
          Consumer<ChatPro>(
            builder: (context, pro, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pro.selectedUsers.isNotEmpty) ...[
                    _buildSelectedUsersChips(pro),
                    Spacers.sb10(),
                  ],
                  TextField(
                    controller: _searchCntrler,
                    onChanged: (value) {
                      // Search for group members
                      if (value.isEmpty) {
                        pro.searchResults.clear();
                      }
                      // Call search method if available
                      // pro.searchGroupMembers(value);
                    },
                    decoration: _inputDecoration("Start typing to find users"),
                  ),
                  Spacers.sb10(),
                  Container(
                    constraints: BoxConstraints(minHeight: 50, maxHeight: 220),
                    width: double.infinity,
                    child: _buildSearchResultsList(pro),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUsersChips(ChatPro pro) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget(
                text: "Selected Members (${pro.selectedUsers.length})",
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            Spacers.sb10(),
            Wrap(
              spacing: 4.0,
              runSpacing: 4.0,
              children: pro.selectedUsers.map((user) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.btnClr.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextWidget(
                        text: user.fullName,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                      ),
                      Spacers.sbw5(),
                      GestureDetector(
                        onTap: () => pro.removeSelectedUser(user),
                        child: ImageWidget(
                          image: Paths.delete,
                          width: 16,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(ChatPro pro) {
    if (pro.isLoading) {
      return Center(child: showLoader());
    }

    if (pro.searchResults.isEmpty &&
        _searchCntrler.text.isNotEmpty) {
      return Center(
        heightFactor: 5,
        child: const TextWidget(
          text: "No results found",
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: pro.searchResults.length,
      separatorBuilder: (c, i) => Spacers.sb5(),
      itemBuilder: (context, index) {
        final user = pro.searchResults[index];
        final isSelected = pro.selectedUsers.any((u) => u.id == user.id);
        return GestureDetector(
          onTap: () => pro.toggleUserSelection(user),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.grey : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: ImageWidget(
                    image: user.image != null && user.image!.isNotEmpty
                        ? user.image!
                        : Paths.user,
                    width: 35,
                    height: 35,
                    fit: BoxFit.cover,
                  ),
                ),
                Spacers.sbw12(),
                Expanded(
                  child: TextWidget(
                    text: user.fullName,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(4),
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
    );
  }

  Widget profileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: pickImage,
          child: Container(
            width: 140,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
            onTap: () => pickImage(),
            child: ImageWidget(image: Paths.edit, width: 20),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Icon(Icons.close, size: 24, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextWidget(
        text: text,
        color: Colors.blueGrey.shade700,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  // Helper for Input Decoration
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      isDense: true,
      contentPadding: EdgeInsets.only(left: 15, right: 15, top: 12, bottom: 14),
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}
