import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/screens/call_screen.dart' as cs;
import 'package:print_helper/services/call_device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'package:print_helper/services/api_routes.dart';
import 'components/tab_group_info.dart';
import 'components/tab_private_chat_info.dart';
import 'components/tab_mesg_forward_sheet.dart';
import 'components/tab_voice_mesg_bubble.dart';
import 'components/tab_video_mesg_bubble.dart';
import 'components/tab_cloud_files_picker_dialog.dart';
import 'groupchat/tab_edit_group.dart';
import 'components/tab_dialpad_dialog.dart';

enum _DuplicateAttachmentAction { reshare, rename, cancel }

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
  bool _pendingDuplicateChecked = false;
  int? _pendingDuplicateConversationId;
  ChatDuplicateFileCheckResult? _pendingDuplicateResult;
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
  final LayerLink _attachmentLayerLink = LayerLink();
  bool _showAttachmentMenu = false;

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

      if (widget.conversationId == null) {
        pro.fetchUserProfile(widget.receiverUserId.toString());
        return;
      }
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
      _clearPendingAttachmentMeta();
      _pendingImage = null;
      pendingFileName = null;
      _pendingIsPdf = false;

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

  void _clearPendingAttachmentMeta() {
    _pendingDuplicateChecked = false;
    _pendingDuplicateConversationId = null;
    _pendingDuplicateResult = null;
  }

  int? _resolveConversationForDuplicateCheck(ChatPro pro) {
    if (widget.conversationId != null && widget.conversationId! > 0) {
      return widget.conversationId;
    }
    final existingId = pro.findPrivateConversationWithUser(
      widget.receiverUserId,
    );
    if (existingId != null && existingId > 0) {
      return existingId;
    }
    return null;
  }

  Future<void> _runDuplicateCheckOnPickedAttachment({
    required File file,
    required String fileName,
  }) async {
    debugPrint(
      '🧪 [PICK] duplicate-check start | file=$fileName path=${file.path}',
    );
    final pro = getChatPro(context);
    final conversationId = _resolveConversationForDuplicateCheck(pro);
    if (conversationId == null) {
      debugPrint(
        '🧪 [PICK] duplicate-check skipped | reason=no-conversation-id',
      );
      if (!mounted) return;
      setState(() {
        _clearPendingAttachmentMeta();
      });
      return;
    }

    debugPrint(
      '🧪 [PICK] duplicate-check call | conversationId=$conversationId file=$fileName',
    );

    Loaders.show();
    final duplicateResult = await pro.checkExistingAttachment(
      file: file,
      conversationId: conversationId,
    );
    Loaders.hide();

    debugPrint(
      '🧪 [PICK] duplicate-check result | null=${duplicateResult == null} hasDuplicates=${duplicateResult?.hasDuplicates} matches=${duplicateResult?.matches.length ?? 0}',
    );

    if (!mounted) return;

    setState(() {
      _pendingDuplicateChecked = duplicateResult != null;
      _pendingDuplicateConversationId = conversationId;
      _pendingDuplicateResult = duplicateResult;
    });

    if (duplicateResult == null || !duplicateResult.hasDuplicates) {
      debugPrint('🧪 [PICK] no duplicates found');
    } else {
      debugPrint(
        '🧪 [PICK] duplicates cached | matches=${duplicateResult.matches.length}',
      );
    }
  }

  // Removed _showAttachmentOptions as it is replaced by _buildAttachmentMenu

  Future<void> _pickFileFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null || file.path!.isEmpty) return;

    final selectedFile = File(file.path!);
    setState(() {
      _pendingImage = selectedFile;
      pendingFileName = file.name;
      _pendingIsPdf = file.extension?.toLowerCase() == 'pdf';
      _clearPendingAttachmentMeta();
    });

    await _runDuplicateCheckOnPickedAttachment(
      file: selectedFile,
      fileName: file.name,
    );
  }

  void _showCloudFilesPicker() {
    showDialog(
      context: context,
      builder: (_) => TabCloudFilesPickerDialog(
        conversationId: widget.conversationId,
        receiverUserId: widget.receiverUserId,
      ),
    );
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

  bool _isGranted(dynamic result) => result is bool ? result : true;

  Future<bool> _ensureCallPermissions() async {
    try {
      if (Platform.isAndroid) {
        await Permission.bluetoothConnect.request();
      }
      final readNumbers = await TwilioVoice.instance
          .requestReadPhoneNumbersPermission();
      final readState = await TwilioVoice.instance
          .requestReadPhoneStatePermission();
      final callPhone = await TwilioVoice.instance.requestCallPhonePermission();
      final mic = await TwilioVoice.instance.requestMicAccess();

      final granted =
          _isGranted(readNumbers) &&
          _isGranted(readState) &&
          _isGranted(callPhone) &&
          _isGranted(mic);

      if (!granted) {
        showToast(message: "Call permissions are required");
      }
      return granted;
    } catch (_) {
      showToast(message: "Unable to request call permissions");
      return false;
    }
  }

  Future<bool> _ensureTwilioTokens() async {
    final chatPro = getChatPro(context);
    final accessToken = await chatPro.getTwilioAccessToken(forceRefresh: true);
    if (accessToken == null || accessToken.isEmpty) {
      showToast(message: "Twilio access token is missing");
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceToken = prefs.getString("fcm_token");
    if (deviceToken == null || deviceToken.isEmpty) {
      // Token missing from prefs — recover directly from Firebase and cache it
      try {
        deviceToken = await FirebaseMessaging.instance.getToken();
        if (deviceToken != null && deviceToken.isNotEmpty) {
          await prefs.setString("fcm_token", deviceToken);
        }
      } catch (_) {}
    }
    if (deviceToken == null || deviceToken.isEmpty) {
      showToast(message: "FCM device token is missing");
      return false;
    }

    try {
      await TwilioVoice.instance.setTokens(
        accessToken: accessToken,
        deviceToken: deviceToken,
      );
      return true;
    } catch (_) {
      showToast(message: "Failed to register Twilio tokens");
      return false;
    }
  }

  Future<void> _placeVoiceCall({
    String? fromNumber,
    String? toNumber,
    bool isInternal = false,
    int? targetUserId,
  }) async {
    if (!CallDeviceService.callEnabled) {
      showToast(message: "Call feature is disabled in this build");
      return;
    }

    final hasPermissions = await _ensureCallPermissions();
    if (!hasPermissions) return;

    final hasTokens = await _ensureTwilioTokens();
    if (!hasTokens || !mounted) return;

    if (toNumber == null || toNumber.isEmpty) {
      showToast(message: "Phone number is required to place a call.");
      return;
    }

    final String? finalToUserId = targetUserId?.toString();
    final success = await CallDeviceService.placeExternalCall(
      toNumber: toNumber,
      conversationId:
          (widget.conversationId != null && widget.conversationId! > 0)
          ? widget.conversationId
          : null,
      record: true,
      toUserId: finalToUserId,
      fromNumber: fromNumber,
    );

    if (!mounted) return;

    if (success) {
      if (CallDeviceService.expectingBridgeLeg) {
        showToast(message: "Connecting... Please wait.");
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => cs.CallScreen(
              callerName: toNumber,
              callerNumber: toNumber,
              isIncoming: false,
            ),
          ),
        );
      }
    } else {
      showToast(message: "Failed to place call");
    }
  }

  Future<CallPopupData?> _buildNewCallPopupData() async {
    final pro = getChatPro(context);
    final results = await Future.wait([
      pro.fetchCallFromNumbers(),
      pro.fetchUserTwilioNumbers(widget.receiverUserId),
    ]);

    final fromNumbers = results[0];
    final targetTwilioNumbers = results[1];

    List<CallFromNumber> targetNumbers = [];
    targetNumbers.addAll(targetTwilioNumbers);

    if (pro.userProfile != null) {
      final profile = pro.userProfile!;
      if (profile.phone.isNotEmpty &&
          !targetNumbers.any((n) => n.number == profile.phone)) {
        targetNumbers.add(
          CallFromNumber(
            number: profile.phone,
            label: 'Mobile',
            isTwilio: false,
            type: 'mobile',
          ),
        );
      }
      for (String phone in profile.phones) {
        if (phone.isNotEmpty && !targetNumbers.any((n) => n.number == phone)) {
          targetNumbers.add(
            CallFromNumber(
              number: phone,
              label: 'Other',
              isTwilio: false,
              type: 'other',
            ),
          );
        }
      }
    }

    return CallPopupData(
      conversationId: 0,
      type: 'private',
      callFromNumbers: fromNumbers,
      targets: [
        CallTarget(
          user: CallTargetUser(
            id: widget.receiverUserId,
            name: widget.name,
            isOnline: false,
            image: pro.userProfile?.image,
          ),
          numbers: targetNumbers,
        ),
      ],
    );
  }

  void _showCallFromSheet() {
    String? selectedFromNumber;
    final media = MediaQuery.of(context);
    final rect = RelativeRect.fromLTRB(
      media.size.width - 450,
      kToolbarHeight + media.padding.top + 8,
      16,
      0,
    );

    final Future<CallPopupData?> popupDataFuture =
        widget.conversationId != null && widget.conversationId! > 0
        ? getChatPro(
            context,
            listen: false,
          ).fetchCallPopupData(widget.conversationId!)
        : _buildNewCallPopupData();

    showMenu<void>(
      context: context,
      position: rect,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      constraints: const BoxConstraints(maxWidth: 420, minWidth: 380),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (ctx, setStateSheet) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FutureBuilder<CallPopupData?>(
                  future: popupDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 200,
                        child: Center(child: showLoader()),
                      );
                    }

                    final popupData = snapshot.data;
                    if (popupData == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: TextWidget(
                            text: "Failed to load call data.",
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }

                    final fromNumbers = popupData.callFromNumbers;
                    final targets = popupData.targets;

                    if (selectedFromNumber == null && fromNumbers.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (selectedFromNumber == null) {
                          setStateSheet(
                            () => selectedFromNumber = fromNumbers.first.number,
                          );
                        }
                      });
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ImageWidget(image: Paths.call, width: 18),
                            Spacers.sbw8(),
                            const TextWidget(
                              text: "Start Call",
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                if (selectedFromNumber == null) {
                                  showToast(
                                    message:
                                        "Select a 'Call From' number first",
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                _showDialPad(selectedFromNumber!);
                              },
                              icon: const Icon(
                                Icons.dialpad,
                                size: 20,
                                color: Colors.blue,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                        Spacers.sb5(),
                        const TextWidget(
                          text: "Call From",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        Spacers.sb8(),
                        if (fromNumbers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: TextWidget(
                                text: "No Twilio numbers are assigned to you.",
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          _buildFromDropdown(
                            fromNumbers,
                            selectedFromNumber,
                            (val) =>
                                setStateSheet(() => selectedFromNumber = val),
                          ),
                        if (fromNumbers.isNotEmpty) ...[
                          Spacers.sb12(),
                          const TextWidget(
                            text: "Select a number to call",
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          Spacers.sb8(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: SingleChildScrollView(
                              child: Column(
                                children: targets.map((target) {
                                  return _buildTargetSection(
                                    target: target,
                                    isGroup: popupData.type == 'group',
                                    selectedFromNumber: selectedFromNumber,
                                    onCallPressed:
                                        (toNumber, isInternal, targetUserId) {
                                          if (selectedFromNumber == null ||
                                              selectedFromNumber!.isEmpty) {
                                            showToast(
                                              message:
                                                  "Select a call from number",
                                            );
                                            return;
                                          }
                                          Navigator.pop(context);
                                          _placeVoiceCall(
                                            fromNumber: selectedFromNumber,
                                            toNumber: toNumber,
                                            isInternal: isInternal,
                                            targetUserId: targetUserId,
                                          );
                                        },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDialPad(String fromNumber) {
    showDialog(
      context: context,
      builder: (context) => TabDialPadDialog(
        fromNumber: fromNumber,
        onCall: (toNumber) {
          _placeVoiceCall(fromNumber: fromNumber, toNumber: toNumber);
        },
      ),
    );
  }

  Widget _buildFromDropdown(
    List<CallFromNumber> numbers,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          isDense: true,
          padding: const EdgeInsets.symmetric(vertical: 5),
          icon: const Icon(Icons.arrow_drop_down),
          selectedItemBuilder: (context) {
            return numbers.map((item) {
              final label = (item.context != null && item.context!.isNotEmpty)
                  ? item.context!
                  : item.label.isNotEmpty
                  ? item.label
                  : "Twilio Line";
              return Row(
                children: [
                  _numberLogo(item.logo),
                  Spacers.sbw8(),
                  Expanded(
                    child: TextWidget(
                      text: "$label - ${_formatPhone(item.number)}",
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: numbers.map((item) {
            final contextLabel =
                (item.context != null && item.context!.isNotEmpty)
                ? "${item.context}"
                : "";
            return DropdownMenuItem<String>(
              value: item.number,
              child: Row(
                children: [
                  _numberLogo(item.logo),
                  Spacers.sbw8(),
                  Expanded(
                    child: TextWidget(
                      text: "$contextLabel - ${_formatPhone(item.number)}",
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTargetSection({
    required CallTarget target,
    required bool isGroup,
    required String? selectedFromNumber,
    required void Function(String toNumber, bool isInternal, int targetUserId)
    onCallPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ImageWidget(
              image:
                  (target.user.image != null && target.user.image!.isNotEmpty)
                  ? target.user.image!
                  : Paths.user,
              fit: BoxFit.cover,
              width: 36,
              height: 36,
            ),
          ),
          Spacers.sbw8(),
          SizedBox(
            width: 65,
            child: TextWidget(
              text: target.user.fullName,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacers.sbw8(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: target.numbers.isEmpty
                  ? [
                      TextWidget(
                        text: "No numbers",
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ]
                  : target.numbers.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: () => onCallPressed(
                            item.number,
                            item.isTwilio,
                            target.user.id,
                          ),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.isTwilio)
                                  _numberLogo(item.logo)
                                else
                                  ImageWidget(
                                    image: item.type == 'landline'
                                        ? Paths.landPhone
                                        : item.type == 'mobile'
                                        ? Paths.call2
                                        : Paths.other,
                                    width: 20,
                                    height: 20,
                                  ),
                                Spacers.sbw8(),
                                TextWidget(
                                  text: _formatPhone(item.number),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhone(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.length == 11 && digits.startsWith('1')
        ? digits.substring(1)
        : digits;
    if (local.length == 10) {
      return '(${local.substring(0, 3)}) ${local.substring(3, 6)}-${local.substring(6)}';
    }
    return number;
  }

  Widget _numberLogo(String? logo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: ImageWidget(
        image: (logo != null && logo.isNotEmpty) ? logo : Paths.other,
        fit: BoxFit.cover,
        width: 24,
        height: 24,
      ),
    );
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
                          key: ValueKey('chat_msg_${msg.id}'),
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
          if (_showAttachmentMenu)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showAttachmentMenu = false),
                behavior: HitTestBehavior.translucent,
                child: Container(),
              ),
            ),
          _buildAttachmentMenu(),
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
              Expanded(
                child: GestureDetector(
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
              ),
            ],
          );
        },
      ),
      actions: [
        Consumer<ChatPro>(
          builder: (context, pro, _) {
            if (widget.conversationId != null && widget.conversationId! > 0) {
              final convo = pro.conversations.firstWhere(
                (c) => c.id == widget.conversationId,
                orElse: () => ChatConversation(
                  id: -1,
                  type: 'private',
                  title: '',
                  participants: const [],
                  latestMessage: null,
                  image: '',
                  unreadCount: 0,
                  updatedAt: DateTime.now(),
                  isDefault: true,
                ),
              );
              if (convo.type == 'group') {
                final myId = getAuthPro(context, listen: false).user?.id;
                final me = convo.participants.firstWhere(
                  (p) => p.id == myId,
                  orElse: () => ChatParticipant(
                    name: '',
                    username: '',
                    lastName: '',
                    isOnline: false,
                    phoneNumbers: const [],
                  ),
                );
                if (me.role == 'observer') return const SizedBox.shrink();
              }
            }
            return IconButton(
              icon: Icon(CupertinoIcons.phone),
              onPressed: _showCallFromSheet,
            );
          },
        ),
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

            return IconButton(
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
    if (msg.type == 'call' || msg.type == 'video_call') {
      return _buildCallBubble(msg);
    }

    // Call recording bubble (voice message with is_call_recording)
    if (msg.isCallRecording && msg.audioUrl != null) {
      return _buildCallRecordingBubble(msg);
    }

    // Video message bubble
    if (msg.type == 'video' && msg.videoUrl != null) {
      return _buildVideoBubble(msg);
    }

    // Image / file attachment bubble
    if (msg.type == 'image' || msg.type == 'file') {
      return _attachmentBubble(msg);
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
      children: [
        TextWidget(
          text:
              'App Chat • ${DateFormat('dd/MM/yyyy • hh:mm a').format(msg.createdAt)}',
          fontSize: 10,
          color: const Color(0xff8e8e93),
          fontWeight: FontWeight.w500,
        ),
        if (msg.isMe) ...[
          const SizedBox(width: 4),
          Icon(iconData, size: 14, color: iconColor),
        ],
      ],
    );
  }

  Widget _buildCallBubble(ChatMessage msg) {
    final callOutcome = (msg.callOutcome ?? '').toLowerCase();
    final callStatus = (msg.callStatus ?? '').toLowerCase();
    final messageLower = msg.message.toLowerCase();
    final isDeclined =
        callOutcome == 'rejected' ||
        callStatus == 'canceled' ||
        messageLower.contains('declined');
    final isMissed = msg.isMissedCall == true;
    final isVideoCall = msg.type == 'video_call';

    String callerLabel;
    if (msg.isMe) {
      callerLabel = "You";
    } else {
      callerLabel = msg.senderName ?? 'Unknown';
    }

    final title = isDeclined
        ? msg.message
        : (isMissed
              ? (isVideoCall
                    ? "Missed Video Call From $callerLabel"
                    : "Missed Called From $callerLabel")
              : (isVideoCall
                    ? "Video Call From $callerLabel"
                    : "Called From $callerLabel"));

    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null
        ? _formatPhone(msg.callToNumber!)
        : 'You';
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();

    final bgColor = (isMissed || isDeclined)
        ? const Color(0xffFFDDDD)
        : const Color(0xffD4EDDA);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageWidget(
                image: (isMissed || isDeclined) ? Paths.cross : Paths.call2,
                width: (isMissed || isDeclined) ? 16 : 20,
                height: (isMissed || isDeclined) ? 16 : 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextWidget(
                  text: title,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                TextWidget(
                  text: "From: $from  •  To: $to",
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextWidget(
                    text: dateStr,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Colors.black45,
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

  Widget _buildCallRecordingBubble(ChatMessage msg) {
    final toNames = _toUserNames(msg);
    String title;
    if (msg.isMe) {
      title = "You Called $toNames";
    } else {
      final senderName = msg.senderName ?? 'Unknown';
      title = "$senderName Called You";
    }

    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null
        ? _formatPhone(msg.callToNumber!)
        : 'You';
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          VoiceMessageBubbleUI(
            path: msg.audioUrl!,
            duration: msg.audioDuration ?? 0,
            isMe: msg.isMe,
            isUploading: false,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextWidget(
              text: "From: $from  •  To: $to",
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextWidget(
              text: dateStr,
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  String _toUserNames(ChatMessage msg) {
    if (msg.toUsers != null && msg.toUsers!.isNotEmpty) {
      return msg.toUsers!.map((u) => u['name'] ?? 'Unknown').join(', ');
    }
    return msg.message.replaceAll('Missed Call To ', '');
  }

  /// Video message bubble
  Widget _buildVideoBubble(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 370),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name (group chat)
          if (!msg.isMe && msg.senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextWidget(
                text: msg.senderName!,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

          // Video player
          TabVideoMessageBubbleUI(
            videoUrl: msg.videoUrl!,
            duration: msg.videoDuration,
            isMe: msg.isMe,
            isVideoCallRecording: msg.isVideoCallRecording,
          ),

          const SizedBox(height: 4),
          // Time + ticks
          _metaRow(msg),
        ],
      ),
    );
  }

  Widget _attachmentBubble(ChatMessage msg) {
    final pro = getChatPro(context);
    final localPath = pro.localAttachmentPaths[msg.id];
    final progress = pro.uploadProgress[msg.id];
    final isUploading = progress != null;
    final isImage = _isImageAttachmentMessage(msg);
    final isMovedAttachment = msg.isMoved;
    final resolvedThumbnailUrl =
        (msg.thumbnailUrl != null && msg.thumbnailUrl!.isNotEmpty)
        ? _resolveAttachmentUrl(msg.thumbnailUrl!, cacheBuster: '${msg.id}')
        : null;
    final resolvedRemoteUrl =
        (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty)
        ? _resolveAttachmentUrl(msg.attachmentUrl!, cacheBuster: '${msg.id}')
        : null;

    final rawName =
        (msg.attachmentName != null && msg.attachmentName!.isNotEmpty)
        ? msg.attachmentName!
        : msg.message.replaceAll('📎 ', '');

    Widget previewWidget;
    if (isImage) {
      previewWidget = GestureDetector(
        onTap: () {
          _openImagePreview(initialMessageId: msg.id);
        },
        child: localPath != null
            ? Image.file(
                File(localPath),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              )
            : ImageWidget(
                image:
                    (resolvedThumbnailUrl != null &&
                        resolvedThumbnailUrl.isNotEmpty)
                    ? resolvedThumbnailUrl
                    : (resolvedRemoteUrl ?? ''),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 34,
                  ),
                ),
              ),
      );
    } else {
      previewWidget = Center(
        child: (resolvedThumbnailUrl != null && resolvedThumbnailUrl.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: ImageWidget(
                  image: resolvedThumbnailUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorWidget: _buildDocPreview(rawName, size: 64),
                ),
              )
            : _buildDocPreview(rawName, size: 64),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isMovedAttachment ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMovedAttachment ? Colors.transparent : const Color(0xffe1e1e1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SENDER NAME (ONLY IF NOT ME AND IN GROUP)
          if (!msg.isMe && msg.senderName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: TextWidget(
                text: msg.senderName!,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

          // PREVIEW SECTION
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMovedAttachment)
                  _buildMovedFileBanner(msg: msg, isImage: isImage)
                else
                  Container(
                    width: double.infinity,
                    height: isImage ? 200 : 130,
                    decoration: BoxDecoration(
                      color: const Color(0xfff8f9fa),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xffecedef),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: previewWidget,
                    ),
                  ),
                const SizedBox(height: 12),
                // NAME & EXPIRY SECTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: TextWidget(
                          text: rawName,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isMovedAttachment ? Colors.black87 : const Color(0xff004271),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      if (msg.expiresInDays != null && !msg.isExpired)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [_buildExpiryLabel(msg)],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // PROGRESS
          if (isUploading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // FOOTER
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _metaRow(msg),
          ),
        ],
      ),
    );
  }

  Widget _buildMovedFileBanner({
    required ChatMessage msg,
    required bool isImage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfffdf5e0).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfff8e8c1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File does not exist',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade900,
            ),
          ),
          if (msg.movedByName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Deleted by ${msg.movedByName}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade800.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpiryLabel(ChatMessage msg) {
    if (msg.expiresInDays != null && !msg.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xfffff8c5), // Pill Yellow
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xfff3d670).withOpacity(0.5)),
        ),
        child: TextWidget(
          text: 'Expires in ${msg.expiresInDays!.toStringAsFixed(0)} days',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xff7c5c00), // Darker text
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _resolveAttachmentUrl(String rawUrl, {String? cacheBuster}) {
    String resolvedUrl = rawUrl.trim().replaceAll('`', '').trim();
    if (resolvedUrl.isEmpty) return resolvedUrl;

    if (!resolvedUrl.startsWith('http')) {
      if (!resolvedUrl.startsWith('/')) return resolvedUrl;
      final apiUri = Uri.parse(ApiRoutes.baseUrl);
      final origin = apiUri.hasPort
          ? '${apiUri.scheme}://${apiUri.host}:${apiUri.port}'
          : '${apiUri.scheme}://${apiUri.host}';
      resolvedUrl = '$origin$resolvedUrl';
    }

    if (cacheBuster == null || cacheBuster.isEmpty) {
      return resolvedUrl;
    }
    if (resolvedUrl.contains('?') && resolvedUrl.contains('X-Amz-Signature')) {
      return resolvedUrl;
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme) return resolvedUrl;
    final query = Map<String, String>.from(uri.queryParameters);
    query['cb'] = cacheBuster;
    return uri.replace(queryParameters: query).toString();
  }

  bool _isImageAttachmentMessage(ChatMessage msg) {
    if (msg.type == 'image') return true;
    final mime = (msg.attachmentMimeType ?? '').toLowerCase();
    if (mime.startsWith('image/') || mime.startsWith('images/')) return true;
    final byName = msg.attachmentName ?? '';
    if (_isImageFileName(byName)) return true;
    final byUrl = (msg.attachmentUrl ?? '').toLowerCase();
    return byUrl.endsWith('.jpg') ||
        byUrl.endsWith('.jpeg') ||
        byUrl.endsWith('.png') ||
        byUrl.endsWith('.webp') ||
        byUrl.endsWith('.gif');
  }

  Widget _buildDocPreview(String fileName, {double? size}) {
    final lower = fileName.toLowerCase();
    IconData iconData = Icons.insert_drive_file_rounded;
    Color color = Colors.grey;

    if (lower.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_rounded;
      color = Colors.red.shade700;
    } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      iconData = Icons.description_rounded;
      color = Colors.blue.shade700;
    } else if (lower.endsWith('.txt')) {
      iconData = Icons.text_snippet_rounded;
      color = Colors.grey.shade700;
    } else if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
      iconData = Icons.folder_zip_rounded;
      color = Colors.orange.shade700;
    } else if (lower.endsWith('.psd')) {
      iconData = Icons.image_rounded;
      color = Colors.deepPurple.shade700;
    }

    return Icon(iconData, size: size ?? 48, color: color);
  }

  bool _isImageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Future<void> _openImagePreview({required int initialMessageId}) {
    final pro = context.read<ChatPro>();
    final imageItems = <Map<String, dynamic>>[];

    for (final message in pro.messages) {
      if (!_isImageAttachmentMessage(message)) continue;
      if (message.isMoved) continue;

      final local = pro.localAttachmentPaths[message.id];
      final remote =
          (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
          ? _resolveAttachmentUrl(
              message.attachmentUrl!,
              cacheBuster: '${message.id}',
            )
          : null;

      if ((local == null || local.isEmpty) &&
          (remote == null || remote.isEmpty)) {
        continue;
      }

      imageItems.add({
        'id': message.id,
        'local': local,
        'remote': remote,
        'name': message.attachmentName,
      });
    }

    if (imageItems.isEmpty) return Future.value();

    int currentIndex = imageItems.indexWhere(
      (e) => e['id'] == initialMessageId,
    );
    if (currentIndex < 0) currentIndex = 0;

    final pageController = PageController(initialPage: currentIndex);

    return showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: imageItems.length,
                        onPageChanged: (index) {
                          setStateDialog(() => currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final item = imageItems[index];
                          final String? local = item['local'] as String?;
                          final String? remote = item['remote'] as String?;

                          return Center(
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4,
                              child: (local != null && local.isNotEmpty)
                                  ? Image.file(File(local), fit: BoxFit.contain)
                                  : ImageWidget(
                                      image: remote ?? '',
                                      fit: BoxFit.contain,
                                      showLoad: true,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final item = imageItems[currentIndex];
                            _downloadChatAttachment(
                              localPath: item['local'] as String?,
                              remoteUrl: item['remote'] as String?,
                              fileName: item['name'] as String?,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: TextWidget(
                              text:
                                  '${currentIndex + 1} / ${imageItems.length}',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(ctx),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final auth = context.read<AuthPro>();
    final isAdmin = auth.user?.roleName == 'ADMIN';
    final canEdit = (msg.isMe || isAdmin) && msg.type == 'text';
    final canDelete = msg.isMe || isAdmin;
    final canDownload =
        (msg.type == 'image' || msg.type == 'file') && !msg.isMoved;
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
          case 'download':
            if (msg.isMoved) {
              showToast(message: 'File has been deleted');
              break;
            }
            final localPath = getChatPro(context).localAttachmentPaths[msg.id];
            _downloadChatAttachment(
              localPath: localPath,
              remoteUrl: msg.attachmentUrl,
              fileName: msg.attachmentName,
            );
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
        if (canDownload)
          const PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download, size: 18, color: Colors.black87),
                SizedBox(width: 8),
                TextWidget(
                  text: 'Download',
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

  Future<void> _downloadChatAttachment({
    required String? localPath,
    required String? remoteUrl,
    String? fileName,
  }) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photos = await Permission.photos.request();
          if (!photos.isGranted) {
            showToast(message: "Storage permission denied");
            return;
          }
        }
      }

      Loaders.show();

      Directory saveDir;
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          saveDir = downloadsDir;
        } else {
          saveDir = (await getExternalStorageDirectory())!;
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      String ext = 'jpg';
      if (fileName != null && fileName.contains('.')) {
        ext = fileName.split('.').last;
      } else if (remoteUrl != null) {
        final urlPath = Uri.parse(remoteUrl).path;
        if (urlPath.contains('.')) {
          ext = urlPath.split('.').last.split('?').first;
        }
      }

      final name = 'chat_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savePath = '${saveDir.path}/$name';

      if (localPath != null && localPath.isNotEmpty) {
        await File(localPath).copy(savePath);
      } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
        await Dio().download(remoteUrl, savePath);
      } else {
        Loaders.hide();
        showToast(message: "No file to download");
        return;
      }

      Loaders.hide();
      showToast(message: "File saved to Downloads");
    } catch (_) {
      Loaders.hide();
      showToast(message: "Failed to save file");
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black26, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// EDITING / PENDING ATTACHMENT AREA
              if (_editingMessage != null || _pendingImage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    children: [
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
                              left: BorderSide(
                                color: AppColors.primary,
                                width: 4,
                              ),
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
                                    const SizedBox(height: 2),
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
                      if (_pendingImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Stack(
                            children: [
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                  color: Colors.grey.shade100,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _pendingIsPdf
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.picture_as_pdf,
                                              size: 40,
                                              color: Colors.red,
                                            ),
                                            SizedBox(height: 4),
                                            Text("PDF"),
                                          ],
                                        )
                                      : Image.file(
                                          _pendingImage!,
                                          key: ValueKey(
                                            'pending_img_${_pendingImage!.path}',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _pendingImage = null;
                                      pendingFileName = null;
                                      _pendingIsPdf = false;
                                      _clearPendingAttachmentMeta();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              /// TEXT FIELD AREA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _messageCtrl,
                  focusNode: _focusNode,
                  enabled: !_isChatDisabled,
                  readOnly: _isChatDisabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) {
                    if (_editingMessage != null) {
                      _onEditSubmit();
                    } else {
                      _sendMessage();
                    }
                  },
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = false;
                      _showAttachmentMenu = false;
                    });
                  },
                  onChanged: (text) {
                    if (widget.conversationId == null) return;
                    context.read<ChatPro>().onTextTyping(
                      conversationId: widget.conversationId!,
                      text: text,
                    );
                  },
                  style: const TextStyle(
                    fontFamilyFallback: ['Segoe UI Emoji'],
                  ),
                  decoration: InputDecoration(
                    hintText: isSmsSelected
                        ? "Type your Message....."
                        : "Type your SMS… (Carrier charges may apply)",
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Colors.black12),

              /// ACTION BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    if (isRecording) ...[
                      const SizedBox(width: 4),
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
                      _sendButton(
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
                        isStop: true,
                      ),
                    ] else ...[
                      /// ATTACHMENT (+) BUTTON
                      CompositedTransformTarget(
                        link: _attachmentLayerLink,
                        child: _actionIcon(
                          Icons.add_circle_outline_sharp,
                          onTap: () {
                            setState(() {
                              _showAttachmentMenu = !_showAttachmentMenu;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      /// MIC BUTTON
                      _actionIcon(
                        Icons.mic_none_outlined,
                        onTap: () async {
                          if (widget.conversationId == null) return;
                          final pro = context.read<ChatPro>();
                          await pro.startVoiceRecording();
                          _startRecordTimer();
                        },
                      ),
                      const SizedBox(width: 12),

                      /// SMILEY BUTTON
                      _actionIcon(
                        CupertinoIcons.smiley,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                            _showAttachmentMenu = false;
                          });
                        },
                      ),
                      const SizedBox(width: 14),

                      /// + PROJECT BUTTON
                      GestureDetector(
                        onTap: () {
                          // TODO: Implement project action
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xffFFC107),
                              width: 1.5,
                            ),
                          ),
                          child: const TextWidget(
                            text: "+ Project",
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(
                              0xff003366,
                            ), // Matching mockup text color
                          ),
                        ),
                      ),
                      const Spacer(),

                      /// SEND BUTTON
                      _sendButton(
                        onTap: () {
                          if (_editingMessage != null) {
                            _onEditSubmit();
                          } else {
                            _sendMessage();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendButton({required VoidCallback onTap, bool isStop = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: const BoxDecoration(
          color: Color(0xffFFC107),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isStop ? Icons.stop : Icons.send,
          size: 20,
          color: Colors.white,
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

  Future<void> _onAttachmentTypeSelected(String choice) async {
    if (!mounted) return;
    if (choice == 'cloud') {
      _showCloudFilesPicker();
    } else if (choice == 'device') {
      await _pickFileFromDevice();
    }
  }

  Widget _buildAttachmentMenu() {
    if (!_showAttachmentMenu) return const SizedBox.shrink();
    return Positioned(
      bottom: 80, // Anchored above the input bar
      left: 16,
      child: CompositedTransformFollower(
        link: _attachmentLayerLink,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -10),
        child: Material(
          elevation: 12,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuItem(
                  icon: Icons.cloud,
                  text: "Attach cloud files",
                  onTap: () {
                    setState(() => _showAttachmentMenu = false);
                    _onAttachmentTypeSelected('cloud');
                  },
                ),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                _menuItem(
                  icon: CupertinoIcons.cloud_download,
                  text: "Upload from this device",
                  onTap: () {
                    setState(() => _showAttachmentMenu = false);
                    _onAttachmentTypeSelected('device');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: TextWidget(
                text: text,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
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

    if (_pendingImage != null) {
      final effectiveFileName = pendingFileName?.trim().isNotEmpty == true
          ? pendingFileName!.trim()
          : _extractFileName(_pendingImage!.path);
      final attachmentSent = await _sendAttachmentWithDuplicateCheck(
        file: _pendingImage!,
        fileName: effectiveFileName,
        caption: text,
        conversationId: conversationId,
        currentUserId: authpro.user!.id,
      );

      if (!mounted) return;
      if (attachmentSent) {
        setState(() {
          _pendingImage = null;
          pendingFileName = null;
          _pendingIsPdf = false;
          _clearPendingAttachmentMeta();
        });
        _messageCtrl.clear();
        _initScrollToBottom();
      }
      return;
    }

    _messageCtrl.clear();
    await pro.sendMessage(
      text: text,
      conversationId: conversationId,
      currentUserId: authpro.user!.id,
    );

    _initScrollToBottom();
  }

  Future<bool> _sendAttachmentWithDuplicateCheck({
    required File file,
    required String fileName,
    required String caption,
    required int conversationId,
    required int currentUserId,
  }) async {
    final pro = getChatPro(context);
    ChatDuplicateFileCheckResult? duplicateResult;

    final canUsePrecheckedResult =
        _pendingDuplicateChecked &&
        _pendingDuplicateConversationId == conversationId;

    if (canUsePrecheckedResult) {
      duplicateResult = _pendingDuplicateResult;
    } else {
      Loaders.show();
      duplicateResult = await pro.checkExistingAttachment(
        file: file,
        conversationId: conversationId,
      );
      Loaders.hide();
    }

    if (!mounted) return false;

    if (duplicateResult == null || !duplicateResult.hasDuplicates) {
      return pro.sendAttachmentMessage(
        file: file,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
      );
    }

    final duplicate = duplicateResult.matches.isNotEmpty
        ? duplicateResult.matches.first
        : ChatDuplicateFileMatch(originalName: fileName);
    final renamedFileName = _buildRenamedFileName(
      fileName,
      duplicateResult.matches,
    );

    final action = await _showDuplicateAttachmentSheet(
      originalFileName: fileName,
      duplicateName: duplicate.displayName,
      renamedFileName: renamedFileName,
      canReshare: duplicate.canReshare,
    );

    if (!mounted || action == _DuplicateAttachmentAction.cancel) {
      return false;
    }

    if (action == _DuplicateAttachmentAction.reshare) {
      return pro.reshareDuplicateAttachment(
        match: duplicate,
        originalFile: file,
        alternateFileName: fileName,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
      );
    }

    return pro.sendAttachmentMessage(
      file: file,
      conversationId: conversationId,
      currentUserId: currentUserId,
      caption: caption,
      overrideFileName: renamedFileName,
    );
  }

  Future<_DuplicateAttachmentAction> _showDuplicateAttachmentSheet({
    required String originalFileName,
    required String duplicateName,
    required String renamedFileName,
    required bool canReshare,
  }) async {
    final action = await showModalBottomSheet<_DuplicateAttachmentAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'This file already exists in the chat',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                const SizedBox(height: 8),
                const TextWidget(
                  text:
                      'Choose whether to reshare the older copy or upload this file with a new name.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                const SizedBox(height: 14),
                _duplicateAttachmentInfoRow(
                  label: 'Selected',
                  value: originalFileName,
                ),
                const SizedBox(height: 6),
                _duplicateAttachmentInfoRow(
                  label: 'Existing',
                  value: duplicateName,
                ),
                const SizedBox(height: 18),
                if (canReshare)
                  _duplicateActionTile(
                    title: 'Reshare older file instead',
                    subtitle:
                        'Skip uploading a second copy and send the existing file again.',
                    onTap: () =>
                        Navigator.pop(ctx, _DuplicateAttachmentAction.reshare),
                  ),
                _duplicateActionTile(
                  title: 'Send as $renamedFileName',
                  subtitle:
                      'Upload this file as a renamed copy, similar to image(1).jpg.',
                  onTap: () =>
                      Navigator.pop(ctx, _DuplicateAttachmentAction.rename),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, _DuplicateAttachmentAction.cancel),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return action ?? _DuplicateAttachmentAction.cancel;
  }

  Widget _duplicateAttachmentInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: TextWidget(
            text: label,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black45,
          ),
        ),
        Expanded(
          child: TextWidget(
            text: value,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _duplicateActionTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text: subtitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black45,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildRenamedFileName(
    String originalFileName,
    List<ChatDuplicateFileMatch> matches,
  ) {
    final existingNames = <String>{originalFileName.toLowerCase()};
    for (final match in matches) {
      final existingName = match.displayName.trim();
      if (existingName.isNotEmpty) {
        existingNames.add(existingName.toLowerCase());
      }
    }

    final dotIndex = originalFileName.lastIndexOf('.');
    final baseName = dotIndex > 0
        ? originalFileName.substring(0, dotIndex)
        : originalFileName;
    final extension = dotIndex > 0 ? originalFileName.substring(dotIndex) : '';

    var suffix = 1;
    while (true) {
      final candidate = '$baseName($suffix)$extension';
      if (!existingNames.contains(candidate.toLowerCase())) {
        return candidate;
      }
      suffix++;
    }
  }

  String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : path;
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
