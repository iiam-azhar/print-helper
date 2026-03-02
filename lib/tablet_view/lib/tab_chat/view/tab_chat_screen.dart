import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'components/tab_group_info.dart';
import 'components/tab_private_chat_info.dart';
import 'components/tab_mesg_forward_sheet.dart';
import 'components/tab_voice_mesg_bubble.dart';
import 'groupchat/tab_edit_group.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int receiverUserId;
  final String name;
  final String image;
  final String subtitle;
  final VoidCallback onBack;
  final bool showBack;
  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverUserId,
    required this.name,
    required this.image,
    required this.subtitle,
    required this.onBack,
    required this.showBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool isSmsSelected = true;
  String selectedSmsNumber = "(323) 000-0000";
  File? _pendingImage;
  String? pendingFileName;
  bool _pendingIsPdf = false;
  bool _showEmojiPicker = false;
  bool _isSearchMode = false;
  ChatMessage? _editingMessage;
  final Map<int, bool> _expandedMessages = {};
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  Timer? _searchDebounce;
  List<ChatMessage> searchResults = [];
  String? currentVisibleDate;
  bool _isChatDisabled = false;
  bool _isUserOnline = false;
  DateTime? _userLastSeen;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  late ChatPro _chatPro;

  final List<String> smsNumbers = [
    "(323) 000-0000",
    "(323) 808-4052",
    "(415) 123-4567",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pro = getChatPro(context);
      final authpro = getAuthPro(context);
      pro.isChatScreenOpen = true;

      if (widget.conversationId == null) return;
      // Fetch user profile for online/last seen status
      final convo = pro.conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ChatConversation(
          id: -1,
          type: 'private',
          title: widget.name,
          participants: [],
          latestMessage: null,
          image: widget.image,
          unreadCount: 0,
          updatedAt: DateTime.now(),
          isDefault: true,
        ),
      );
      if (convo.type == 'private' && convo.participants.isNotEmpty) {
        setState(() {
          _isUserOnline = convo.participants[0].isOnline;
          _userLastSeen = convo.participants[0].lastSeenAt;
        });
        pro.fetchUserProfile(
          convo.participants[0].id.toString(),
          conversationId: widget.conversationId,
        );
      }
      // Mark chat as read-only if the other user was deleted
      final isDeletedPeer =
          convo.type == 'private' &&
          convo.participants.isNotEmpty &&
          convo.participants.first.id == null;
      if (mounted && isDeletedPeer != _isChatDisabled) {
        setState(() => _isChatDisabled = isDeletedPeer);
      }
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0.0);
      }
      await _getChatMessages(pro, authpro);
      _scrollCtrl.addListener(_onScroll);
      if (widget.conversationId != null && widget.conversationId != 0) {
        // Mark conversation as read when opening chat
        await pro.markConversAsRead(widget.conversationId!);
        await pro.initConversationSocket(
          conversationId: widget.conversationId!,
          currentUserId: authpro.user!.id,
        );
      }
    });
  }

  Future<void> _getChatMessages(ChatPro pro, AuthPro authpro) async {
    // If conversationId is null or 0, find existing conversation with receiverUserId
    int? actualConversationId = widget.conversationId;
    if (actualConversationId == null || actualConversationId == 0) {
      final existingConversation = pro.conversations.firstWhere(
        (conv) {
          // For private chats, match by participant ID
          if (conv.type == 'private') {
            return conv.participants.any((p) => p.id == widget.receiverUserId);
          }
          // For groups, match by group name or receiverUserId if it matches a group
          if (conv.type == 'group') {
            return conv.title == widget.name ||
                conv.id == widget.receiverUserId;
          }
          return false;
        },
        orElse: () => ChatConversation(
          id: -1,
          type: 'private',
          title: widget.name,
          participants: [],
          latestMessage: null,
          image: widget.image,
          unreadCount: 0,
          updatedAt: DateTime.now(),
          isDefault: false,
        ),
      );
      actualConversationId = existingConversation.id;
    }

    // Only fetch messages if we have a valid conversation ID
    if (actualConversationId > 0) {
      await pro.fetchMessages(
        conversationId: actualConversationId.toString(),
        currentUserId: authpro.user!.id,
      );
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 100) {
      final pro = getChatPro(context);
      final auth = getAuthPro(context);
      final firstMsg = pro.messages.isNotEmpty ? pro.messages[0] : null;
      if (firstMsg != null) {
        final label = _chatDateLabel(firstMsg.createdAt);
        if (label != currentVisibleDate) {
          setState(() {
            currentVisibleDate = label;
          });
        }
      }
      if (!pro.isLoadingMore && pro.hasMore) {
        // Get the actual conversation ID (handle case where it's 0 or null)
        int? actualConversationId = widget.conversationId;
        if (actualConversationId == null || actualConversationId == 0) {
          final existingConversation = pro.conversations.firstWhere(
            (conv) {
              // For private chats, match by participant ID
              if (conv.type == 'private') {
                return conv.participants.any(
                  (p) => p.id == widget.receiverUserId,
                );
              }
              // For groups, match by group name or receiverUserId if it matches a group
              if (conv.type == 'group') {
                return conv.title == widget.name ||
                    conv.id == widget.receiverUserId;
              }
              return false;
            },
            orElse: () => ChatConversation(
              id: -1,
              type: 'private',
              title: widget.name,
              participants: [],
              latestMessage: null,
              image: widget.image,
              unreadCount: 0,
              updatedAt: DateTime.now(),
              isDefault: false,
            ),
          );
          actualConversationId = existingConversation.id;
        }
        if (actualConversationId > 0) {
          pro.fetchMessages(
            conversationId: actualConversationId.toString(),
            currentUserId: auth.user!.id,
            loadMore: true,
          );
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatPro = Provider.of<ChatPro>(context, listen: false);
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If conversation changed, reset and reload
    if (oldWidget.conversationId != widget.conversationId) {
      _messageCtrl.clear();
      _searchCtrl.clear();
      _editingMessage = null;
      searchResults = [];
      _showEmojiPicker = false;
      _isSearchMode = false;
      _isChatDisabled = false;

      // Reinitialize for new conversation
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final pro = getChatPro(context);
        final authpro = getAuthPro(context);

        // Disconnect old socket and reset state
        pro.disconnectConversationSocket();
        pro.reset(); // This clears messages and resets pagination

        if (widget.conversationId != null && widget.conversationId != 0) {
          await _getChatMessages(pro, authpro);
          // Mark new conversation as read
          await pro.markConversAsRead(widget.conversationId!);
          await pro.initConversationSocket(
            conversationId: widget.conversationId!,
            currentUserId: authpro.user!.id,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.conversationId != null) {
      _chatPro.disconnectConversationSocket();
    }
    _chatPro.isChatScreenOpen = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPro.clearSearch();
    });

    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _recordTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _startEditing(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _messageCtrl.text = msg.message;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageCtrl.clear();
    });
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    setState(() {
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordDuration = Duration(seconds: timer.tick);
      });
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    setState(() {
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void searchMessages(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (widget.conversationId != null) {
        final authPro = getAuthPro(context);
        getChatPro(context).searchMessages(
          conversationId: widget.conversationId.toString(),
          query: query,
          currentUserId: authPro.user!.id,
        );
      }
    });
  }

  String _chatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return DateFormat("d MMM yyyy").format(dt);
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inSeconds < 60) {
      return "now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else if (diff.inDays == 1) {
      return "yesterday";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    } else {
      return DateFormat("d MMM").format(lastSeen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7f9),
      appBar: _appBar(context),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: ImageWidget(image: Paths.chatBgg, fit: BoxFit.cover),
          ),
          Column(
            children: [
              // Search bar
              if (_isSearchMode) _buildSearchBar(context),
              Expanded(
                child: Consumer<ChatPro>(
                  builder: (context, chatPro, _) {
                    final displayMessages = _isSearchMode && chatPro.isSearching
                        ? chatPro.messageSearchResults
                        : chatPro.messages;
                    final isSearchView = _isSearchMode && chatPro.isSearching;

                    if (displayMessages.isEmpty) {
                      return Center(
                        child: TextWidget(
                          text: 'No messages yet',
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: !isSearchView,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, index) {
                        final msg = displayMessages[index];
                        bool showHeader = false;
                        final isLast = index == displayMessages.length - 1;
                        if (!isSearchView) {
                          if (isLast) {
                            showHeader = true;
                          } else {
                            final nextMsg = displayMessages[index + 1];
                            final currDate = DateTime(
                              msg.createdAt.year,
                              msg.createdAt.month,
                              msg.createdAt.day,
                            );
                            final nextDate = DateTime(
                              nextMsg.createdAt.year,
                              nextMsg.createdAt.month,
                              nextMsg.createdAt.day,
                            );
                            if (currDate != nextDate) showHeader = true;
                          }
                        }
                        return Column(
                          children: [
                            if (showHeader) _dateHeader(msg.createdAt),
                            _messageRow(
                              msg,
                              highlightQuery: isSearchView
                                  ? chatPro.searchQuery
                                  : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Consumer<ChatPro>(
                builder: (context, pro, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pro.isOtherUserTyping) _typingIndicator(),
                      _inputBar(),
                      if (_showEmojiPicker)
                        SizedBox(
                          height: 280,
                          child: EmojiPicker(
                            textEditingController: _messageCtrl,
                            config: Config(
                              height: 280,
                              checkPlatformCompatibility: true,
                              emojiViewConfig: EmojiViewConfig(
                                columns: 8,
                                emojiSizeMax: 28,
                              ),
                              bottomActionBarConfig: BottomActionBarConfig(
                                enabled: true,
                                showBackspaceButton: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------- */
  /* APP BAR                                             */
  /* ------------------------------------------------------- */
  AppBar _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 5,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Consumer<ChatPro>(
        builder: (context, chatPro, child) {
          // Update online status or group members if available from provider
          String subtitle = '';
          late ChatConversation convo;
          if (widget.conversationId != null && widget.conversationId! > 0) {
            convo = chatPro.conversations.firstWhere(
              (c) => c.id == widget.conversationId,
              orElse: () => ChatConversation(
                id: -1,
                type: 'private',
                title: widget.name,
                participants: [],
                latestMessage: null,
                image: widget.image,
                unreadCount: 0,
                updatedAt: DateTime.now(),
                isDefault: true,
              ),
            );
            if (convo.id > 0) {
              if (convo.type == 'group') {
                // For groups, show member count
                final memberCount = convo.participants.length;
                subtitle = memberCount == 1
                    ? '1 member'
                    : '$memberCount members';
              } else if (convo.type == 'private' &&
                  convo.participants.isNotEmpty) {
                // For private chats, show online status
                _isUserOnline = convo.participants[0].isOnline;
                _userLastSeen = convo.participants[0].lastSeenAt;
                subtitle = _isUserOnline
                    ? 'Online'
                    : (_userLastSeen != null
                          ? 'Last seen ${_formatLastSeen(_userLastSeen!)}'
                          : 'Offline');
              }
            }
          } else {
            convo = ChatConversation(
              id: -1,
              type: 'private',
              title: widget.name,
              participants: [],
              latestMessage: null,
              image: widget.image,
              unreadCount: 0,
              updatedAt: DateTime.now(),
              isDefault: true,
            );
          }
          return Row(
            children: [
              if (widget.showBack)
                IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  onPressed: widget.onBack,
                ),
              GestureDetector(
                onTap: () {
                  // Open edit group panel if it's a group chat, or info panel for private chat
                  if (widget.conversationId != null &&
                      widget.conversationId! > 0) {
                    final convo = chatPro.conversations.firstWhere(
                      (c) => c.id == widget.conversationId,
                      orElse: () => ChatConversation(
                        id: -1,
                        type: 'private',
                        title: '',
                        participants: [],
                        latestMessage: null,
                        image: '',
                        unreadCount: 0,
                        updatedAt: DateTime.now(),
                        isDefault: false,
                      ),
                    );
                    if (convo.id > 0 && convo.type == 'group') {
                      _openRightSideSheet(
                        context,
                        EditChatGroup(conversationId: widget.conversationId!),
                        fullHeight: true,
                      );
                    } else if (convo.id > 0 && convo.type == 'private') {
                      // Show private chat info panel
                      _openRightSideSheet(
                        context,
                        PrivateChatInfo(conversation: convo),
                        fullHeight: true,
                      );
                    }
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: convo.id > 0 ? (convo.title) : widget.name,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    TextWidget(
                      text: subtitle,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: (_isUserOnline || subtitle.contains('member'))
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: ImageWidget(image: Paths.vc.toString(), width: 28),
          onPressed: () {},
        ),
        SizedBox(width: 18),
        Icon(CupertinoIcons.phone),
        SizedBox(width: 18),
        // Show info button for group chats only
        Consumer<ChatPro>(
          builder: (context, chatPro, _) {
            if (widget.conversationId == null || widget.conversationId! <= 0) {
              return const SizedBox.shrink();
            }

            final convo = chatPro.conversations.firstWhere(
              (c) => c.id == widget.conversationId,
              orElse: () => ChatConversation(
                id: -1,
                type: 'private',
                title: widget.name,
                participants: [],
                latestMessage: null,
                image: widget.image,
                unreadCount: 0,
                updatedAt: DateTime.now(),
                isDefault: true,
              ),
            );

            if (convo.id == -1) return const SizedBox.shrink();

            final isGroupChat = convo.type == 'group';

            // Only show info button for group chats
            if (!isGroupChat) {
              return const SizedBox.shrink();
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(CupertinoIcons.info),
                  onPressed: () {
                    // Show group info panel
                    final maxHeight = MediaQuery.of(context).size.height * 0.6;
                    final estimatedHeight =
                        (56 + (convo.participants.length * 72) + 20)
                            .clamp(200, maxHeight)
                            .toDouble();
                    _openRightSideSheet(
                      context,
                      GroupInfo(conversation: convo),
                      height: estimatedHeight,
                    );
                  },
                ),
                SizedBox(width: 18),
              ],
            );
          },
        ),
        IconButton(
          icon: Icon(CupertinoIcons.search),
          onPressed: () {
            setState(() {
              _isSearchMode = !_isSearchMode;
              if (!_isSearchMode) {
                _searchCtrl.clear();
                searchResults = [];
              }
            });
          },
        ),
        SizedBox(width: 12),
      ],
    );
  }

  Widget _dateHeader(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextWidget(
            text: _chatDateLabel(dt),
            color: Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _messageRow(ChatMessage msg, {String? highlightQuery}) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: msg.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: ImageWidget(
                  image: msg.senderAvatar ?? Paths.user,
                  height: 35,
                  width: 35,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: _bubble(msg, highlightQuery: highlightQuery),
            ),
          ),
          // if (msg.isMe) const
          SizedBox(width: 8),
          _messageMenu(msg),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage msg, {String? highlightQuery}) {
    // Special rendering for call type
    if (msg.type == 'call') {
      return _buildCallBubble(msg);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: 370),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe && msg.senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextWidget(
                text: msg.senderName!,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          if (msg.type == 'voice' && msg.audioUrl != null)
            VoiceMessageBubbleUI(
              path: msg.audioUrl!,
              duration: msg.audioDuration ?? 0,
              isMe: msg.isMe,
              isUploading:
                  msg.isMe &&
                  (msg.audioUrl!.startsWith('/data') ||
                      msg.audioUrl!.startsWith('file://')),
            )
          else if (highlightQuery != null && highlightQuery.isNotEmpty)
            _buildHighlightedText(msg.message, highlightQuery, msg.isMe)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: msg.message,
                  maxLines: (_expandedMessages[msg.id] ?? false) ? null : 4,
                  overflow: (_expandedMessages[msg.id] ?? false)
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  fontSize: 13,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                if (msg.message.split('\n').length > 4 ||
                    msg.message.length > 200)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedMessages[msg.id] =
                            !(_expandedMessages[msg.id] ?? false);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextWidget(
                        text: (_expandedMessages[msg.id] ?? false)
                            ? 'Read less'
                            : 'Read more',
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          _metaRow(msg),
        ],
      ),
    );
  }

  Widget _metaRow(ChatMessage msg) {
    Color iconColor = Colors.grey;
    IconData iconData = Icons.done;
    if (msg.isRead == true) {
      iconData = Icons.done_all;
      iconColor = Colors.blue;
    } else if (msg.isDelivered == true) {
      iconData = Icons.done_all;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextWidget(
          text:
              'APP Chat • ${DateFormat('dd/MM/yyyy hh:mm a').format(msg.createdAt)}',
          fontSize: 10,
          color: Colors.black54,
          fontWeight: FontWeight.w400,
          overflow: TextOverflow.ellipsis,
        ),
        if (msg.isMe) ...[
          const SizedBox(width: 4),
          Icon(iconData, size: 14, color: iconColor),
        ],
      ],
    );
  }

  Widget _buildCallBubble(ChatMessage msg) {
    // Extract call details from message properties
    final isMissed = msg.isMissedCall ?? false;
    final callStatus = msg.callStatus ?? '';
    final direction = msg.callDirection ?? '';
    final toNumber = msg.callToNumber ?? '';
    final fromNumber = msg.callFromNumber ?? '';
    
    // If no call details, show fallback
    if (direction.isEmpty && toNumber.isEmpty && fromNumber.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: 370),
        decoration: BoxDecoration(
          color: Color(0xFFF8D7DA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFFE8B4BC), width: 1.5),
        ),
        child: TextWidget(
          text: msg.message,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
      );
    }
    final displayNumber = direction == 'outgoing' ? toNumber : fromNumber;
    // Determine call type text
    String callTypeText = 'Call';
    if (isMissed) {
      callTypeText = 'Missed Call';
    } else if (callStatus == 'busy') {
      callTypeText = 'Busy - Missed Call';
    } else if (callStatus == 'no-answer') {
      callTypeText = 'No Answer';
    } else if (callStatus == 'completed') {
      callTypeText = 'Call Completed';
    }
    // Format phone number
    String formatPhoneNumber(String? number) {
      if (number == null || number.isEmpty) return '';
      if (number.length == 11 && number.startsWith('1')) {
        // US format: 1XXXXXXXXXX -> (XXX) XXX-XXXX
        return '(${number.substring(1, 4)}) ${number.substring(4, 7)}-${number.substring(7)}';
      }
      return number;
    }

    final formattedNumber = formatPhoneNumber(displayNumber);
    if (isMissed == true) {
      final formattedToNumber = formatPhoneNumber(toNumber);
      final formattedFromNumber = formatPhoneNumber(fromNumber);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: 370),
        decoration: BoxDecoration(
          color: const Color(0xFFF8D7DA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ImageWidget(image: Paths.cross, height: 15, width: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: TextWidget(
                    text: msg.senderName != null && msg.senderName!.isNotEmpty
                        ? 'Missed Called From ${msg.senderName}'
                        : 'Missed Called',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    child: TextWidget(
                      text:
                          (formattedFromNumber.isNotEmpty ||
                              formattedToNumber.isNotEmpty)
                          ? 'From: $formattedFromNumber • To: $formattedToNumber'
                          : formattedNumber,
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextWidget(
                      text: DateFormat(
                        'MM/dd/yyyy • h:mm a',
                      ).format(msg.createdAt),
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      constraints: BoxConstraints(maxWidth: 370),
      decoration: BoxDecoration(
        color: Color(0xFFF8D7DA), // Light pink/rose background
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE8B4BC), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
            ),
            child: ImageWidget(image: Paths.call2, width: 28, height: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: callTypeText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                const SizedBox(height: 3),
                if (msg.senderName != null && msg.senderName!.isNotEmpty)
                  TextWidget(
                    text: direction == 'outgoing'
                        ? 'To ${msg.senderName}'
                        : 'From ${msg.senderName}',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                const SizedBox(height: 6),
                TextWidget(
                  text: formattedNumber.isNotEmpty
                      ? 'From: $formattedNumber • ${DateFormat('MM/dd/yyyy • h:mm a').format(msg.createdAt)}'
                      : DateFormat('MM/dd/yyyy • h:mm a').format(msg.createdAt),
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, bool isMe) {
    if (query.isEmpty) {
      return TextWidget(
        text: text,
        fontSize: 13,
        color: Colors.black,
        fontWeight: FontWeight.w400,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <TextSpan>[];
    int lastMatchEnd = 0;

    int index = lowerText.indexOf(lowerQuery);
    while (index != -1) {
      if (index > lastMatchEnd) {
        matches.add(
          TextSpan(
            text: text.substring(lastMatchEnd, index),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }
      matches.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            backgroundColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
        ),
      );

      lastMatchEnd = index + query.length;
      index = lowerText.indexOf(lowerQuery, lastMatchEnd);
    }

    if (lastMatchEnd < text.length) {
      matches.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: matches));
  }

  Widget sentPdfMessage(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 14, left: 60, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 📄 FILE ICON (CENTERED)
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 96,
                              color: Colors.black,
                            ),
                            Positioned(
                              bottom: 18,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextWidget(
                                  text: "PDF",
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      ///  FILE NAME
                      TextWidget(
                        text: msg.message,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      /// META + TICK
                      Row(
                        children: [
                          Expanded(
                            child: TextWidget(
                              text:
                                  "APP Chat · ${DateFormat('dd/MM/yyyy hh:mm a').format(msg.createdAt)}",
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.done_all,
                            size: 16,
                            color: msg.isRead == true
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _messageMenu(msg),
          ],
        ),
      ),
    );
  }

  /* ------------------------------------------------------- */
  /*  MESSAGE MENU                                        */
  /* ------------------------------------------------------- */
  Widget _messageMenu(ChatMessage msg) {
    // Don't show menu for call messages
    if (msg.type == 'call') {
      return const SizedBox(width: 24);
    }

    final auth = context.read<AuthPro>();
    final isAdmin = auth.user?.roleName == 'ADMIN';
    final canEdit = (msg.isMe || isAdmin) && msg.type != 'voice';
    final canDelete = msg.isMe || isAdmin;
    return PopupMenuButton<String>(
      menuPadding: EdgeInsets.zero,
      splashRadius: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _startEditing(msg);
            break;
          case 'delete':
            _deletePopup(msg);
            break;
          case 'forward':
            _showForwardPopup(msg);
            break;
        }
      },
      itemBuilder: (context) => [
        if (canEdit) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                ImageWidget(image: Paths.edit, height: 18, width: 18),
                SizedBox(width: 8),
                TextWidget(
                  text: 'Edit',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              ImageWidget(image: Paths.share, height: 18, width: 18),
              SizedBox(width: 8),
              TextWidget(
                text: 'Forward',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                ImageWidget(image: Paths.delete, height: 18, width: 18),
                SizedBox(width: 8),
                TextWidget(
                  text: 'Delete',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 30,
        width: 30,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.more_vert, size: 18),
      ),
    );
  }

  Future<dynamic> _deletePopup(ChatMessage msg) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: TextWidget(
          text: "Delete Message?",
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        content: TextWidget(
          text: "Are you sure you want to delete this message?",
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: TextWidget(
              text: "Cancel",
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await getChatPro(context).deleteMessage(
                messageId: msg.id,
                conversationId: msg.conversationId,
              );
            },
            child: TextWidget(
              text: "Delete",
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------- */
  /* INPUT BAR                                           */
  /* ------------------------------------------------------- */
  Widget channelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => isSmsSelected = false);
          },
          child: Container(
            height: 33,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: !isSmsSelected ? Color(0xff231f20) : Color(0xffd1d3d4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TextWidget(
              text: "App Chat",
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        Spacers.sbw8(),
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              isSmsSelected = true;
              selectedSmsNumber = value;
            });
          },
          itemBuilder: (context) {
            return smsNumbers
                .map(
                  (n) => PopupMenuItem(
                    value: n,
                    child: Text(n, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList();
          },
          color: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSmsSelected ? Colors.black : Color(0xffd1d3d4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextWidget(
                  text: "SMS Text ",
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSmsSelected ? Colors.white : Colors.black,
                ),
                Spacers.sbw2(),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      TextWidget(
                        text: selectedSmsNumber,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      Spacers.sbw5(),
                      ImageWidget(
                        image: Paths.arrowDwn,
                        width: 10,
                        color: Colors.grey,
                      ),
                      Spacers.sbw5(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputBar() {
    final chatPro = context.watch<ChatPro>();
    final isRecording = chatPro.isRecordingVoice;
    bool isDeletedPeer = _isChatDisabled;
    if (widget.conversationId != null && widget.conversationId! > 0) {
      final convo = chatPro.conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ChatConversation(
          id: -1,
          type: 'private',
          title: widget.name,
          participants: [],
          latestMessage: null,
          image: widget.image,
          unreadCount: 0,
          updatedAt: DateTime.now(),
          isDefault: true,
        ),
      );
      if (convo.type == 'private' && convo.participants.isNotEmpty) {
        isDeletedPeer = convo.participants.first.id == null;
      }
    }
    if (isDeletedPeer) return _deletedChatBanner();
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.black, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// EDITING BANNER
              if (_editingMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: AppColors.primary, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: "Editing message",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            Spacers.sb2(),
                            TextWidget(
                              text: _editingMessage!.message,
                              maxLines: 1,
                              fontWeight: FontWeight.w400,
                              overflow: TextOverflow.ellipsis,
                              fontSize: 11,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelEditing,
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),

              /// PENDING IMAGE
              if (_pendingImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _pendingIsPdf
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 4),
                                    Text("PDF"),
                                  ],
                                )
                              : Image.file(_pendingImage!, fit: BoxFit.cover),
                        ),
                      ),

                      ///  REMOVE IMAGE BUTTON
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pendingImage = null;
                              pendingFileName = null;
                              _pendingIsPdf = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _messageCtrl,
                focusNode: _focusNode,
                enabled: !_isChatDisabled,
                readOnly: _isChatDisabled,
                minLines: 1,
                maxLines: 4,
                // maxLength: 5000,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  // Send message when Enter is pressed
                  if (_editingMessage != null) {
                    _onEditSubmit();
                  } else {
                    _sendMessage();
                  }
                },
                onTap: () {
                  setState(() {
                    _showEmojiPicker = false;
                  });
                },
                onChanged: (text) {
                  if (widget.conversationId == null) return;
                  context.read<ChatPro>().onTextTyping(
                    conversationId: widget.conversationId!,
                    text: text,
                  );
                },
                style: const TextStyle(fontFamilyFallback: ['Segoe UI Emoji']),
                decoration: InputDecoration(
                  hintText: isSmsSelected
                      ? "Type your Message....."
                      : "Type your SMS… (Carrier charges may apply)",
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              const SizedBox(height: 8),

              /// ACTION ROW
              Row(
                children: [
                  if (isRecording) ...[
                    TextWidget(
                      text: _formatDuration(_recordDuration),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        context.read<ChatPro>().cancelRecording();
                        _stopRecordTimer();
                      },
                      child: const TextWidget(
                        text: "Cancel",
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final pro = context.read<ChatPro>();
                        final auth = context.read<AuthPro>();
                        if (_recordDuration.inSeconds < 1) {
                          showToast(message: "Message too short");
                          await pro.cancelRecording();
                        } else if (widget.conversationId != null &&
                            auth.user != null) {
                          await pro.stopRecordingAndSend(
                            conversationId: widget.conversationId!,
                            currentUserId: auth.user!.id,
                          );
                        } else {
                          await pro.cancelRecording();
                        }
                        _stopRecordTimer();
                      },
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: const BoxDecoration(
                          color: Color(0xffFFC107),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stop,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    _actionIcon(
                      Icons.add_circle_outline_sharp,
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                        );
                        if (result == null) return;
                        final file = result.files.single;
                        if (file.path == null) return;
                        setState(() {
                          _pendingImage = File(file.path!);
                          pendingFileName = file.name;
                          _pendingIsPdf =
                              file.extension?.toLowerCase() == 'pdf';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _actionIcon(
                      isRecording ? Icons.stop : Icons.mic,
                      onTap: () async {
                        if (widget.conversationId == null) return;
                        final pro = context.read<ChatPro>();
                        if (isRecording) {
                          final auth = context.read<AuthPro>();
                          if (_recordDuration.inSeconds < 1) {
                            showToast(message: "Message too short");
                            await pro.cancelRecording();
                          } else if (auth.user != null) {
                            await pro.stopRecordingAndSend(
                              conversationId: widget.conversationId!,
                              currentUserId: auth.user!.id,
                            );
                          } else {
                            await pro.cancelRecording();
                          }
                          _stopRecordTimer();
                        } else {
                          await pro.startVoiceRecording();
                          _startRecordTimer();
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _actionIcon(
                      CupertinoIcons.smiley,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xffFFC107),
                          width: 1.5,
                        ),
                      ),
                      child: const TextWidget(
                        text: "+ Project",
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        if (_editingMessage != null) {
                          _onEditSubmit();
                        } else {
                          _sendMessage();
                        }
                      },
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: const BoxDecoration(
                          color: Color(0xffFFC107),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 18, color: Colors.black),
    );
  }

  /* ------------------------------------------------------- */
  /*  SEND MESSAGE & EDIT                                 */
  /* ------------------------------------------------------- */
  void _sendMessage() async {
    if (_isChatDisabled) {
      showToast(message: "Messaging disabled for this chat");
      return;
    }
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    setState(() => _showEmojiPicker = false);
    _focusNode.requestFocus();
    final pro = getChatPro(context);
    final authpro = getAuthPro(context);
    int? conversationId = widget.conversationId;

    // If no conversationId, check existing history or create new
    if (conversationId == null) {
      conversationId = pro.findPrivateConversationWithUser(
        widget.receiverUserId,
      );
      if (conversationId == null) {
        conversationId = await pro.createConvId(
          type: 'private',
          userIds: [widget.receiverUserId],
          context: context,
        );
        if (conversationId != null) {
          await pro.initConversationSocket(
            conversationId: conversationId,
            currentUserId: authpro.user!.id,
          );
        }
      }
    }

    if (conversationId == null) return;

    _messageCtrl.clear();
    await pro.sendMessage(
      text: text,
      conversationId: conversationId,
      currentUserId: authpro.user!.id,
    );

    _initScrollToBottom();
  }

  Future<void> _initScrollToBottom() async {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.decelerate,
    );
  }

  void _onEditSubmit() async {
    if (_isChatDisabled) {
      showToast(message: "Messaging disabled for this chat");
      return;
    }
    if (_editingMessage == null) return;
    final newText = _messageCtrl.text.trim();
    if (newText.isEmpty) return;

    final msgId = _editingMessage!.id;
    await context.read<ChatPro>().editMessage(
      messageId: msgId,
      newMessage: newText,
    );
    _cancelEditing();
  }

  Future<dynamic> _openRightSideSheet(
    BuildContext context,
    Widget child, {
    bool fullHeight = false,
    double? height,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RightSideSheet",
      barrierColor: Colors.black.withValues(alpha: .25),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) {
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight =
            height ?? (fullHeight ? screenHeight : screenHeight * 0.6);
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              height: sheetHeight,
              margin: fullHeight
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(top: 60, right: 0),
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
                borderRadius: BorderRadius.circular(24),
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6, right: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: const [
            TextWidget(
              text: "Typing...",
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deletedChatBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff9f9f9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.block, color: Colors.redAccent),
            Spacers.sbw12(),
            const Expanded(
              child: TextWidget(
                text:
                    "This user was deleted. You can view history but cannot send messages.",
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForwardPopup(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardMessageSheet(messageToForward: msg),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: (query) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 500),
                    () {
                      if (widget.conversationId != null) {
                        final authPro = getAuthPro(context);
                        getChatPro(context).searchMessages(
                          conversationId: widget.conversationId.toString(),
                          query: query,
                          currentUserId: authPro.user!.id,
                        );
                      }
                    },
                  );
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            getChatPro(context).clearSearch();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Consumer<ChatPro>(
            builder: (context, pro, _) {
              if (!pro.isSearching || pro.searchTotalResults == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextWidget(
                    text: '${pro.searchTotalResults}',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
