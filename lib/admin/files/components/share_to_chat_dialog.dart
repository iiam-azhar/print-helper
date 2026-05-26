import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/providers/files_pro.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:print_helper/widgets/loaders.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/search_modals.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';

class ShareToChatDialog extends StatefulWidget {
  final String itemName;
  final String itemPath;
  final bool isFolder;

  const ShareToChatDialog({
    super.key,
    required this.itemName,
    required this.itemPath,
    required this.isFolder,
  });

  @override
  State<ShareToChatDialog> createState() => _ShareToChatDialogState();
}

class _ShareToChatDialogState extends State<ShareToChatDialog> {
  final TextEditingController searchCtrl = TextEditingController();
  final Set<int> selectedUserIds = {};
  final Set<int> selectedConversationIds = {};
  final Map<int, String> selectedTitles = {};

  Future<void> _handleShare(FilesPro filesPro, ChatPro chatPro) async {
    if (selectedUserIds.isEmpty && selectedConversationIds.isEmpty) return;

    Loaders.show();
    final success = await filesPro.shareItemToChat(
      userIds: selectedUserIds.isNotEmpty ? selectedUserIds.toList() : null,
      conversationIds: selectedConversationIds.isNotEmpty 
          ? selectedConversationIds.toList() 
          : null,
      itemPath: widget.itemPath,
      itemName: widget.itemName,
      isFolder: widget.isFolder,
    );
    Loaders.hide();

    if (success) {
      showToast(message: 'Shared successfully');
      if (mounted) {
        chatPro.clearUserSearch();
        Navigator.pop(context);
      }
    } else {
      showToast(message: 'Failed to share');
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatPro = Provider.of<ChatPro>(context, listen: false);
    final filesPro = Provider.of<FilesPro>(context, listen: false);

    bool hasSelection = selectedUserIds.isNotEmpty || selectedConversationIds.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                TextWidget(
                  text: 'Share to Chat',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    chatPro.clearUserSearch();
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.close, size: 24.sp),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            height: 44.h,
            decoration: BoxDecoration(
              color: const Color(0xfff1f1f2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.search, color: Colors.grey, size: 20),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (val) {
                      chatPro.onSearchGlobalChanged(val);
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Find People or Groups',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasSelection)
            Container(
              height: 50.h,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...selectedUserIds.map((id) => _selectedChip(selectedTitles[id] ?? 'User', () {
                    setState(() => selectedUserIds.remove(id));
                  })),
                  ...selectedConversationIds.map((id) => _selectedChip(selectedTitles[id] ?? 'Group', () {
                    setState(() => selectedConversationIds.remove(id));
                  })),
                ],
              ),
            ),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          Expanded(
            child: Consumer<ChatPro>(
              builder: (context, pro, _) {
                final displayList = pro.searchResults.isNotEmpty 
                    ? pro.searchResults 
                    : pro.conversations;

                if (displayList.isEmpty) {
                  return Center(
                    child: TextWidget(
                      text: pro.searchResults.isNotEmpty 
                          ? 'No results found' 
                          : 'No conversations found',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: displayList.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xfff0f0f0)),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    String title = '';
                    String image = '';
                    int? conversationId;
                    int? userId;
                    bool isSelected = false;

                    if (item is SearchUsers) {
                      title = item.fullName;
                      image = item.image ?? '';
                      userId = item.id;
                      isSelected = selectedUserIds.contains(userId);
                    } else if (item is ChatConversation) {
                      title = item.title;
                      image = item.image;
                      conversationId = item.id;
                      isSelected = selectedConversationIds.contains(conversationId);
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(50.r),
                        child: ImageWidget(
                          image: image.isNotEmpty ? image : Paths.user,
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: TextWidget(
                        text: title,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.blue : Colors.grey,
                        size: 24.sp
                      ),
                      onTap: () {
                        setState(() {
                          if (userId != null) {
                            if (isSelected) {
                              selectedUserIds.remove(userId);
                            } else {
                              selectedUserIds.add(userId);
                              selectedTitles[userId] = title;
                            }
                          } else if (conversationId != null) {
                            if (isSelected) {
                              selectedConversationIds.remove(conversationId);
                            } else {
                              selectedConversationIds.add(conversationId);
                              selectedTitles[conversationId] = title;
                            }
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: hasSelection ? () => _handleShare(filesPro, chatPro) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: Size(double.infinity, 50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: TextWidget(
                text: 'Share',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedChip(String label, VoidCallback onDelete) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TextWidget(
            text: label,
            fontSize: 12,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 14, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
