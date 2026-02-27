import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/admin/chat/view/chat_profile.dart';
import 'package:print_helper/admin/chat/view/groupchat/edit_group.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/screens/call_screen.dart' as cs;
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:print_helper/services/call_device_service.dart';

import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../utils/console_util.dart';
import '../models/chat_models.dart';
import '../provider/chat_pro.dart';
import '../../../widgets/loaders.dart';
import '../../../widgets/spacers.dart';
import '../../../widgets/text_widget.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/typing_dots.dart';
import 'components/mesg_forward_sheet.dart';
import 'components/mesg_options_dialog.dart';
import 'components/voice_mesg_bubble.dart';
import 'components/dialpad_dialog.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int receiverUserId;
  final String title;
  const ChatScreen({
    super.key,
    this.conversationId,
    required this.title,
    required this.receiverUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  // double _cancelSliderOffset = 0.0;
  ChatMessage? _editingMessage;
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool isSmsSelected = false;
  String? currentVisibleDate;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchMode = false;
  Timer? _searchDebounce;
  bool _isChatDisabled = false; // True when peer is deleted
  OverlayEntry? _groupOverlay;
  String selectedSmsNumber = "(323) 000-0000";
  final _scrollCtrl = ScrollController();
  static const double _inputAreaHeight = 20;
  late ChatPro _chatPro;
  final List<String> smsNumbers = [
    "(323) 000-0000",
    "(323) 808-4052",
    "(415) 123-4567",
  ];
  void _startEditing(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _messageCtrl.text = msg.message; // Pre-fill input
    });
    // Slight delay to focus input
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  // 3. HELPER TO CANCEL EDITING
  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageCtrl.clear();
    });
    _focusNode.unfocus();
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
    } catch (e) {
      showToast(message: "Unable to request call permissions");
      printData(title: "Call permissions error:", data: e, e: true);
      return false;
    }
  }

  Future<bool> _ensureTwilioTokens() async {
    final chatPro = getChatPro(context);
    // Always force-refresh so we never use an expired token (error 20104)
    final accessToken = await chatPro.getTwilioAccessToken(forceRefresh: true);
    if (accessToken == null || accessToken.isEmpty) {
      showToast(message: "Twilio access token is missing");
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final deviceToken = prefs.getString("fcm_token");
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
    } catch (e) {
      showToast(message: "Failed to register Twilio tokens");
      printData(title: "Twilio setTokens error:", data: e, e: true);
      return false;
    }
  }

  Future<void> _placeVoiceCall({
    String? fromNumber,
    String? toNumber,
    bool isInternal = false,
    int? targetUserId,
  }) async {
    printData(
      title: "_placeVoiceCall - START",
      data:
          "fromNumber: $fromNumber, toNumber: $toNumber, isInternal: $isInternal",
    );
    if (!CallDeviceService.callEnabled) {
      showToast(message: "Call feature is disabled in this build");
      return;
    }
    final hasPermissions = await _ensureCallPermissions();
    if (!hasPermissions) return;
    final hasTokens = await _ensureTwilioTokens();
    if (!hasTokens) return;
    if (!mounted) return;
    // We only use the outbound-voice API for BOTH internal (Twilio-to-Twilio) and external.
    // The only difference is that for external calls, the to_user_id is null.
    if (toNumber == null || toNumber.isEmpty) {
      showToast(message: "Phone number is required to place a call.");
      return;
    }
    final String? finalToUserId = isInternal ? targetUserId?.toString() : null;
    final success = await CallDeviceService.placeExternalCall(
      toNumber: toNumber,
      conversationId: widget.conversationId,
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
      } else {
        printData(
          title: "_placeVoiceCall",
          data: "Direct outbound call started",
        );
      }
    } else {
      showToast(message: "Failed to place call");
    }
  }

  void _showDialPad(String fromNumber) {
    showDialog(
      context: context,
      builder: (context) => DialPadDialog(
        fromNumber: fromNumber,
        onCall: (toNumber) {
          _placeVoiceCall(fromNumber: fromNumber, toNumber: toNumber);
        },
      ),
    );
  }

  Future<CallPopupData?> _buildNewCallPopupData() async {
    final pro = getChatPro(context);

    // Run both API requests at the same time
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
              type: 'mobile',
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
            name: widget.title,
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
      0,
      kToolbarHeight + media.padding.top + 8.h,
      0,
      0,
    );

    // Create the future strictly once before opening the menu
    final Future<CallPopupData?> popupDataFuture = widget.conversationId != null
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
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      constraints: BoxConstraints(
        maxWidth: media.size.width,
        minWidth: media.size.width,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (ctx, setStateSheet) {
              return Container(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: FutureBuilder<CallPopupData?>(
                  future: popupDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 200.h,
                        child: Center(child: showLoader()),
                      );
                    }
                    final popupData = snapshot.data;
                    if (popupData == null) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: const Center(
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

                    // Auto-select the first "from" number
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
                        // ── Header ──
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

                        // ── Call From Dropdown ──
                        Spacers.sb5(),
                        const TextWidget(
                          text: "Call From",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        Spacers.sb8(),
                        if (fromNumbers.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 18.h),
                            child: const Center(
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
                          // ── Target Numbers (scrollable) ──
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 300.h),
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
                                          printData(
                                            title:
                                                "Call from: $selectedFromNumber | Call to: $toNumber",
                                            data:
                                                "Internal: $isInternal | Target: $targetUserId",
                                          );
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

  /// Dropdown for selecting the "Call From" number
  Widget _buildFromDropdown(
    List<CallFromNumber> numbers,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14.r),
          isDense: true,
          padding: EdgeInsets.symmetric(vertical: 5.h),
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

  /// Builds a target section — avatar + name on left, numbers on right
  Widget _buildTargetSection({
    required CallTarget target,
    required bool isGroup,
    required String? selectedFromNumber,
    required void Function(String toNumber, bool isInternal, int targetUserId)
    onCallPressed,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + Name (left side)
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
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
            width: 65.w,
            child: TextWidget(
              text: target.user.fullName,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacers.sbw8(),
          // Number pills (right side)
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
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: GestureDetector(
                          onTap: () => onCallPressed(
                            item.number,
                            item.isTwilio,
                            target.user.id,
                          ),
                          child: Container(
                            width: 200,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10.r),
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

  /// Formats a phone number to (XXX) XXX-XXXX
  String _formatPhone(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    // Handle 11-digit with leading 1
    final local = digits.length == 11 && digits.startsWith('1')
        ? digits.substring(1)
        : digits;
    if (local.length == 10) {
      return '(${local.substring(0, 3)}) ${local.substring(3, 6)}-${local.substring(6)}';
    }
    return number; // Return as-is if not a standard US number
  }

  /// Circular logo widget for a number
  Widget _numberLogo(String? logo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.r),
      child: ImageWidget(
        image: (logo != null && logo.isNotEmpty) ? logo : Paths.other,
        fit: BoxFit.cover,
        width: 24,
        height: 24,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pro = getChatPro(context);
      final authpro = getAuthPro(context);
      pro.isChatScreenOpen = true;
      pro.reset();
      // NEW CHAT (no conversation yet)
      if (widget.conversationId == null) {
        pro.fetchUserProfile(widget.receiverUserId.toString());
        return; // Do NOT fetch messages or init socket
      }
      // Fetch user profile for online/last seen status
      final convo = pro.conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ChatConversation(
          id: -1,
          type: 'private',
          title: widget.title,
          participants: [],
          latestMessage: null,
          image: '',
          unreadCount: 0,
          updatedAt: DateTime.now(),
          isDefault: true,
        ),
      );

      if (convo.type == 'private' && convo.participants.isNotEmpty) {
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
      // Ensure we are at 0 (bottom) before adding listener
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0.0);
      }
      // Fetch initial data
      await _getChatMessages(pro, authpro);
      // Add listener AFTER initial fetch to prevent premature triggers
      _scrollCtrl.addListener(_onScroll);
      await pro.initConversationSocket(
        conversationId: widget.conversationId!,
        currentUserId: authpro.user!.id,
      );
    });
  }

  Future<void> _getChatMessages(ChatPro pro, AuthPro authpro) async {
    await pro.fetchMessages(
      conversationId: widget.conversationId.toString(),
      currentUserId: authpro.user!.id,
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 100) {
      final pro = getChatPro(context);
      final auth = getAuthPro(context);
      // For reverse list, first visible item = messages[0]
      final firstMsg = pro.messages.isNotEmpty ? pro.messages[0] : null;
      if (firstMsg != null) {
        final label = chatDateLabel(firstMsg.createdAt);
        if (label != currentVisibleDate) {
          setState(() {
            currentVisibleDate = label;
          });
        }
      }
      if (!pro.isLoadingMore && pro.hasMore) {
        pro.fetchMessages(
          conversationId: widget.conversationId.toString(),
          currentUserId: auth.user!.id,
          loadMore: true,
        );
      }
    }
  }

  Future<void> _initScrollToBottom() async {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.decelerate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save the provider reference without listening
    _chatPro = Provider.of<ChatPro>(context, listen: false);
  }

  @override
  void dispose() {
    // 3. Use the SAVED reference (_chatPro), NOT context
    // _chatPro.disconnectConversationSocket();
    if (widget.conversationId != null) {
      _chatPro.disconnectConversationSocket();
    }
    _chatPro.isChatScreenOpen = false;

    // Clear search after frame to avoid notifyListeners during dispose
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

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordDuration = Duration.zero;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted)
        setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    if (mounted) {
      setState(() {
        _recordDuration = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ImageWidget(image: Paths.chtbg, fit: BoxFit.cover),
        ),
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          appBar: _appBar(context),
          body: Consumer<ChatPro>(
            builder: (context, pro, _) {
              return Column(
                children: [
                  // Search bar
                  if (_isSearchMode) _buildSearchBar(context),
                  Expanded(
                    child: Consumer<ChatPro>(
                      builder: (context, pro, _) {
                        final loadMore = pro.isLoadingMore;
                        final displayMessages = _isSearchMode && pro.isSearching
                            ? pro.messageSearchResults
                            : pro.messages;
                        final isSearchView = _isSearchMode && pro.isSearching;

                        return ListView.builder(
                          controller: _scrollCtrl,
                          reverse: !isSearchView,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            12.w,
                            12.w,
                            12.w,
                            _inputAreaHeight +
                                MediaQuery.of(context).viewInsets.bottom +
                                2,
                          ),
                          itemCount:
                              displayMessages.length +
                              (loadMore && !isSearchView ? 1 : 0),
                          itemBuilder: (context, index) {
                            /// 🔄 Loader appears at TOP (because reverse = true)
                            if (loadMore &&
                                !isSearchView &&
                                index == displayMessages.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Center(child: showLoader()),
                              );
                            }
                            if (index >= displayMessages.length) {
                              return const SizedBox.shrink();
                            }
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
                                      ? pro.searchQuery
                                      : null,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Consumer<ChatPro>(
                builder: (context, pro, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pro.isOtherUserTyping)
                        Padding(
                          padding: EdgeInsets.only(left: 12.w, bottom: 6.h),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                TextWidget(
                                  text: "Typing",
                                  textAlign: TextAlign.center,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                TypingBubbleWave(),
                              ],
                            ),
                          ),
                        ),
                      // _channelSelector(),
                      _inputBar(),
                      if (_showEmojiPicker)
                        SizedBox(
                          height: 280,
                          child: EmojiPicker(
                            onEmojiSelected: (category, emoji) {
                              _messageCtrl.text += emoji.emoji;
                              _messageCtrl
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _messageCtrl.text.length),
                              );
                            },
                            config: Config(
                              height: 280,
                              emojiViewConfig: EmojiViewConfig(
                                emojiSizeMax: 28,
                              ),
                              skinToneConfig: SkinToneConfig(),
                              categoryViewConfig: CategoryViewConfig(
                                indicatorColor: const Color(0xffFFC107),
                                iconColor: Colors.grey,
                                iconColorSelected: const Color(0xffFFC107),
                              ),
                              bottomActionBarConfig: BottomActionBarConfig(
                                enabled: false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateHeader(DateTime dt) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: TextWidget(
            text: chatDateLabel(dt),
            color: Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    if (_isChatDisabled) return _deletedChatBanner();

    final isRecording = context.watch<ChatPro>().isRecordingVoice;
    return SafeArea(
      minimum: EdgeInsets.only(bottom: 10.h),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
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
                  if (_editingMessage != null) _editingBanner(),
                  TextField(
                    controller: _messageCtrl,
                    focusNode: _focusNode,
                    enabled: !_isChatDisabled,
                    readOnly: _isChatDisabled,
                    minLines: 1,
                    maxLines: 4,
                    onTap: () {
                      setState(() => _showEmojiPicker = false);
                    },
                    onChanged: (text) {
                      if (widget.conversationId == null) return;
                      context.read<ChatPro>().onTextTyping(
                        conversationId: widget.conversationId!,
                        text: text,
                      );
                    },
                    decoration: InputDecoration(
                      hintText: isSmsSelected
                          ? "Type your SMS… (Carrier charges may apply)"
                          : "Type your Message",
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
                  const SizedBox(height: 8),
                  inputKeys(isRecording),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editingBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
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
            child: Icon(Icons.close, size: 18.sp),
          ),
        ],
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
            Expanded(
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

  Row inputKeys(bool isRecording) {
    return Row(
      children: [
        if (isRecording)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          )
        else
          _actionIcon(icon: Icons.add_circle_outline_sharp, onTap: () {}),
        Spacers.sbw12(),
        GestureDetector(
          key: const ValueKey('mic_btn'),
          onTap: () {
            if (_isChatDisabled) return;
            if (widget.conversationId == null) return;

            final pro = context.read<ChatPro>();
            final auth = context.read<AuthPro>();

            if (isRecording) {
              // If it's already recording, tapping the mic again will send it
              if (_recordDuration.inSeconds < 1) {
                showToast(message: "Message too short");
                pro.cancelRecording();
              } else if (auth.user != null) {
                pro.stopRecordingAndSend(
                  conversationId: widget.conversationId!,
                  currentUserId: auth.user!.id,
                );
              } else {
                pro.cancelRecording();
              }
              _stopRecordTimer();
            } else {
              // If not recording, tapping the mic starts it
              pro.startVoiceRecording();
              _startRecordTimer();
            }
          },
          child: AnimatedScale(
            scale: isRecording ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              color: isRecording ? Colors.red : Colors.black,
              size: 24, // Original size
            ),
          ),
        ),
        Spacers.sbw12(),
        if (isRecording)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<ChatPro>().cancelRecording();
                    _stopRecordTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TextWidget(
                      text: "Cancel",
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacers.sbw8(),
                GestureDetector(
                  onTap: () {
                    final pro = context.read<ChatPro>();
                    final auth = context.read<AuthPro>();
                    if (_recordDuration.inSeconds < 1) {
                      showToast(message: "Message too short");
                      pro.cancelRecording();
                    } else if (widget.conversationId != null &&
                        auth.user != null) {
                      pro.stopRecordingAndSend(
                        conversationId: widget.conversationId!,
                        currentUserId: auth.user!.id,
                      );
                    } else {
                      pro.cancelRecording();
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
                      Icons.send,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _actionIcon(
            icon: CupertinoIcons.smiley,
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
              });
            },
          ),
          Spacers.sbw12(),
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffFFC107), width: 1.5),
            ),
            child: const Text(
              "+ Project",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (_editingMessage != null) {
                _onEditSubmit();
              } else {
                _onSendPressed();
              }
            },
            child: Container(
              height: 35,
              width: 35,
              decoration: const BoxDecoration(
                color: Color(0xffFFC107),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, size: 20, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onEditSubmit() async {
    if (_isChatDisabled) {
      showToast(message: "Messaging disabled for this chat");
      return;
    }
    final newText = _messageCtrl.text.trim();
    if (newText.isEmpty || _editingMessage == null) return;
    final msgId = _editingMessage!.id;
    await context.read<ChatPro>().editMessage(
      messageId: msgId,
      newMessage: newText,
    );
    _cancelEditing();
  }

  // void _onSendPressed() async {
  //   final text = _messageCtrl.text.trim();
  //   if (text.isEmpty) return;
  //   setState(() => _showEmojiPicker = false);
  //   _focusNode.requestFocus();
  //   final pro = getChatPro(context);
  //   final authpro = getAuthPro(context);
  //   int? conversationId = widget.conversationId;
  //   // STEP 1: If no conversationId yet, check existing history
  //   // if conversationId == null
  //   conversationId ??= pro.findPrivateConversationWithUser(
  //     widget.receiverUserId,
  //   );
  //   // STEP 2: Still no conversation → create it
  //   if (conversationId == null) {
  //     conversationId = await pro.createConvId(
  //       type: 'private', // for non group
  //       userIds: [widget.receiverUserId],
  //       context: context,
  //     );
  //     if (conversationId == null) return;
  //   }
  //   _messageCtrl.clear();
  //   // STEP 3: Send message (ONLY ONCE)
  //   await pro.sendMessage(
  //     text: text,
  //     conversationId: conversationId,
  //     currentUserId: authpro.user!.id,
  //   );
  //   _initScrollToBottom();
  // }

  void _onSendPressed() async {
    if (_isChatDisabled) {
      showToast(message: "Messaging disabled for this chat");
      return;
    }
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _showEmojiPicker = false);
    _focusNode.requestFocus();
    final pro = getChatPro(context);
    final authpro = getAuthPro(context);
    int? conversationId = widget.conversationId;
    // STEP 1: If no conversationId yet, check existing history or create new
    if (conversationId == null) {
      conversationId = pro.findPrivateConversationWithUser(
        widget.receiverUserId,
      );
      // Still no conversation → create it
      if (conversationId == null) {
        conversationId = await pro.createConvId(
          type: 'private',
          userIds: [widget.receiverUserId],
          context: context,
        );
        // IMPORTANT: If we just created the ID, we MUST initialize the socket!
        // This sets 'currentActiveConversationId' in the provider
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
    // STEP 2: Send message (Now safe because socket is initialized)
    await pro.sendMessage(
      text: text,
      conversationId: conversationId,
      currentUserId: authpro.user!.id,
    );
    _initScrollToBottom();
  }

  Widget channelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => isSmsSelected = false);
          },
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            decoration: BoxDecoration(
              color: !isSmsSelected ? Color(0xff231f20) : Color(0xffd1d3d4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Center(
              child: TextWidget(
                text: "App Chat",
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
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
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: isSmsSelected ? Color(0xff231f20) : Color(0xffd1d3d4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
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
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9.r),
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
                        image: Paths.down,
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

  Widget _actionIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 20.sp, color: Colors.black),
    );
  }

  String _appBarSubtitle(BuildContext context) {
    final pro = getChatPro(context);
    final convo = pro.conversations.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => ChatConversation(
        id: -1,
        type: 'private',
        title: widget.title,
        participants: [],
        latestMessage: null,
        image: '',
        unreadCount: 0,
        updatedAt: DateTime.now(),
        isDefault: true,
      ),
    );
    if (convo.type == 'group') {
      return "${convo.participants.length} members";
    }

    // Show online/last seen for private chat
    if (pro.userProfile != null) {
      if (pro.userProfile!.isOnline) {
        return "Online";
      } else if (pro.userProfile!.lastSeenAt != null) {
        final lastSeen = DateTime.tryParse(pro.userProfile!.lastSeenAt!);
        if (lastSeen != null) {
          final now = DateTime.now();
          final diff = now.difference(lastSeen);

          if (diff.inMinutes < 1) {
            return "Last seen just now";
          } else if (diff.inMinutes < 60) {
            return "Last seen ${diff.inMinutes}m ago";
          } else if (diff.inHours < 24) {
            return "Last seen ${diff.inHours}h ago";
          } else if (diff.inDays < 7) {
            return "Last seen ${diff.inDays}d ago";
          } else {
            return "Last seen ${DateFormat('MMM dd').format(lastSeen)}";
          }
        }
      }
    }

    return "New chat";
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.black,
          size: 25,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () {
          if (widget.conversationId == null) return;
          final convo = getChatPro(
            context,
          ).conversations.firstWhere((c) => c.id == widget.conversationId);
          // final convo = getChatPro(
          //   context,
          // ).conversations.firstWhere((c) => c.id == widget.conversationId);
          if (convo.type == 'group') {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black.withValues(alpha: .25),
              builder: (_) => FractionallySizedBox(
                heightFactor: .98,
                child: EditChatGroup(conversationId: convo.id),
              ),
            ).then((_) {
              if (mounted) {
                getChatPro(
                  context,
                  listen: false,
                ).getGroupDetails(widget.conversationId!);
              }
            });
          } else {
            navTo(
              context: context,
              page: ProfileDetails(
                id: convo.participants[0].id.toString(),
                conversationId: widget.conversationId,
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer<ChatPro>(
              builder: (context, pro, _) {
                // NEW CHAT SAFE HANDLING
                if (widget.conversationId == null) {
                  return TextWidget(
                    text: widget.title,
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  );
                }
                final convo = pro.conversations.firstWhere(
                  (c) => c.id == widget.conversationId,
                  orElse: () => ChatConversation(
                    id: -1, // ✅ SAFE
                    type: 'private',
                    title: widget.title,
                    participants: const [],
                    latestMessage: null,
                    image: '',
                    unreadCount: 0,
                    updatedAt: DateTime.now(),
                    isDefault: true,
                  ),
                );

                return TextWidget(
                  text: convo.title,
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              },
            ),

            Spacers.sb2(),
            Consumer<ChatPro>(
              builder: (context, _, _) {
                return TextWidget(
                  text: _appBarSubtitle(context),
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: ImageIcon(
            AssetImage(Paths.vc),
            color: AppColors.black,
            size: 30,
          ),
          onPressed: () {},
        ),

        IconButton(
          icon: ImageIcon(
            AssetImage(Paths.call),
            color: AppColors.black,
            size: 20,
          ),
          onPressed: _showCallFromSheet,
        ),
        _groupInfoAction(),
        IconButton(
          icon: Icon(
            _isSearchMode ? CupertinoIcons.search : CupertinoIcons.search,
            color: AppColors.black.withValues(alpha: 0.8),
            size: 25,
            weight: 400,
          ),
          onPressed: () {
            setState(() {
              _isSearchMode = !_isSearchMode;
              if (!_isSearchMode) {
                _searchCtrl.clear();
                getChatPro(context).clearSearch();
              } else {
                // Focus search field when opening
                Future.delayed(Duration(milliseconds: 100), () {
                  _searchFocusNode.requestFocus();
                });
              }
            });
          },
        ),
        Spacers.sbw5(),
      ],
    );
  }

  Widget _groupInfoAction() {
    if (widget.conversationId == null) return const SizedBox.shrink();
    return Consumer<ChatPro>(
      builder: (context, pro, _) {
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
        if (convo.type != 'group') return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.info_outline, size: 29),
          onPressed: () => _showGroupInfoPopup(convo),
        );
      },
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
              padding: EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50.r),
                child: ImageWidget(
                  image: msg.senderAvatar != null
                      ? msg.senderAvatar!
                      : Paths.user,
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
          Builder(
            builder: (iconCtx) {
              return GestureDetector(
                onTap: () {
                  final RenderBox box = iconCtx.findRenderObject() as RenderBox;
                  final Offset pos = box.localToGlobal(Offset.zero);
                  final Size size = box.size;
                  showMessageOptionsDialog(
                    context: context,
                    position: pos,
                    size: size,
                    msg: msg,
                    onEdit: () {
                      _startEditing(msg);
                    },
                    onForward: () {
                      _showForwardPopup(msg);
                    },
                    onDelete: () async {
                      _deletePopup(msg);
                    },
                  );
                },

                child: Container(
                  width: 30.w,
                  height: 30.h,
                  margin: EdgeInsets.only(left: 8.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13.r),
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                  child: Icon(Icons.more_vert, size: 20.sp),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<dynamic> _deletePopup(ChatMessage msg) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: TextWidget(
          text: "Delete Message?",
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        content: TextWidget(
          text: "Are you sure you want to delete this message?",
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: TextWidget(
              text: "Cancel",
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
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
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage msg, {String? highlightQuery}) {
    // ── Call-type message bubble ──
    if (msg.type == 'call') {
      return _callBubble(msg);
    }

    // ── Call recording bubble (voice msg with is_call_recording) ──
    if (msg.isCallRecording && msg.audioUrl != null) {
      return _callRecordingBubble(msg);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name (group chat)
          if (!msg.isMe && msg.senderName != null)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
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
              voiceWaveform: msg.voiceWaveform,
              isUploading:
                  msg.audioUrl!.startsWith('/data') ||
                  msg.audioUrl!.startsWith('file://') ||
                  !msg.audioUrl!.startsWith('http'),
            )
          else
            highlightQuery != null && highlightQuery.isNotEmpty
                ? _buildHighlightedText(msg.message, highlightQuery, msg.isMe)
                : TextWidget(
                    text: msg.message,
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
          SizedBox(height: 4.h),
          // Time + ticks
          _metaRow(msg),
        ],
      ),
    );
  }

  String formatMessageTime(String dateTime) {
    final dt = DateTime.parse(dateTime);
    return DateFormat("dd/MM/yyyy • h:mma").format(dt).toLowerCase();
  }

  /// Special bubble for call-type messages
  Widget _callBubble(ChatMessage msg) {
    final isMissed = msg.isMissedCall == true;
    // Build the title — use user name from message
    String callerLabel;
    if (msg.isMe) {
      callerLabel = "You";
    } else {
      callerLabel = msg.senderName ?? 'Unknown';
    }
    final title = isMissed
        ? "Missed Called From $callerLabel"
        : "Called From $callerLabel";
    // Format phone numbers
    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null ? _formatPhone(msg.callToNumber!) : '—';
    // Date/time
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();
    final bgColor = isMissed
        ? const Color(0xffFFDDDD)
        : const Color(0xffD4EDDA);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageWidget(
                image: isMissed ? Paths.close : Paths.call3,
                width: isMissed ? 18 : 22,
              ),
              SizedBox(width: 6.w),
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
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
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
                SizedBox(height: 3.h),
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

  /// Call recording bubble (voice message with is_call_recording)
  Widget _callRecordingBubble(ChatMessage msg) {
    // Build title based on direction
    final toNames = _toUserNames(msg);
    String title;
    if (msg.isMe) {
      title = "You Called $toNames";
    } else {
      final senderName = msg.senderName ?? 'Unknown';
      title = "$senderName Called You";
    }

    // Format phone numbers
    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null ? _formatPhone(msg.callToNumber!) : '—';

    // Date/time
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (bold italic)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8.h),

          // Audio player
          VoiceMessageBubbleUI(
            path: msg.audioUrl!,
            duration: msg.audioDuration ?? 0,
            isMe: msg.isMe,
            voiceWaveform: msg.voiceWaveform,
            isUploading: false,
          ),

          SizedBox(height: 6.h),

          // From / To line
          TextWidget(
            text: "From: $from  •  To: $to",
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
          SizedBox(height: 2.h),

          // Date row
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

  /// Extracts "to user" names from call attachments
  String _toUserNames(ChatMessage msg) {
    if (msg.toUsers != null && msg.toUsers!.isNotEmpty) {
      return msg.toUsers!.map((u) => u['name'] ?? 'Unknown').join(', ');
    }
    return msg.message.replaceAll('Missed Call To ', '');
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextWidget(
          text: 'APP Chat • ${formatMessageTime(msg.createdAt.toString())}',
          fontSize: 10,
          color: Colors.black54,
          fontWeight: FontWeight.w400,
          overflow: TextOverflow.ellipsis,
        ),
        if (msg.isMe) ...[
          SizedBox(width: 4.w),
          Icon(iconData, size: 14.sp, color: iconColor),
        ],
      ],
    );
  }

  Widget imageMessage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Center(
        child: ImageWidget(
          image: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e",
          height: 160,
          width: 160,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showGroupInfoPopup(ChatConversation convo) {
    if (_groupOverlay != null) return;
    _groupOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _hideGroupInfoPopup,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 5,
              right: 14,
              child: _groupInfoCard(convo),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_groupOverlay!);
  }

  void _hideGroupInfoPopup() {
    _groupOverlay?.remove();
    _groupOverlay = null;
  }

  Widget _groupInfoCard(ChatConversation convo) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              color: Colors.black.withValues(alpha: 0.15),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20.sp),
                      Spacers.sbw5(),
                      TextWidget(
                        text: "Group Info",
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _hideGroupInfoPopup,
                    child: Icon(Icons.close, size: 20.sp),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: convo.participants.length,
              itemBuilder: (_, i) {
                final user = convo.participants[i];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 6.w,
                    horizontal: 16.w,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(50.r),
                        child: ImageWidget(
                          image: user.image != null ? user.image! : Paths.user,
                          height: 35,
                          width: 35,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Spacers.sbw10(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: user.name,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          TextWidget(
                            text: "@${user.username}",
                            color: Colors.grey,
                            fontSize: 12,
                            maxLines: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Spacers.sb10(),
          ],
        ),
      ),
    );
  }

  void _showForwardPopup(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Important for rounded corners
      builder: (_) => ForwardMessageSheet(messageToForward: msg),
    );
  }

  String chatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    // Else: Format like WhatsApp
    return DateFormat("d MMM yyyy").format(dt);
  }

  /// ---------------- SEARCH UI METHODS ----------------
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: (query) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(Duration(milliseconds: 500), () {
                    if (widget.conversationId != null) {
                      final authPro = getAuthPro(context);
                      getChatPro(context).searchMessages(
                        conversationId: widget.conversationId.toString(),
                        query: query,
                        currentUserId: authPro.user!.id,
                      );
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: AppColors.hint, fontSize: 14.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: AppColors.grey,
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 20,
                            color: AppColors.grey,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            getChatPro(context).clearSearch();
                          },
                        )
                      : null,
                ),
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ),
          Consumer<ChatPro>(
            builder: (context, pro, _) {
              if (!pro.isSearching || pro.searchTotalResults == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(left: 12.w),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: TextWidget(
                    text: '${pro.searchTotalResults}',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              );
            },
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
        color: AppColors.black,
        fontWeight: FontWeight.w400,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <TextSpan>[];
    int lastMatchEnd = 0;

    int index = lowerText.indexOf(lowerQuery);
    while (index != -1) {
      // Add text before match
      if (index > lastMatchEnd) {
        matches.add(
          TextSpan(
            text: text.substring(lastMatchEnd, index),
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }

      // Add highlighted match
      matches.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
            backgroundColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
        ),
      );

      lastMatchEnd = index + query.length;
      index = lowerText.indexOf(lowerQuery, lastMatchEnd);
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      matches.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: matches));
  }
}
