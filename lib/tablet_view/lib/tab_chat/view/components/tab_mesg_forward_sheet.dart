import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/loaders.dart';
import '../../../tab_constants/paths.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';

class ForwardMessageSheet extends StatefulWidget {
  final ChatMessage messageToForward;

  const ForwardMessageSheet({super.key, required this.messageToForward});

  @override
  State<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<ForwardMessageSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    // We clear the search results when closing the sheet
    // Using addPostFrameCallback ensures we don't trigger updates during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatPro>().clearUserSearch();
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spacers.sb12(),
              // --- Header Indicator ---
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Spacers.sb12(),
              // --- Search Bar ---
              _buildSearchBar(context),
              Spacers.sb10(),
              const Divider(height: 1),
              // --- List Area ---
              Expanded(
                child: Consumer<ChatPro>(
                  builder: (context, pro, _) {
                    if (pro.searchResults.isNotEmpty) {
                      return _buildSearchList(pro);
                    }
                    return _buildRecentChatList(pro);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final pro = context.read<ChatPro>();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.symmetric(horizontal: 14),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xfff1f1f2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, color: Colors.grey),
          Spacers.sbw10(),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: pro.onSearchGlobalChanged,
              decoration: const InputDecoration(
                hintText: "Search people",
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (pro.isLoading)
            SizedBox(height: 16, width: 16, child: showLoader()),
        ],
      ),
    );
  }

  Widget _buildSearchList(ChatPro pro) {
    return ListView.separated(
      itemCount: pro.searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = pro.searchResults[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: ImageWidget(
              image: user.image?.isNotEmpty == true ? user.image! : Paths.user,
              height: 35,
              width: 35,
            ),
          ),
          title: TextWidget(
            text: "${user.name} ${user.lastName}",
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onTap: () => _forwardToUser(user.id),
        );
      },
    );
  }

  Widget _buildRecentChatList(ChatPro pro) {
    return ListView.separated(
      itemCount: pro.conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = pro.conversations[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: ImageWidget(
              image: chat.image.isNotEmpty ? chat.image : Paths.user,
              height: 35,
              width: 35,
            ),
          ),
          title: TextWidget(
            text: chat.title,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          onTap: () => _forwardToConversation(chat.id),
        );
      },
    );
  }

  // --- Logic ---

  Future<void> _forwardToUser(int userId) async {
    final pro = context.read<ChatPro>();
    final auth = context.read<AuthPro>();
    // 1. Find or create conversation ID
    int? conversationId = pro.findPrivateConversationWithUser(userId);
    conversationId ??= await pro.createConvId(
      type: 'private',
      userIds: [userId],
      context: context,
    );
    if (conversationId == null) return;
    // 2. Perform Forward
    await _performForward(pro, auth, conversationId);
  }

  Future<void> _forwardToConversation(int conversationId) async {
    final pro = context.read<ChatPro>();
    final auth = context.read<AuthPro>();
    // Perform Forward
    await _performForward(pro, auth, conversationId);
  }

  // ✅ CENTRALIZED LOGIC FOR FORWARDING (Voice & Text)
  Future<void> _performForward(
    ChatPro pro,
    AuthPro auth,
    int conversationId,
  ) async {
    Loaders.show();
    try {
      final msg = widget.messageToForward;
      if (msg.type == 'voice') {
        //  FORWARD VOICE MESSAGE (Use dedicated method without re-uploading)
        await pro.forwardVoiceMessage(
          audioUrl: msg.audioUrl!, // Pass existing remote URL
          audioDuration: msg.audioDuration ?? 0, // Pass existing Duration
          conversationId: conversationId,
          currentUserId: auth.user!.id,
        );
      } else {
        //  FORWARD TEXT MESSAGE
        await pro.sendMessage(
          text: msg.message,
          conversationId: conversationId,
          currentUserId: auth.user!.id,
          type: 'text',
        );
      }
      if (mounted) {
        pro.clearUserSearch();
        Navigator.pop(context); // Close sheet
      }
    } finally {
      Loaders.hide();
    }
  }
}
