import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:print_helper/admin/chat/view/chat_window.dart';
import 'package:print_helper/admin/chat/view/groupchat/create_group.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/loaders.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import '../../../constants/paths.dart';

import '../../../widgets/spacers.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _listRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pro = getChatPro(context);
      final authpro = getAuthPro(context);
      await pro.loadConversations();
      if (!mounted) return;
      pro.initChatListSocket(
        userId: authpro.user!.id.toString(),
        context: context,
      );
      _startListRefreshTimer();
    });
  }

  void _startListRefreshTimer() {
    _listRefreshTimer?.cancel();
    _listRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      final pro = getChatPro(context);
      if (_searchController.text.trim().isNotEmpty) return;
      await pro.loadConversations(showLoading: false);
    });
  }

  @override
  void dispose() {
    _listRefreshTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    getChatPro(context).clearUserSearch();
  }

  void _unfocusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _appBar(context),
      body: Consumer<ChatPro>(
        builder: (context, pro, _) {
          return SafeArea(
            child: Column(
              children: [
                Spacers.sb10(),
                _searchBar(pro),
                Spacers.sb10(),
                Divider(color: Color(0XFFe6e7e6), height: 1),
                Spacers.sb10(),
                Expanded(
                  child: pro.searchResults.isNotEmpty
                      ? _searchResultsList(pro)
                      : _chatList(pro),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chatList(ChatPro pro) {
    if (pro.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(18.0.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextWidget(
                text: 'Welcome!',
                fontSize: 22,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.bold,
              ),
              TextWidget(
                text: 'Connect with your team instantly.',
                fontSize: 14,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w500,
              ),
              TextWidget(
                text: 'Start a conversation by searching for users above',
                fontSize: 14,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w500,
              ),
              // TextWidget(
              //   text:
              //       'Connect with your team instantly. \nStart a conversation by searching for users above',
              //   fontSize: 16,
              //   textAlign: TextAlign.center,
              //   fontWeight: FontWeight.w600,
              // ),
            ],
          ),
        ),
      );
    }
    final currentUserId = getAuthPro(context).user?.id;
    return RefreshIndicator(
      onRefresh: () async {
        await pro.loadConversations();
      },
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: pro.conversations.length,
        separatorBuilder: (context, index) => Divider(color: Color(0XFFe6e7e6)),
        itemBuilder: (context, index) {
          final chat = pro.conversations[index];
          final participant =
              chat.type == 'private' && chat.participants.isNotEmpty
              ? chat.participants.first
              : null;
          final isDeletedUser = participant?.id == null;
          return GestureDetector(
            onTap: () async {
              _clearSearch();
              await navTo(
                context: context,
                page: ChatScreen(
                  conversationId: chat.id,
                  title: chat.title,
                  receiverUserId:
                      chat.type == 'private' && chat.participants.isNotEmpty
                      ? (chat.participants.first.id ?? 0)
                      : 0,
                ),
              );
              if (!mounted) return;
              _unfocusSearch();
              final chatPro = getChatPro(context);
              chatPro.markConversAsRead(chat.id);
            },
            child: ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50.r),
                  border: Border.all(color: Color(0xffe6e7e6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50.r),
                  child: ImageWidget(
                    image: chat.type == 'private'
                        // PRIVATE CHAT
                        ? (chat.image.isNotEmpty ? chat.image : Paths.user)
                        // GROUP CHAT
                        : (chat.image.isNotEmpty ? chat.image : Paths.other),
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              title: Row(
                crossAxisAlignment: .center,
                mainAxisAlignment: .start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextWidget(
                      text: chat.title,
                      color: Color(0xff414345),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (chat.type == 'private')
                    Expanded(
                      flex: 3,
                      child: TextWidget(
                        text: isDeletedUser
                            ? 'Deleted User'
                            : '@${participant?.username ?? 'deleted user'}',
                        color: isDeletedUser ? Colors.red : Color(0xff414345),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
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
                        color: Color(0xff414345),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  chat.latestMessage != null
                      ? Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              TextWidget(
                                text: chat.latestMessage != null
                                    ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(chat.latestMessage!.createdAt)
                                    : '',
                                color: Colors.grey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ],
                          ),
                        )
                      : Spacer(flex: 3),
                ],
              ),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
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
                  if (chat.unreadCount > 0)
                    Container(
                      constraints: BoxConstraints(
                        minWidth: 25.w,
                        minHeight: 20.w,
                      ),
                      margin: EdgeInsets.only(top: 5.w, right: 4.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(50.r),
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
        },
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    final authPro = getAuthPro(context);
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      elevation: 0,
      title: Row(
        crossAxisAlignment: .end,
        children: [
          Icon(CupertinoIcons.text_bubble, color: AppColors.black, size: 25.sp),
          Spacers.sbw12(),
          TextWidget(
            text: "Messages",
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
            fontFam: MyFontFam.poppins,
            color: Color(0XFF414345),
          ),
        ],
      ),
      actions: [
        authPro.user!.roleName == 'ADMIN'
            ? GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withValues(alpha: .25),
                    builder: (_) => FractionallySizedBox(
                      heightFactor: .98,
                      child: CreateChatGroup(
                        onSuccess: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: TextWidget(
                    text: "+ Group",
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0XFF414345),
                  ),
                ),
              )
            : SizedBox(),
        Spacers.sbw10(),
      ],
    );
  }

  Widget _searchBar(ChatPro pro) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      height: 40.h,
      decoration: BoxDecoration(
        color: const Color(0xfff1f1f2),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, color: Colors.grey),
          Spacers.sbw10(),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: pro.onSearchGlobalChanged,
              decoration: const InputDecoration(
                hintText: "Find People or Groups",
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

  Widget _searchResultsList(ChatPro pro) {
    if (pro.searchResults.isEmpty) {
      return Center(
        child: TextWidget(
          text: 'No users found',
          fontSize: 14,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return ListView.separated(
      itemCount: pro.searchResults.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (_, _) => Divider(color: Color(0XFFe6e7e6), height: 1),
      itemBuilder: (context, index) {
        final user = pro.searchResults[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(50.r),
            child: ImageWidget(
              image: user.image?.isNotEmpty == true ? user.image! : Paths.user,
              height: 35,
              width: 35,
            ),
          ),
          title: TextWidget(
            text: "${user.name} ${user.lastName}",
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          onTap: () async {
            _clearSearch();
            final existingId = pro.findPrivateConversationWithUser(user.id);
            await navTo(
              context: context,
              page: ChatScreen(
                conversationId: existingId,
                title: user.name,
                receiverUserId: user.id,
              ),
            );
            if (!mounted) return;
            _unfocusSearch();
          },
        );
      },
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
        color: Colors.black54,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Handle video messages
    if (msg.type == 'video') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, size: 14.sp, color: Colors.black54),
          SizedBox(width: 4.w),
          Flexible(
            child: TextWidget(
              text: msg.message.isNotEmpty ? msg.message : 'Video',
              color: Colors.black54,
              fontWeight: FontWeight.w500,
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

      // Caller: 'You' if current user, else sender's name
      final callerName = isSelfCaller
          ? 'You'
          : (msg.userName != null
                ? '${msg.userName}${msg.userLastName != null && msg.userLastName!.isNotEmpty ? ' ${msg.userLastName}' : ''}'
                : 'Unknown');

      // Callee: first entry in toUsers
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
          constraints: BoxConstraints(maxWidth: 220.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20.r),
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
                size: 11.sp,
                color: iconColor,
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.sp,
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

    // Handle non-call voice messages
    if (msg.type == 'voice') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 14.sp, color: Colors.black54),
          SizedBox(width: 4.w),
          Flexible(
            child: TextWidget(
              text: 'Voice message',
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return TextWidget(
      text: msg.message.isEmpty ? 'No messages yet' : msg.message,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
      fontSize: 13,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
