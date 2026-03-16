import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'groupchat/tab_create_group.dart';
import 'tab_chat_screen.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
import '../../tab_widgets/tab_spacers.dart';

class ChatList extends StatefulWidget {
  final Function(ChatConversation)? onChatSelected;

  const ChatList({super.key, this.onChatSelected});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatPro = getChatPro(context);
      final authPro = getAuthPro(context);
      await chatPro.loadConversations();
      if (!mounted) return;
      chatPro.initChatListSocket(
        userId: authPro.user!.id.toString(),
        context: context,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatPro>(
      builder: (context, chatPro, child) {
        final displayList = chatPro.searchResults.isNotEmpty
            ? chatPro.searchResults
            : chatPro.conversations;
        return Container(
          color: AppColors.white,
          child: Column(
            children: [
              _appBar(context, chatPro),
              Spacers.sb10(),
              _searchBar(chatPro),
              Spacers.sb10(),
              const Divider(height: 1, color: Color(0xffe6e7e6)),
              Expanded(
                child: displayList.isEmpty
                    ? Center(
                        child: TextWidget(
                          text: chatPro.searchResults.isNotEmpty
                              ? "No users found"
                              : "No conversations yet",
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await chatPro.loadConversations();
                        },
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: displayList.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xffe6e7e6),
                          ),
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            if (item is ChatConversation) {
                              return _chatTile(item, chatPro);
                            } else {
                              return _searchUserTile(item, chatPro);
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchUserTile(dynamic user, ChatPro chatPro) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: ImageWidget(
          image: user.image?.isNotEmpty == true ? user.image! : Paths.user,
          height: 40,
          width: 40,
          fit: BoxFit.cover,
        ),
      ),
      title: TextWidget(
        text: "${user.name} ${user.lastName}",
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      onTap: () {
        chatPro.clearUserSearch();
        _searchController.clear();

        // Check if conversation already exists with this user or group
        final existingConversation = chatPro.conversations.firstWhere(
          (conv) {
            // Check for private conversation
            if (conv.type == 'private' &&
                conv.participants.any((p) => p.id == user.id)) {
              return true;
            }
            // Check for group conversation by matching title or ID
            if (conv.type == 'group') {
              final fullName = "${user.name} ${user.lastName}".trim();
              return conv.title == fullName || conv.id == user.id;
            }
            return false;
          },
          orElse: () => ChatConversation(
            id: 0, // temporary ID for new conversation
            type: 'private',
            title: user.name,
            image: user.image?.isNotEmpty == true ? user.image! : Paths.user,
            participants: [
              ChatParticipant(
                id: user.id ?? 0,
                name: user.name,
                lastName: user.lastName,
                username: user.email ?? '',
                image: user.image,
                isOnline: false,
                phoneNumbers: [],
              ),
            ],
            otherParticipants: OtherParticipant(
              id: user.id ?? 0,
              name: user.name,
              username: user.email ?? '',
            ),
            latestMessage: null,
            unreadCount: 0,
            updatedAt: DateTime.now(),
            isDefault: false,
          ),
        );

        if (widget.onChatSelected != null) {
          widget.onChatSelected!(existingConversation);
        }
      },
    );
  }

  bool _isPhoneTitle(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 7) return false;
    return RegExp(r'^[0-9\s\(\)\-\+\.]+$').hasMatch(title);
  }

  Widget _unsavedAccountButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: TextWidget(
          text: '+ Account',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _chatTile(ChatConversation chat, ChatPro chatPro) {
    final participant = chat.type == 'private' && chat.participants.isNotEmpty
        ? chat.participants.first
        : null;
    final isDeletedUser = participant?.id == null;
    final authPro = getAuthPro(context);
    final currentUserId = authPro.user?.id;

    // Check if the latest message was sent by current user
    final isMyMessage =
        chat.latestMessage?.userId != null &&
        chat.latestMessage!.userId == currentUserId;

    return InkWell(
      onTap: () async {
        if (widget.onChatSelected != null) {
          widget.onChatSelected!(chat);
        } else {
          // Clear search bar when entering chat
          final pro = getChatPro(context);
          pro.clearUserSearch();
          _searchController.clear();

          navTo(
            context: context,
            page: ChatScreen(
              conversationId: chat.id,
              receiverUserId: participant?.id ?? 0,
              name: chat.title,
              image: chat.type == 'private'
                  ? (chat.image.isNotEmpty ? chat.image : Paths.user)
                  : (chat.image.isNotEmpty ? chat.image : Paths.other),
              subtitle: chat.type == 'private'
                  ? (_isPhoneTitle(chat.title)
                        ? ''
                        : (isDeletedUser
                              ? 'Deleted User'
                              : '@${participant?.username ?? 'deleted user'}'))
                  : (chat.latestMessage?.userName ?? 'Group'),
              onBack: () {
                Navigator.of(context).pop();
              },
              showBack: true,
            ),
          );
          pro.markConversAsRead(chat.id);
        }
      },
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xffe6e7e6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: ImageWidget(
              image: chat.type == 'private'
                  ? (chat.image.isNotEmpty ? chat.image : Paths.user)
                  : (chat.image.isNotEmpty ? chat.image : Paths.other),
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: TextWidget(
                text: chat.title,
                color: const Color(0xff414345),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (chat.type == 'private' && _isPhoneTitle(chat.title))
              Expanded(flex: 3, child: _unsavedAccountButton())
            else if (chat.type == 'private' &&
                chat.latestMessage?.userName != null)
              Expanded(
                flex: 3,
                child: TextWidget(
                  text: '@${chat.latestMessage?.userName ?? 'Unknown'}',
                  color: const Color(0xff939393),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else if (chat.type == 'private')
              Expanded(
                flex: 3,
                child: TextWidget(
                  text: isDeletedUser
                      ? 'Deleted User'
                      : '@${participant?.username ?? 'deleted user'}',
                  color: isDeletedUser ? Colors.red : const Color(0xff939393),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else if (chat.type == 'group' &&
                chat.latestMessage?.userName != null)
              Expanded(
                flex: 3,
                child: TextWidget(
                  text: '@${chat.latestMessage?.userName ?? 'Unknown'}',
                  color: const Color(0xff939393),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(flex: 3),
            const SizedBox(width: 12),
            if (chat.latestMessage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextWidget(
                    text: DateFormat(
                      'dd MMM yyyy',
                    ).format(chat.latestMessage!.createdAt),
                    color: const Color(0xff939393),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                  ),
                ],
              )
            else
              const Spacer(flex: 2),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Expanded(
              child: _buildLatestMessageSubtitle(
                chat.latestMessage,
                isSelfCaller:
                    chat.latestMessage?.userId != null &&
                    chat.latestMessage!.userId == currentUserId,
                calleeFallback:
                    chat.type == 'private' && chat.participants.isNotEmpty
                    ? '${chat.participants.first.name} ${chat.participants.first.lastName}'
                          .trim()
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            if (chat.unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: TextWidget(
                    text: chat.unreadCount > 999
                        ? '999+'
                        : chat.unreadCount.toString(),
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestMessageSubtitle(
    ChatLatestMessage? msg, {
    String? calleeFallback,
    bool isSelfCaller = false,
  }) {
    if (msg == null) {
      return TextWidget(
        text: 'No messages yet',
        color: const Color(0xff6b6b6b),
        fontWeight: FontWeight.w400,
        fontSize: 13,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (msg.type == 'video') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Flexible(
            child: TextWidget(
              text: msg.message.isNotEmpty ? msg.message : 'Video',
              color: const Color(0xff6b6b6b),
              fontWeight: FontWeight.w400,
              fontSize: 13,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final isCallMsg =
        msg.type == 'call' || (msg.type == 'voice' && msg.isCallRecording);

    if (isCallMsg) {
      final isMissed =
          msg.callOutcome == 'missed' ||
          msg.callOutcome == 'no-answer' ||
          (msg.callOutcome == null && msg.type == 'call');

      final callerName = isSelfCaller
          ? 'You'
          : (msg.userName != null
                ? '${msg.userName}${msg.userLastName != null && msg.userLastName!.isNotEmpty ? ' ${msg.userLastName}' : ''}'
                : 'Unknown');

      final toUser = msg.toUsers?.isNotEmpty == true
          ? msg.toUsers!.first
          : null;
      final calleeName = toUser != null
          ? (toUser['name']?.toString() ?? 'Unknown')
          : calleeFallback;

      final chipColor = isMissed
          ? const Color(0xFFFFF0F0)
          : const Color(0xFFEDFBF0);
      final iconColor = isMissed ? Colors.red : Colors.green;
      final textColor = isMissed ? Colors.red : Colors.green;

      final label = calleeName != null
          ? '$callerName → $calleeName'
          : callerName;

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMissed ? Icons.phone_missed : Icons.phone_forwarded,
                size: 11,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.type == 'voice') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Flexible(
            child: TextWidget(
              text: 'Voice message',
              color: const Color(0xff6b6b6b),
              fontWeight: FontWeight.w400,
              fontSize: 13,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (msg.type == 'image') {
      return TextWidget(
        text: '📷 Image',
        color: const Color(0xff6b6b6b),
        fontWeight: FontWeight.w400,
        fontSize: 13,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return TextWidget(
      text: msg.message.isEmpty ? 'No messages yet' : msg.message,
      color: const Color(0xff6b6b6b),
      fontWeight: FontWeight.w400,
      fontSize: 13,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // 🔹 AppBar (Left Panel)
  Widget _appBar(BuildContext context, ChatPro chatPro) {
    final authPro = getAuthPro(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(CupertinoIcons.text_bubble, size: 24, color: Colors.black),
          Spacers.sbw10(),
          TextWidget(
            text: "Messages",
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff414345),
          ),
          const Spacer(),
          if (authPro.user?.roleName == 'ADMIN')
            GestureDetector(
              onTap: () {
                _openRightSideSheet(context, CreateChatGroup());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary),
                ),
                child: TextWidget(
                  text: "+ Group",
                  fontSize: 12,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔹 Search Bar
  Widget _searchBar(ChatPro chatPro) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xfff1f1f2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                chatPro.onSearchGlobalChanged(value);
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Find People or Groups",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                isDense: true,
              ),
            ),
          ),
          if (chatPro.isLoading)
            SizedBox(height: 16, width: 16, child: showLoader()),
        ],
      ),
    );
  }

  Future<dynamic> _openRightSideSheet(BuildContext context, Widget child) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RightSideSheet",
      barrierColor: Colors.black.withValues(alpha: .25),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              height: MediaQuery.of(context).size.height,
              margin: const EdgeInsets.only(top: 0, right: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
