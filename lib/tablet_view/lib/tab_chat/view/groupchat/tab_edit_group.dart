import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../tab_utils/console_util.dart';
import '../../../tab_widgets/tab_custom_button.dart';
import 'package:provider/provider.dart';

import '../../../tab_constants/colors.dart';
import '../../../tab_constants/paths.dart';
import 'package:print_helper/models/search_modals.dart';
// import 'package:print_helper/admin/chat/models/chat_models.dart'; // Unused
import 'package:print_helper/admin/chat/models/chat_group_model.dart';
import '../../../tab_services/helpers.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/loaders.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import '../../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';

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
  bool _isExpanded = true;
  bool pickingFile = false;
  File? selectedImage;
  bool formSubmitted = false;
  ChatPro? _chatPro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _chatPro = getChatPro(context);
      // Clear previous state
      _chatPro?.searchResults.clear();
      _chatPro?.selectedUsers.clear();

      final result = await _chatPro?.getGroupDetails(widget.conversationId);
      if (!mounted || result == null) return;
      group = result;
      _groupNameCntrler.text = result.title;

      // selectedUsers are populated in getGroupDetails

      setState(() {
        isInitialLoading = false;
      });
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

    final success = await chatPro.updateGroup(
      conversationId: widget.conversationId,
      title: _groupNameCntrler.text.trim(),
      userIds: userIds,
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
      child: isInitialLoading
          ? Center(child: showLoader())
          : Column(
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
                            text: "Change group photo",
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
              title: 'Update',
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
                    decoration: _inputDecoration("Search users"),
                  ),
                  Spacers.sb10(),
                  Container(
                    constraints: BoxConstraints(minHeight: 50, maxHeight: 280),
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

  Widget buildSelectedUsersChips(ChatPro pro) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.btnClr.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextWidget(
                        text: user.fullName,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                      Spacers.sbw5(),
                      GestureDetector(
                        onTap: () => pro.removeSelectedUser(user),
                        child: ImageWidget(
                          image: Paths.delete,
                          width: 18,
                          color: Colors.white,
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
    // Check loading state first
    if (pro.isLoading) {
      return Center(child: showLoader());
    }

    // Show selected members if search is empty, otherwise show search results
    List<SearchUsers> displayList = _searchCntrler.text.isEmpty
        ? pro.selectedUsers
        : pro.searchResults;

    // Deduplicate by user ID
    final seen = <int>{};
    displayList = displayList.where((user) => seen.add(user.id)).toList();

    // If no search results but search is active, show "No results" + selected members
    if (displayList.isEmpty && _searchCntrler.text.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            Spacers.sb20(),
            const TextWidget(
              text: "No results found",
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            if (pro.selectedUsers.isNotEmpty) ...[
              Spacers.sb20(),
              Divider(thickness: 1, color: Colors.grey.shade300),
              Spacers.sb10(),
              TextWidget(
                text: "Added Members (${pro.selectedUsers.length})",
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              Spacers.sb10(),
              ..._buildMembersList(pro.selectedUsers, pro, isSearching: false),
            ],
          ],
        ),
      );
    }
    if (displayList.isEmpty) {
      return Center(
        heightFactor: 5,
        child: const TextWidget(
          text: "Start typing to find users",
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: displayList.length,
      separatorBuilder: (c, i) => Spacers.sb5(),
      itemBuilder: (context, index) {
        final user = displayList[index];
        final isSearching = _searchCntrler.text.isNotEmpty;
        return _buildMemberItem(user, pro, isSearching: isSearching);
      },
    );
  }

  Widget _buildMemberItem(
    SearchUsers user,
    ChatPro pro, {
    required bool isSearching,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: ImageWidget(
                  image: user.image != null && user.image!.isNotEmpty
                      ? user.image!
                      : Paths.user,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isOnline ? Colors.green : Colors.grey,
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
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextWidget(
                      text: user.fullName,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    Spacers.sbw5(),
                    if (!isSearching &&
                        group != null &&
                        group!.adminIds.contains(user.id))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: TextWidget(
                          text: 'Admin',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: Colors.amber.shade800,
                        ),
                      ),
                  ],
                ),
                Spacers.sb2(),
                if (!isSearching)
                  TextWidget(
                    text: _getLastSeenText(user),
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.grey,
                  )
                else if ((user.email ?? '').trim().isNotEmpty)
                  TextWidget(
                    text: user.email!,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => pro.toggleUserSelection(user),
            child: Padding(
              padding: EdgeInsets.only(right: 5),
              child: pro.selectedUsers.any((u) => u.id == user.id)
                  ? ImageWidget(
                      image: Paths.delete,
                      width: 20,
                      height: 20,
                      color: Colors.grey,
                    )
                  : Icon(
                      Icons.add_circle_outline,
                      size: 24,
                      color: Colors.grey.shade400,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMembersList(
    List<SearchUsers> users,
    ChatPro pro, {
    required bool isSearching,
  }) {
    return users
        .map(
          (user) => Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: _buildMemberItem(user, pro, isSearching: isSearching),
          ),
        )
        .toList();
  }

  Widget profileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: pickImage,
          child: Container(
            width: 140,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: selectedImage != null
                    ? FileImage(selectedImage!)
                    : group?.image != null && group!.image!.isNotEmpty
                    ? NetworkImage(group!.image!)
                    : const AssetImage(Paths.user) as ImageProvider,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: pickImage,
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
              text: "Edit Group",
              fontWeight: FontWeight.w600,
              fontSize: 16,
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
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.all(12),
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

  String _getLastSeenText(SearchUsers user) {
    if (user.isOnline) {
      return 'Online';
    }
    if (user.lastSeenAt == null) {
      return 'Last seen Jan 22';
    }
    try {
      final lastSeen = user.lastSeenAt!.toLocal();
      final now = DateTime.now().toLocal();
      final difference = now.difference(lastSeen);

      if (difference.isNegative) {
        return 'Last seen just now';
      }

      if (difference.inMinutes < 1) {
        return 'Last seen just now';
      } else if (difference.inHours < 1) {
        return 'Last seen ${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return 'Last seen ${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Last seen yesterday';
      } else if (difference.inDays < 7) {
        return 'Last seen ${difference.inDays}d ago';
      } else {
        final months = [
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
        ];
        return 'Last seen ${lastSeen.day} ${months[lastSeen.month - 1]} ${lastSeen.year}';
      }
    } catch (e) {
      return 'Last seen Jan 22';
    }
  }
}
