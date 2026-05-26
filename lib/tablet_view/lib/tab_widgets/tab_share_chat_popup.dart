import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'loaders.dart';
import 'tab_toasts.dart';
import '../tab_constants/paths.dart';
import '../tab_widgets/tab_image_widget.dart';
import 'tab_text_widget.dart' as tab_text;
import '../tab_services/helpers.dart';

class TabShareChatPopup extends StatefulWidget {
  final String itemName;
  final String itemPath;
  final bool isFolder;

  const TabShareChatPopup({
    super.key,
    required this.itemName,
    required this.itemPath,
    required this.isFolder,
  });

  static Future<void> show({
    required BuildContext context,
    required String itemName,
    required String itemPath,
    required bool isFolder,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => TabShareChatPopup(
        itemName: itemName,
        itemPath: itemPath,
        isFolder: isFolder,
      ),
    );
  }

  @override
  State<TabShareChatPopup> createState() => _TabShareChatPopupState();
}

class _TabShareChatPopupState extends State<TabShareChatPopup> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<dynamic> _selectedItems =
      {}; // Set of Conversation or SearchResultUser

  @override
  void initState() {
    super.initState();
    postFrameCallback(() {
      final chatPro = getChatPro(context);
      chatPro.clearUserSearch();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getSelectedItemName() {
    if (_selectedItems.isEmpty) return '';
    if (_selectedItems.length == 1) {
      final item = _selectedItems.first as dynamic;
      try {
        return item.title ?? '${item.name} ${item.lastName}';
      } catch (e) {
        return item.name ?? '';
      }
    }
    return '${_selectedItems.length} selected';
  }

  Future<void> _onShare() async {
    if (_selectedItems.isEmpty) {
      showToast(message: 'Please select a conversation or user');
      return;
    }

    final filesPro = getFilePro(context);

    final List<int> conversationIds = [];
    final List<int> userIds = [];

    for (final selected in _selectedItems) {
      try {
        final item = selected as dynamic;
        final id = item.id;
        if (id is! int) continue;

        if (item.runtimeType.toString().contains('User')) {
          userIds.add(id);
        } else {
          conversationIds.add(id);
        }
      } catch (_) {}
    }

    if (conversationIds.isEmpty && userIds.isEmpty) {
      showToast(message: 'Invalid selection');
      return;
    }

    Loaders.show();
    final success = await filesPro.shareItemToChat(
      conversationIds: conversationIds.isNotEmpty ? conversationIds : null,
      userIds: userIds.isNotEmpty ? userIds : null,
      itemPath: widget.itemPath,
      itemName: widget.itemName,
      isFolder: widget.isFolder,
    );
    Loaders.hide();

    if (success) {
      showToast(message: 'Shared successfully');
      if (mounted) Navigator.pop(context);
    } else {
      showToast(message: 'Failed to share');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const tab_text.TextWidget(
                    text: 'Share To Chat',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              // Label
              const tab_text.TextWidget(
                text: 'CONVERSATION OR USER',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff94a3b8),
              ),
              const SizedBox(height: 12),

              // Search Field
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer<ChatPro>(
                        builder: (context, chatPro, _) {
                          return TextField(
                            controller: _searchCtrl,
                            onChanged: chatPro.onSearchGlobalChanged,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search conversation or user...',
                              hintStyle: TextStyle(color: Color(0xff94a3b8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Selection List
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Consumer<ChatPro>(
                  builder: (context, chatPro, _) {
                    final isSearching = _searchCtrl.text.trim().isNotEmpty;
                    final list = isSearching
                        ? chatPro.searchResults
                        : chatPro.conversations;

                    if (list.isEmpty) {
                      return Center(
                        child: tab_text.TextWidget(
                          text: isSearching
                              ? 'No users found'
                              : 'No recent conversations',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black45,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 70,
                        color: Color(0xfff1f5f9),
                      ),
                      itemBuilder: (context, index) {
                        final dynamic item = list[index];
                        String title = '';
                        String image = '';
                        try {
                          title = item.title ?? '${item.name} ${item.lastName}';
                        } catch (_) {
                          try {
                            title = item.name ?? '';
                          } catch (__) {}
                        }
                        try {
                          image = item.image ?? '';
                        } catch (_) {}

                        final isSelected = _selectedItems.any(
                          (e) => (e as dynamic).id == item.id,
                        );

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedItems.removeWhere(
                                  (e) => (e as dynamic).id == item.id,
                                );
                              } else {
                                _selectedItems.add(item);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xfff1f5f9),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: ImageWidget(
                                      image: image.isNotEmpty
                                          ? image
                                          : Paths.user,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Name & Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tab_text.TextWidget(
                                        text: title,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      const SizedBox(height: 2),
                                      const tab_text.TextWidget(
                                        text: 'Conversation',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xff94a3b8),
                                      ),
                                    ],
                                  ),
                                ),
                                // Checkbox
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xffffce00)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffffce00)
                                          : const Color(0xffcbd5e1),
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Selected indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const tab_text.TextWidget(
                      text: 'Selected: ',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xff64748b),
                    ),
                    tab_text.TextWidget(
                      text: _getSelectedItemName(),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Button
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xffe2e8f0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const tab_text.TextWidget(
                      text: 'Cancel',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share Button
                  ElevatedButton(
                    onPressed: _selectedItems.isEmpty ? null : _onShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedItems.isEmpty
                          ? const Color(0xffe2e8f0)
                          : const Color(0xffffce00),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: tab_text.TextWidget(
                      text: 'Share To Chat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedItems.isEmpty
                          ? const Color(0xff94a3b8)
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
