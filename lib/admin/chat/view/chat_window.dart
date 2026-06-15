import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/admin/chat/view/chat_profile.dart';
import 'package:print_helper/admin/chat/view/groupchat/edit_group.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/project_pro.dart';
import 'package:print_helper/screens/call_screen.dart' as cs;
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/services/api_routes.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../services/call_device_service.dart';
import 'package:print_helper/models/client_option.dart';
import 'package:print_helper/models/projects_models.dart';
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
import 'components/video_mesg_bubble.dart';
import 'components/dialpad_dialog.dart';
import 'components/cloud_files_picker_sheet.dart';
import 'components/project_chat_pebble.dart';
import 'components/reminder_mesg_bubble.dart';

enum _DuplicateAttachmentAction { reshare, rename, cancel }

enum _DeleteScopeAction { self, everyone, cancel }

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

  /// Returns true if the other participant in this private chat is Admin or Staff.
  bool _isPeerAdminOrStaff(ChatPro chatPro) {
    // Check from conversation participants list
    if (widget.conversationId != null && widget.conversationId! > 0) {
      final convo = chatPro.conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ChatConversation(
          id: -1,
          type: 'private',
          title: '',
          participants: [],
          image: '',
          unreadCount: 0,
          updatedAt: DateTime.now(),
          isDefault: true,
        ),
      );
      if (convo.id != -1 &&
          convo.type == 'private' &&
          convo.participants.isNotEmpty) {
        final peer = convo.participants.firstWhere(
          (p) => p.id == widget.receiverUserId,
          orElse: () => ChatParticipant(
            name: '',
            username: '',
            lastName: '',
            isOnline: false,
            phoneNumbers: [],
          ),
        );
        final pRole = (peer.accountTypeName ?? '').toLowerCase();
        return pRole == 'admin' || pRole == 'staff';
      }
    }
    // Fallback: check fetched user profile (role: 1=admin, 2=staff)
    if (chatPro.userProfile != null &&
        chatPro.userProfile!.id == widget.receiverUserId) {
      return chatPro.userProfile!.role == 1 || chatPro.userProfile!.role == 2;
    }
    return false;
  }

  /// Returns true if the current conversation is an external-number group
  /// (a system-created group for SMS / external phone numbers with 0 members).
  bool _isExternalNumberGroup(ChatPro chatPro) {
    if (widget.conversationId == null || widget.conversationId! <= 0)
      return false;
    final convo = chatPro.conversations.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => ChatConversation(
        id: -1,
        type: 'private',
        title: '',
        participants: [],
        image: '',
        unreadCount: 0,
        updatedAt: DateTime.now(),
        isDefault: true,
      ),
    );
    return convo.id != -1 &&
        convo.type == 'group' &&
        convo.participants.isEmpty;
  }

  bool _pendingDuplicateChecked = false;
  int? _pendingDuplicateConversationId;
  ChatDuplicateFileCheckResult? _pendingDuplicateResult;
  OverlayEntry? _groupOverlay;
  String selectedSmsNumber = "(323) 000-0000";
  String _smsFromNumber = "";
  String _smsToNumber = "";
  final _scrollCtrl = ScrollController();
  static const double _inputAreaHeight = 20;
  late ChatPro _chatPro;
  final List<String> smsNumbers = [
    "(323) 000-0000",
    "(323) 808-4052",
    "(415) 123-4567",
  ];

  // 2. HELPER TO START EDITING
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

  Future<void> runDuplicateCheckOnPickedAttachment({required File file}) async {
    final pro = getChatPro(context);
    final conversationId = _resolveConversationForDuplicateCheck(pro);
    if (conversationId == null) {
      if (!mounted) return;
      setState(() {
        _clearPendingAttachmentMeta();
      });
      return;
    }

    final duplicateResult = await pro.checkExistingAttachment(
      file: file,
      conversationId: conversationId,
    );

    if (!mounted) return;
    setState(() {
      _pendingDuplicateChecked = duplicateResult != null;
      _pendingDuplicateConversationId = conversationId;
      _pendingDuplicateResult = duplicateResult;
    });
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
    String? deviceToken = prefs.getString("fcm_token");
    if (deviceToken == null || deviceToken.isEmpty) {
      // Token missing from prefs — recover directly from Firebase and cache it
      try {
        deviceToken = await FirebaseMessaging.instance.getToken();
        if (deviceToken != null && deviceToken.isNotEmpty) {
          await prefs.setString("fcm_token", deviceToken);
        }
      } catch (e) {
        printData(title: "FCM getToken error:", data: e, e: true);
      }
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
    final String? finalToUserId = targetUserId?.toString();
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

  void _showTextDialPad(String fromNumber) {
    showDialog(
      context: context,
      builder: (context) => DialPadDialog(
        fromNumber: fromNumber,
        isTextMode: true,
        onCall: (_) {},
        onSendText: (toNumber) async {
          final pro = getChatPro(context, listen: false);
          final result = await pro.createTwilioTextTarget(
            toNumber: toNumber,
            fromNumber: fromNumber,
          );

          if (result == null || !mounted) return;

          setState(() {
            isSmsSelected = true;
            selectedSmsNumber = _formatPhone(fromNumber);
            _smsFromNumber = _sanitizeSmsNumber(fromNumber);
            _smsToNumber = _sanitizeSmsNumber(toNumber);
          });
          _focusNode.requestFocus();
          showToast(message: "Text mode enabled for ${_formatPhone(toNumber)}");
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
    bool isTextMode = false;
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 700;
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

    Widget buildPopupContent(StateSetter setStateSheet) {
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
                    ImageWidget(
                      image: isTextMode ? Paths.chat : Paths.call,
                      width: 18,
                    ),
                    Spacers.sbw8(),
                    TextWidget(
                      text: isTextMode ? "Send Text" : "Start Call",
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        if (selectedFromNumber == null) {
                          showToast(
                            message: "Select a 'Call From' number first",
                          );
                          return;
                        }
                        Navigator.pop(context);
                        if (isTextMode) {
                          _showTextDialPad(selectedFromNumber!);
                        } else {
                          _showDialPad(selectedFromNumber!);
                        }
                      },
                      icon: Icon(
                        Icons.dialpad,
                        size: 20,
                        color: isTextMode
                            ? const Color(0xFF1E8E3E)
                            : Colors.blue,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                Spacers.sb8(),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setStateSheet(() => isTextMode = false),
                          child: Container(
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: isTextMode
                                  ? Colors.white
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            alignment: Alignment.center,
                            child: TextWidget(
                              text: "Call",
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isTextMode ? Colors.black87 : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Spacers.sbw8(),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setStateSheet(() => isTextMode = true),
                          child: Container(
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: isTextMode
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            alignment: Alignment.center,
                            child: TextWidget(
                              text: "Text",
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Spacers.sb12(),
                TextWidget(
                  text: isTextMode ? "Text From" : "Call From",
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
                    (val) => setStateSheet(() => selectedFromNumber = val),
                  ),
                if (fromNumbers.isNotEmpty) ...[
                  Spacers.sb12(),
                  TextWidget(
                    text: isTextMode
                        ? "Select a number to text"
                        : "Select a number to call",
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  Spacers.sb8(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: isCompact ? 360.h : 300.h,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: targets.map((target) {
                          return _buildTargetSection(
                            target: target,
                            isGroup: popupData.type == 'group',
                            selectedFromNumber: selectedFromNumber,
                            isTextMode: isTextMode,
                            onCallPressed: (toNumber, isInternal, targetUserId) {
                              if (selectedFromNumber == null ||
                                  selectedFromNumber!.isEmpty) {
                                showToast(message: "Select a call from number");
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
                            onTextPressed: (toNumber, fromNumber, _) async {
                              if (selectedFromNumber == null ||
                                  selectedFromNumber!.isEmpty) {
                                showToast(message: "Select a text from number");
                                return;
                              }

                              final pro = getChatPro(context, listen: false);
                              final result = await pro.createTwilioTextTarget(
                                toNumber: toNumber,
                                fromNumber: selectedFromNumber!,
                              );

                              if (result == null) return;

                              Navigator.pop(context);
                              if (mounted) {
                                setState(() {
                                  isSmsSelected = true;
                                  selectedSmsNumber = _formatPhone(
                                    selectedFromNumber!,
                                  );
                                  _smsFromNumber = _sanitizeSmsNumber(
                                    selectedFromNumber!,
                                  );
                                  _smsToNumber = _sanitizeSmsNumber(toNumber);
                                });
                              }
                              _focusNode.requestFocus();
                              showToast(
                                message:
                                    "Text mode enabled for ${_formatPhone(toNumber)}",
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
    }

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
              return buildPopupContent(setStateSheet);
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
    required bool isTextMode,
    required void Function(String toNumber, bool isInternal, int targetUserId)
    onCallPressed,
    required void Function(String toNumber, bool isInternal, int targetUserId)
    onTextPressed,
  }) {
    String normalizeNumber(String value) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 11 && digits.startsWith('1')) {
        return digits.substring(1);
      }
      return digits;
    }

    final normalizedFrom =
        (selectedFromNumber == null || selectedFromNumber.isEmpty)
        ? ''
        : normalizeNumber(selectedFromNumber);

    final visibleNumbers = target.numbers.where((item) {
      if (!item.isTwilio || normalizedFrom.isEmpty) return true;
      return normalizeNumber(item.number) != normalizedFrom;
    }).toList();

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
              children: visibleNumbers.isEmpty
                  ? [
                      TextWidget(
                        text: "No numbers",
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ]
                  : visibleNumbers.map<Widget>((item) {
                      final isTextSupported = item.number.trim().isNotEmpty;
                      final shouldDisable = isTextMode && !isTextSupported;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: GestureDetector(
                          onTap: shouldDisable
                              ? null
                              : () {
                                  if (isTextMode) {
                                    onTextPressed(
                                      item.number,
                                      item.isTwilio,
                                      target.user.id,
                                    );
                                  } else {
                                    onCallPressed(
                                      item.number,
                                      item.isTwilio,
                                      target.user.id,
                                    );
                                  }
                                },
                          child: Container(
                            width: 200,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: shouldDisable
                                  ? const Color(0xFFEDEDED)
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (shouldDisable)
                                  const Icon(
                                    Icons.block,
                                    size: 18,
                                    color: Color(0xFF9E9E9E),
                                  )
                                else if (isTextMode)
                                  const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Colors.black,
                                  )
                                else if (item.isTwilio)
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
                                  color: shouldDisable
                                      ? const Color(0xFF8C8C8C)
                                      : Colors.black,
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

  String _sanitizeSmsNumber(String input) {
    final trimmed = input.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return trimmed;
    return trimmed.startsWith('+') ? '+$digits' : digits;
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
      if (mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
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
                              key: ValueKey('chat_msg_${msg.id}'),
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
                  if (isSmsSelected &&
                      _smsFromNumber.isNotEmpty &&
                      _smsToNumber.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F0E4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD3B77A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sms_outlined,
                            size: 14,
                            color: Color(0xFF6B3B00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextWidget(
                              text:
                                  "Twilio SMS mode • From $_smsFromNumber • To $_smsToNumber",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B3B00),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isSmsSelected = false;
                                _smsFromNumber = "";
                                _smsToNumber = "";
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4DC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD3B77A),
                                ),
                              ),
                              child: const TextWidget(
                                text: "Back to App Chat",
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B3B00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                          ? "Type your SMS... (Carrier charges may apply)"
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
          _actionIcon(
            icon: Icons.add_circle_outline_sharp,
            onTap: _onAddAttachmentPressed,
          ),
        Spacers.sbw12(),
        if (!isSmsSelected) ...[
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
        ],
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
          if (!isSmsSelected) ...[
            if (!_isPeerAdminOrStaff(context.watch<ChatPro>()) &&
                !_isExternalNumberGroup(context.watch<ChatPro>()))
              GestureDetector(
                onTap: _showCreateProjectPopup,
                child: Container(
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
                  child: const Text(
                    "+ Project",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const Spacer(),
          ] else
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

  Future<void> _showCreateProjectPopup() async {
    final projectPro = context.read<ProjectPro>();
    if (!mounted) return;

    final nameController = TextEditingController();
    int? selectedTemplateId;
    int? selectedClientId;
    String? autoAssignedClientLabel;
    String? autoAssignedClientImage;
    int? selectedCustomerId;
    final excludedStaffIds = <int>[];
    final autoAssignedStaff = <Map<String, String>>[];
    var isSaving = false;
    var isLoading = true;

    String? selectedLabelFrom(
      List<Map<String, String>> options,
      int? selectedId,
    ) {
      if (selectedId == null) return null;
      for (final item in options) {
        if (int.tryParse((item['id'] ?? '').trim()) == selectedId) {
          return item['label'];
        }
      }
      return null;
    }

    String? selectedTemplateLabel() {
      if (selectedTemplateId == null) return null;
      for (final item in projectPro.projectBlueprints) {
        if (item.id == selectedTemplateId) {
          return item.name;
        }
      }
      return null;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Trigger data load on first build
          if (isLoading) {
            Future.microtask(() async {
              await projectPro.getProjectClientOptions();
              await projectPro.getProjectBlueprintLibrary();

              // Fetch client using conversation ID
              if (widget.conversationId != null && widget.conversationId! > 0) {
                await projectPro.getPaginatedProjectClientOptions(
                  refresh: true,
                  conversationId: widget.conversationId,
                );
                final clients = projectPro.paginatedClientOptions;
                if (clients.isNotEmpty) {
                  final client = clients.first;
                  selectedClientId = client.id;
                  autoAssignedClientLabel = client.companyName;
                  autoAssignedClientImage = client.image;

                  autoAssignedStaff.clear();
                  for (var staff in client.assignedStaff) {
                    autoAssignedStaff.add({
                      'id': staff.id?.toString() ?? '',
                      'name': staff.name,
                      'image': staff.image ?? '',
                    });
                  }
                  printData(
                    title: 'ChatScreen _showCreateProjectPopup Loaded Client',
                    data: 'Client: $autoAssignedClientLabel (ID: $selectedClientId), '
                        'Staff assigned count: ${autoAssignedStaff.length}, '
                        'Staff details: $autoAssignedStaff',
                  );
                }
              }

              // Fetch customer options for the selected client if available
              await projectPro.getProjectCustomerOptions(
                forceRefresh: true,
                clientId: selectedClientId,
              );

              if (dialogContext.mounted) {
                setDialogState(() => isLoading = false);
              }
            });
          }

          final customers = projectPro.projectCustomerOptions
              .where((item) => (item['id'] ?? '').trim().isNotEmpty)
              .toList();
          final templateOptions = projectPro.projectBlueprints
              .map((item) => {'id': item.id.toString(), 'label': item.name})
              .toList();
          final filteredCustomers = selectedClientId == null
              ? customers
              : customers.where((item) {
                  final id = int.tryParse((item['client_id'] ?? '').trim());
                  return id == selectedClientId;
                }).toList();
          final assignedStaff = autoAssignedStaff
                  .where(
                    (s) =>
                        !excludedStaffIds.contains(int.tryParse(s['id'] ?? '')),
                  )
                  .toList();

          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F5),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 18.w, 14.h),
                    child: Row(
                      children: [
                        ImageWidget(
                          image: Paths.task,
                          width: 21.w,
                          height: 21.h,
                          color: const Color(0xFF1E232B),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Project',
                            style: TextStyle(
                              fontSize: 31 / 2.2,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF171B23),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: Icon(
                            Icons.close,
                            size: 19.sp,
                            color: const Color(0xFF535964),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: const Color(0xFFDADCE1),
                  ),
                  Flexible(
                    child: Stack(
                      children: [
                        IgnorePointer(
                          ignoring: isLoading,
                          child: Opacity(
                            opacity: isLoading ? 0.4 : 1.0,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  20.w,
                                  16.h,
                                  20.w,
                                  18.h,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPopupFieldLabel('* Project Name'),
                                    SizedBox(height: 7.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 9.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F2F5),
                                        borderRadius: BorderRadius.circular(
                                          14.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD8DAE0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: nameController,
                                        decoration: InputDecoration(
                                          hintText: 'Type Project Name',
                                          hintStyle: TextStyle(
                                            fontSize: 12.sp,
                                            color: const Color(0xFF9BA1AC),
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF242A34),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    _buildPopupFieldLabel(
                                      'Template (optional)',
                                    ),
                                    SizedBox(height: 7.h),
                                    _buildProjectPopupDropdownField(
                                      selectedText: selectedTemplateLabel(),
                                      placeholder: 'Select project template',
                                      options: templateOptions,
                                      onPick: (value) => setDialogState(() {
                                        selectedTemplateId = int.tryParse(
                                          (value['id'] ?? '').trim(),
                                        );
                                      }),
                                    ),
                                    SizedBox(height: 14.h),
                                    _buildPopupFieldLabel('Assigned Client'),
                                    SizedBox(height: 7.h),
                                    _buildAssignedClientPicker(
                                      context: context,
                                      projectPro: projectPro,
                                      conversationId: widget.conversationId,
                                      selectedClientId: selectedClientId,
                                      label: autoAssignedClientLabel,
                                      image: autoAssignedClientImage,
                                      onPick: (client) {
                                        setDialogState(() {
                                          selectedClientId = client.id;
                                          autoAssignedClientLabel = client.companyName;
                                          autoAssignedClientImage = client.image;

                                          // Assign staff automatically
                                          autoAssignedStaff.clear();
                                          for (var staff in client.assignedStaff) {
                                            autoAssignedStaff.add({
                                              'id': staff.id?.toString() ?? '',
                                              'name': staff.name,
                                              'image': staff.image ?? '',
                                            });
                                          }
                                        });

                                        if (client.id != null) {
                                          projectPro.getProjectCustomerOptions(
                                            forceRefresh: true,
                                            clientId: client.id,
                                          ).then((_) {
                                            if (dialogContext.mounted) {
                                              setDialogState(() {});
                                            }
                                          });
                                        }
                                      },
                                    ),
                                    SizedBox(height: 14.h),
                                    _buildPopupFieldLabel(
                                      'Assigned Staff (auto)',
                                    ),
                                    SizedBox(height: 7.h),
                                    _buildAssignedStaffAutoField(
                                      assignedStaff,
                                      onRemove: (id) => setDialogState(() {
                                        if (!excludedStaffIds.contains(id)) {
                                          excludedStaffIds.add(id);
                                        }
                                      }),
                                    ),
                                    SizedBox(height: 14.h),
                                    _buildPopupFieldLabel('Assign Customer'),
                                    SizedBox(height: 7.h),
                                    _buildProjectPopupDropdownField(
                                      selectedText: selectedLabelFrom(
                                        filteredCustomers,
                                        selectedCustomerId,
                                      ),
                                      placeholder: 'Select customer',
                                      options: filteredCustomers,
                                      onPick: (value) => setDialogState(() {
                                        selectedCustomerId = int.tryParse(
                                          (value['id'] ?? '').trim(),
                                        );
                                      }),
                                    ),
                                    SizedBox(height: 18.h),
                                    Center(
                                      child: InkWell(
                                        onTap: isSaving
                                            ? null
                                            : () async {
                                                final projectName =
                                                    nameController.text.trim();
                                                if (projectName.isEmpty) {
                                                  showToast(
                                                    message:
                                                        'Project name is required',
                                                  );
                                                  return;
                                                }
                                                if (selectedClientId == null) {
                                                  showToast(
                                                    message:
                                                        'No client detected for this chat',
                                                  );
                                                  return;
                                                }
                                                if (selectedCustomerId ==
                                                    null) {
                                                  showToast(
                                                    message:
                                                        'Please select a customer',
                                                  );
                                                  return;
                                                }

                                                setDialogState(
                                                  () => isSaving = true,
                                                );
                                                Loaders.show();
                                                final chatPro = context
                                                    .read<ChatPro>();
                                                final conversationId =
                                                    _resolveConversationForDuplicateCheck(
                                                      chatPro,
                                                    );

                                                final created = await projectPro
                                                    .createProjectCoreFields(
                                                      name: projectName,
                                                      clientId:
                                                          selectedClientId!,
                                                      customerId:
                                                          selectedCustomerId!,
                                                      projectBlueprintId:
                                                          selectedTemplateId,
                                                      conversationId:
                                                          conversationId,
                                                      excludedStaffIds:
                                                          excludedStaffIds,
                                                    );
                                                Loaders.hide();

                                                if (!dialogContext.mounted)
                                                  return;
                                                setDialogState(
                                                  () => isSaving = false,
                                                );
                                                if (created) {
                                                  // Close dialog immediately
                                                  if (dialogContext.mounted) {
                                                    Navigator.of(
                                                      dialogContext,
                                                    ).pop();
                                                  }

                                                  // Clear fields
                                                  nameController.clear();
                                                  selectedClientId = null;
                                                  selectedCustomerId = null;
                                                  selectedTemplateId = null;
                                                  excludedStaffIds.clear();

                                                  // Refresh projects in the background
                                                  projectPro.getProjects(
                                                    ctx: context,
                                                  );

                                                  // Also refresh messages of this conversation in real-time
                                                  if (widget.conversationId !=
                                                      null) {
                                                    final auth = context
                                                        .read<AuthPro>();
                                                    if (auth.user != null) {
                                                      chatPro.fetchMessages(
                                                        conversationId: widget
                                                            .conversationId
                                                            .toString(),
                                                        currentUserId:
                                                            auth.user!.id,
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                        child: Container(
                                          width: 180.w,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 24.w,
                                            vertical: 9.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF27C25A),
                                            borderRadius: BorderRadius.circular(
                                              999.r,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            isSaving
                                                ? 'Creating...'
                                                : 'Create New',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isLoading)
                          Positioned.fill(child: Center(child: showLoader())),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // nameController.dispose(); // Removed to fix 'used after disposed' crash during pop animation
  }



  Widget _buildAssignedClientPicker({
    required BuildContext context,
    required ProjectPro projectPro,
    required int? conversationId,
    required int? selectedClientId,
    required String? label,
    required String? image,
    required void Function(ClientOption) onPick,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD8DAE0)),
      ),
      child: Row(
        children: [
          if (image != null && image.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: ImageWidget(
                  image: image,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorWidget: ImageWidget(image: Paths.user, width: 20),
                ),
              ),
            ),
          Expanded(
            child: Text(
              label ?? 'Select client',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: label == null ? const Color(0xFF9BA1AC) : const Color(0xFF191D23),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedStaffAutoField(
    List<Map<String, String>> staff, {
    required void Function(int id) onRemove,
  }) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD8DAE0)),
      ),
      child: staff.isEmpty
          ? Text(
              'No staff assigned',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9BA1AC),
              ),
            )
          : Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final item in staff)
                  Container(
                    padding: EdgeInsets.fromLTRB(8.w, 5.h, 8.w, 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFD9DCE3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE1E4EA),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _staffInitial(item['name'] ?? ''),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C818C),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          item['name'] ?? '',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF525866),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () {
                            final id = int.tryParse(item['id'] ?? '');
                            if (id != null) onRemove(id);
                          },
                          child: ImageWidget(
                            image: Paths.delete,
                            width: 12,
                            height: 12,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _staffInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed[0].toUpperCase();
  }

  Widget _buildPopupFieldLabel(String text) {
    final hasRequired = text.startsWith('*');
    final content = hasRequired ? text.substring(1).trim() : text;
    return RichText(
      text: TextSpan(
        children: [
          if (hasRequired)
            TextSpan(
              text: '* ',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE24A4A),
              ),
            ),
          TextSpan(
            text: content,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF262D37),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectPopupDropdownField({
    required String? selectedText,
    required String placeholder,
    required List<Map<String, String>> options,
    required ValueChanged<Map<String, String>> onPick,
  }) {
    return Builder(
      builder: (pickerContext) => InkWell(
        onTap: () async {
          if (options.isEmpty) return;

          final fieldBox = pickerContext.findRenderObject() as RenderBox;
          final overlayBox =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final fieldTopLeft = fieldBox.localToGlobal(
            Offset.zero,
            ancestor: overlayBox,
          );
          final fieldBottomLeft = fieldBox.localToGlobal(
            Offset(0, fieldBox.size.height),
            ancestor: overlayBox,
          );

          final picked = await showMenu<Map<String, String>>(
            context: context,
            color: Colors.white,
            elevation: 10,
            constraints: BoxConstraints(
              minWidth: fieldBox.size.width,
              maxWidth: fieldBox.size.width,
              maxHeight: 240.h,
            ),
            position: RelativeRect.fromLTRB(
              fieldTopLeft.dx,
              fieldBottomLeft.dy + 2.h,
              overlayBox.size.width - (fieldTopLeft.dx + fieldBox.size.width),
              overlayBox.size.height - fieldBottomLeft.dy,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            items: [
              for (final item in options)
                PopupMenuItem<Map<String, String>>(
                  value: item,
                  height: 38.h,
                  child: Text(
                    (item['label'] ?? '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212834),
                    ),
                  ),
                ),
            ],
          );

          if (picked != null) {
            onPick(picked);
          }
        },
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F2F5),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFD8DAE0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedText == null || selectedText.trim().isEmpty
                      ? placeholder
                      : selectedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: selectedText == null || selectedText.trim().isEmpty
                        ? const Color(0xFF9BA1AC)
                        : const Color(0xFF212834),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_down,
                size: 15.sp,
                color: const Color(0xFF8E95A1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSendPressed() async {
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

    if (isSmsSelected && _smsFromNumber.isNotEmpty && _smsToNumber.isNotEmpty) {
      _messageCtrl.clear();
      final sent = await pro.sendTwilioTextMessage(
        currentUserId: authpro.user!.id,
        toNumber: _smsToNumber,
        fromNumber: _smsFromNumber,
        message: text,
        openedConversationId: widget.conversationId,
      );
      if (sent) {
        _initScrollToBottom();
      }
      return;
    }

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

  void _onAddAttachmentPressed() {
    _showAttachmentOptions();
  }

  Future<void> _showAttachmentOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xffd9d9d9),
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
              SizedBox(height: 18.h),
              Align(
                alignment: Alignment.centerLeft,
                child: TextWidget(
                  text: "Share files",
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              SizedBox(height: 4.h),
              Align(
                alignment: Alignment.centerLeft,
                child: TextWidget(
                  text: "Pick where you want to attach the file from",
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey,
                ),
              ),
              SizedBox(height: 14.h),
              _attachmentOptionTile(
                icon: Icons.cloud_outlined,
                title: "Attach cloud files",
                subtitle: "Browse files already saved in cloud",
                onTap: () => Navigator.pop(ctx, 'cloud'),
              ),
              SizedBox(height: 10.h),
              _attachmentOptionTile(
                icon: Icons.upload_file_outlined,
                title: "Upload from this device",
                subtitle: "Choose a document, image, or spreadsheet",
                onTap: () => Navigator.pop(ctx, 'device'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'cloud') {
      _showCloudFilesPicker();
    } else if (choice == 'device') {
      await _pickFileFromDevice();
    }
  }

  Widget _attachmentOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.fill),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                    SizedBox(height: 2.h),
                    TextWidget(
                      text: subtitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey,
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFileFromDevice() async {
    if (_isChatDisabled) {
      showToast(message: "Messaging disabled for this chat");
      return;
    }
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
    final pickedFile = result.files.single;
    final path = pickedFile.path;
    if (path == null || path.isEmpty) {
      showToast(message: 'Unable to read selected file');
      return;
    }
    final selectedFile = File(path);
    _clearPendingAttachmentMeta();
    await _showAttachmentPreviewSheet(
      file: selectedFile,
      fileName: pickedFile.name,
    );
  }

  void _showCloudFilesPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CloudFilesPickerSheet(
        conversationId: widget.conversationId,
        receiverUserId: widget.receiverUserId,
      ),
    );
  }

  Future<void> _showAttachmentPreviewSheet({
    required File file,
    required String fileName,
  }) async {
    final isImage = _isImageFileName(fileName);
    final captionCtrl = TextEditingController();
    String draftCaption = '';
    final chatPro = getChatPro(context);
    final resolvedConversationId = _resolveConversationForDuplicateCheck(
      chatPro,
    );
    ChatDuplicateFileCheckResult? duplicateResultForSheet =
        (_pendingDuplicateChecked &&
            _pendingDuplicateConversationId == resolvedConversationId)
        ? _pendingDuplicateResult
        : null;
    bool isCheckingDuplicate =
        resolvedConversationId != null && duplicateResultForSheet == null;
    bool didScheduleDuplicateCheck = false;
    bool preferReshareOlder = false;
    bool hasDuplicateNotice = duplicateResultForSheet?.hasDuplicates ?? false;
    ChatDuplicateFileMatch? duplicateMatchPreview =
        hasDuplicateNotice &&
            (duplicateResultForSheet?.matches.isNotEmpty ?? false)
        ? duplicateResultForSheet!.matches.first
        : null;
    String renamedFileNamePreview = _buildRenamedFileName(
      fileName,
      duplicateResultForSheet?.matches ?? const [],
    );

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black87,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isCheckingDuplicate && !didScheduleDuplicateCheck) {
              didScheduleDuplicateCheck = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final result = await chatPro.checkExistingAttachment(
                  file: file,
                  conversationId: resolvedConversationId!,
                );
                if (!mounted || !ctx.mounted) return;
                duplicateResultForSheet = result;
                isCheckingDuplicate = false;
                hasDuplicateNotice =
                    duplicateResultForSheet?.hasDuplicates ?? false;
                duplicateMatchPreview =
                    hasDuplicateNotice &&
                        (duplicateResultForSheet?.matches.isNotEmpty ?? false)
                    ? duplicateResultForSheet!.matches.first
                    : null;
                renamedFileNamePreview = _buildRenamedFileName(
                  fileName,
                  duplicateResultForSheet?.matches ?? const [],
                );
                setState(() {
                  _pendingDuplicateChecked = result != null;
                  _pendingDuplicateConversationId = resolvedConversationId;
                  _pendingDuplicateResult = result;
                });
                setSheetState(() {});
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.88,
                decoration: const BoxDecoration(
                  color: Color(0xff1a1a1a),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              isImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        file,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildDocPreview(fileName, size: 80),
                                        const SizedBox(height: 16),
                                        Text(
                                          fileName,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        FutureBuilder<int>(
                                          future: file.length(),
                                          builder: (_, snap) => Text(
                                            snap.hasData
                                                ? _formatFileSize(snap.data!)
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              if (isCheckingDuplicate)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.72,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xffFFC107),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasDuplicateNotice)
                      Container(
                        width: double.infinity,
                        color: const Color(0xff4a3700),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Uploading a copy because a file with the same name is shared in this chat.',
                                style: const TextStyle(
                                  color: Color(0xffF9E07F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                preferReshareOlder = true;
                                Navigator.pop(ctx, true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xfff8f0d0),
                                  ),
                                ),
                                child: const Text(
                                  'Reshare older file instead',
                                  style: TextStyle(
                                    color: Color(0xfff8f0d0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: captionCtrl,
                                onChanged: (value) {
                                  draftCaption = value;
                                },
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Add a caption…',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(ctx).unfocus();
                              draftCaption = captionCtrl.text;
                              Navigator.pop(ctx, true);
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xffFFC107),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      if (confirmed != true) return;
      if (!mounted) return;

      final pro = getChatPro(context);
      final authpro = getAuthPro(context);
      final caption =
          (draftCaption.trim().isNotEmpty ? draftCaption : captionCtrl.text)
              .trim();

      int? conversationId = widget.conversationId;
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

      if (isSmsSelected &&
          _smsFromNumber.isNotEmpty &&
          _smsToNumber.isNotEmpty) {
        final sent = await pro.sendTwilioMmsMessage(
          currentUserId: authpro.user!.id,
          toNumber: _smsToNumber,
          fromNumber: _smsFromNumber,
          file: file,
          message: caption,
          openedConversationId: widget.conversationId ?? conversationId,
        );
        if (sent) {
          _clearPendingAttachmentMeta();
          _initScrollToBottom();
        }
        return;
      }

      if (hasDuplicateNotice) {
        if (preferReshareOlder && duplicateMatchPreview != null) {
          await pro.reshareDuplicateAttachment(
            match: duplicateMatchPreview!,
            originalFile: file,
            alternateFileName: fileName,
            conversationId: conversationId,
            currentUserId: authpro.user!.id,
            caption: caption,
          );
        } else {
          await pro.sendAttachmentMessage(
            file: file,
            conversationId: conversationId,
            currentUserId: authpro.user!.id,
            caption: caption,
            overrideFileName: renamedFileNamePreview,
          );
        }
        _clearPendingAttachmentMeta();
        _initScrollToBottom();
        return;
      }

      await _sendAttachmentWithDuplicateCheck(
        file: file,
        fileName: fileName,
        caption: caption,
        conversationId: conversationId,
        currentUserId: authpro.user!.id,
      );
      _initScrollToBottom();
    } catch (e, st) {
      printData(
        title: "ATTACHMENT PREVIEW SHEET ERROR:",
        data: "$e\n$st",
        e: true,
      );
    }
  }

  Future<void> _sendAttachmentWithDuplicateCheck({
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

    if (!mounted) return;

    if (duplicateResult == null || !duplicateResult.hasDuplicates) {
      await pro.sendAttachmentMessage(
        file: file,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
      );
      _clearPendingAttachmentMeta();
      return;
    }

    // Handle duplicates
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

    if (!mounted || action == _DuplicateAttachmentAction.cancel) return;
    if (action == _DuplicateAttachmentAction.reshare) {
      await pro.reshareDuplicateAttachment(
        match: duplicate,
        originalFile: file,
        alternateFileName: fileName,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
      );
    } else {
      await pro.sendAttachmentMessage(
        file: file,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
        overrideFileName: renamedFileName,
      );
    }
    _clearPendingAttachmentMeta();
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: 'Duplicate File Detected',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                SizedBox(height: 8.h),
                TextWidget(
                  text:
                      'Choose whether to reshare the older copy or upload this file with a new name.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                SizedBox(height: 14.h),
                _duplicateAttachmentInfoRow(
                  label: 'Selected',
                  value: originalFileName,
                ),
                SizedBox(height: 6.h),
                _duplicateAttachmentInfoRow(
                  label: 'Existing',
                  value: duplicateName,
                ),
                SizedBox(height: 18.h),
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
                SizedBox(height: 8.h),
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
          width: 60.w,
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
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(18.r),
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
                    SizedBox(height: 4.h),
                    TextWidget(
                      text: subtitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black45, size: 22.sp),
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

  bool _isImageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
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

    return Icon(iconData, size: size ?? 48.w, color: color);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget channelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isSmsSelected = false;
              _smsFromNumber = "";
              _smsToNumber = "";
            });
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
              _smsFromNumber = _sanitizeSmsNumber(value);
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
      elevation: 1,
      surfaceTintColor: Colors.white,
      backgroundColor: Colors.white,
      leadingWidth: 42,
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
              builder: (context, pro, _) {
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
        Consumer<ChatPro>(
          builder: (context, pro, _) {
            if (widget.conversationId != null) {
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
              icon: ImageIcon(
                AssetImage(Paths.call),
                color: AppColors.black,
                size: 20,
              ),
              onPressed: _showCallFromSheet,
            );
          },
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
    final shouldShowMessageOptions = !_isDeletedTextMessage(msg);

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
          if (shouldShowMessageOptions)
            Builder(
              builder: (iconCtx) {
                return GestureDetector(
                  onTap: () {
                    final RenderBox box =
                        iconCtx.findRenderObject() as RenderBox;
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
                      onDownload: () {
                        if (msg.type != 'image' && msg.type != 'file') return;
                        if (msg.isMoved) {
                          showToast(message: 'File has been deleted');
                          return;
                        }
                        final localPath = getChatPro(
                          context,
                        ).localAttachmentPaths[msg.id];
                        final remoteUrl =
                            (msg.attachmentUrl != null &&
                                msg.attachmentUrl!.isNotEmpty)
                            ? _resolveAttachmentUrl(
                                msg.attachmentUrl!,
                                cacheBuster: '${msg.id}',
                              )
                            : null;
                        _downloadChatAttachment(
                          localPath: localPath,
                          remoteUrl: remoteUrl,
                          fileName: msg.attachmentName,
                        );
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

  Widget _bubble(ChatMessage msg, {String? highlightQuery}) {
    if (msg.systemCard != null) {
      Color statusColor = Colors.grey;
      IconData statusIcon = Icons.done;
      if (msg.isRead == true) {
        statusIcon = Icons.done_all;
        statusColor = Colors.blue;
      } else if (msg.isDelivered == true) {
        statusIcon = Icons.done_all;
      }

      if (msg.type == 'reminder') {
        return ReminderMesgBubble(
          title: msg.systemCard!.title ?? '',
          description: msg.systemCard!.description ?? '',
          buttonLabel: msg.systemCard!.buttonLabel,
          buttonUrl: msg.systemCard!.buttonUrl,
          event: msg.systemCard!.event,
          isMe: msg.isMe,
          metaText:
              "${msg.channel == 'sms' ? 'SMS Chat' : 'App Chat'} • ${formatMessageTime(msg.createdAt.toString())}",
          statusIcon: statusIcon,
          statusColor: statusColor,
        );
      }

      return ProjectChatPebble(
        card: msg.systemCard!,
        isMe: msg.isMe,
        metaText:
            "${msg.channel == 'sms' ? 'SMS Chat' : 'App Chat'} • ${formatMessageTime(msg.createdAt.toString())}",
        statusIcon: statusIcon,
        statusColor: statusColor,
        onAttachmentTap: () {
          if (_isImageAttachmentMessage(msg)) {
            _openImagePreview(initialMessageId: msg.id);
          }
        },
      );
    }

    if (_isDeletedTextMessage(msg)) {
      return _deletedMessageBubble(msg);
    }

    // ── Call-type message bubble ──
    if (msg.type == 'call') {
      return _callBubble(msg);
    }
    // ── Video call-type message bubble ──
    if (msg.type == 'video_call') {
      return _videoCallBubble(msg);
    }
    // ── Call recording bubble (voice msg with is_call_recording) ──
    if (msg.isCallRecording && msg.audioUrl != null) {
      return _callRecordingBubble(msg);
    }
    // ── Video message bubble ──
    if (msg.type == 'video' && msg.videoUrl != null) {
      return _videoBubble(msg);
    }
    // ── Image / file attachment bubble ──
    if (msg.type == 'image' || msg.type == 'file') {
      return _attachmentBubble(msg);
    }
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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

  bool _isDeletedTextMessage(ChatMessage msg) {
    if (msg.type != 'text') return false;

    final normalized = msg.message.trim().toLowerCase();
    return normalized == 'this message was deleted' ||
        normalized == 'you deleted this message' ||
        normalized == 'message deleted';
  }

  Widget _deletedMessageBubble(ChatMessage msg) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 15.sp, color: const Color(0xFF6F6F6F)),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  msg.message,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF616161),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          _metaRow(msg),
        ],
      ),
    );
  }

  Future<dynamic> _deletePopup(ChatMessage msg) {
    if (msg.type == 'image' || msg.type == 'file') {
      return _showFileDeleteScopePopup(msg);
    }
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const TextWidget(
          text: "Delete Message?",
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        content: const TextWidget(
          text: "Are you sure you want to delete this message?",
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextWidget(
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
                deleteScope: 'everyone',
              );
            },
            child: const TextWidget(
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

  Future<_DeleteScopeAction> _showFileDeleteScopePopup(ChatMessage msg) async {
    final action = await showDialog<_DeleteScopeAction>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
        child: Container(
          width: 455.w,
          padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3C4),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: ImageWidget(
                        image: Paths.delete,
                        width: 18.w,
                        height: 18.w,
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: 'Delete File From Chat',
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 5.h),
                        TextWidget(
                          text: 'Choose how this file should be deleted.',
                          color: const Color(0xFF667085),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              _deleteScopeTile(
                title: 'For myself only',
                subtitle: 'Removes only from your chat folder.',
                titleColor: const Color(0xFF1F2937),
                subtitleColor: const Color(0xFF667085),
                borderColor: const Color(0xFFC7CED8),
                backgroundColor: Colors.white,
                onTap: () => Navigator.pop(ctx, _DeleteScopeAction.self),
              ),
              SizedBox(height: 12.h),
              _deleteScopeTile(
                title: 'For everyone',
                subtitle:
                    'Removes from both chat folders and deletes the message.',
                titleColor: const Color(0xFFEF3D32),
                subtitleColor: const Color(0xFFEF3D32),
                borderColor: const Color(0xFFF2ACA7),
                backgroundColor: const Color(0xFFFFF5F4),
                onTap: () => Navigator.pop(ctx, _DeleteScopeAction.everyone),
              ),
              SizedBox(height: 22.h),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 40.h,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(ctx, _DeleteScopeAction.cancel),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFC7CED8),
                        width: 1.2,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 18.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: TextWidget(
                      text: 'Cancel',
                      color: const Color(0xFF344054),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null || action == _DeleteScopeAction.cancel) {
      return _DeleteScopeAction.cancel;
    }

    await getChatPro(context).deleteMessage(
      messageId: msg.id,
      conversationId: msg.conversationId,
      deleteScope: action == _DeleteScopeAction.self ? 'self' : 'everyone',
    );

    return action;
  }

  Widget _deleteScopeTile({
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextWidget(
              text: title,
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            SizedBox(height: 3.h),
            TextWidget(
              text: subtitle,
              color: subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ],
        ),
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
    Widget previewContent;
    if (isImage) {
      Widget imageWidget;
      if (localPath != null) {
        imageWidget = Image.file(
          File(localPath),
          key: ValueKey('chat_img_local_${msg.id}_$localPath'),
          width: double.infinity,
          height: 200.h,
          fit: BoxFit.cover,
        );
      } else if (resolvedThumbnailUrl != null &&
          resolvedThumbnailUrl.isNotEmpty) {
        imageWidget = ImageWidget(
          key: ValueKey('chat_img_thumb_${msg.id}_$resolvedThumbnailUrl'),
          image: resolvedThumbnailUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorWidget:
              (resolvedRemoteUrl != null && resolvedRemoteUrl.isNotEmpty)
              ? ImageWidget(
                  key: ValueKey('chat_img_remote_${msg.id}_$resolvedRemoteUrl'),
                  image: resolvedRemoteUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    width: double.infinity,
                    height: 200.h,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 200.h,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
        );
      } else if (resolvedRemoteUrl != null && resolvedRemoteUrl.isNotEmpty) {
        imageWidget = ImageWidget(
          key: ValueKey('chat_img_remote_${msg.id}_$resolvedRemoteUrl'),
          image: resolvedRemoteUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorWidget: Container(
            width: double.infinity,
            height: 200.h,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        );
      } else {
        imageWidget = Container(
          width: double.infinity,
          height: 200.h,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, size: 48, color: Colors.grey),
        );
      }
      final rawImageName =
          (msg.attachmentName != null && msg.attachmentName!.isNotEmpty)
          ? msg.attachmentName!
          : msg.message.replaceAll('📎 ', '');
      previewContent = GestureDetector(
        onTap: isMovedAttachment
            ? null
            : () {
                _openImagePreview(initialMessageId: msg.id);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMovedAttachment)
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 8.w, 8.w, 0),
                child: _buildMovedFileBanner(msg, isImage: true),
              )
            else
              Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 8.w, 8.w, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14.r),
                      child: imageWidget,
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14.r),
                            topRight: Radius.circular(14.r),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  color: Colors.white,
                                  strokeWidth: 3.5,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      rawImageName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (msg.expiresInDays != null)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: _buildExpiryLabel(msg, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // File type
      final rawName =
          (msg.attachmentName != null && msg.attachmentName!.isNotEmpty)
          ? msg.attachmentName!
          : msg.message.replaceAll('📎 ', '');
      final resolvedThumbnailUrl =
          (msg.thumbnailUrl != null && msg.thumbnailUrl!.isNotEmpty)
          ? _resolveAttachmentUrl(msg.thumbnailUrl!, cacheBuster: '${msg.id}')
          : null;
      previewContent = Padding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMovedAttachment)
              SizedBox(
                width: 240.w,
                child: _buildMovedFileBanner(msg, isImage: false),
              )
            else
              Container(
                width: 240.w,
                height: 112.h,
                decoration: BoxDecoration(
                  color: const Color(0xffe9e9eb),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xffcfcfd3), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Center(
                    child:
                        (resolvedThumbnailUrl != null &&
                            resolvedThumbnailUrl.isNotEmpty)
                        ? Padding(
                            padding: EdgeInsets.all(12.w),
                            child: ImageWidget(
                              image: resolvedThumbnailUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorWidget: _buildDocPreview(rawName),
                            ),
                          )
                        : _buildDocPreview(rawName),
                  ),
                ),
              ),
            SizedBox(height: 10.h),
            SizedBox(
              width: 240.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rawName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (msg.expiresInDays != null)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: _buildExpiryLabel(msg, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (isUploading) ...[
              SizedBox(height: 6.h),
              SizedBox(
                width: 240.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    color: AppColors.primary,
                    minHeight: 4,
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: msg.isMe ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isImage
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.start,
        children: [
          if (!msg.isMe && msg.senderName != null)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
              child: TextWidget(
                text: msg.senderName!,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          previewContent,
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 6.h),
            child: _metaRow(msg),
          ),
        ],
      ),
    );
  }

  Widget _buildMovedFileBanner(ChatMessage msg, {required bool isImage}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xffede8da),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFFF3D670), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File does not exist',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xff8a6b05),
              ),
            ),
            if (msg.movedByName != null) ...[
              SizedBox(height: 4.h),
              Text(
                'Deleted by ${msg.movedByName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff8a6b05),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryLabel(ChatMessage msg, {required double fontSize}) {
    if (msg.isMoved && msg.expiresInDays != null && !msg.isExpired) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xfff3d670),
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Text(
          'Expires in ${msg.expiresInDays!.toStringAsFixed(0)} days',
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(0xff7c5c00),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Text(
      msg.isExpired
          ? 'Expired'
          : 'Expires in ${msg.expiresInDays!.toStringAsFixed(0)} days',
      style: TextStyle(
        fontSize: fontSize,
        color: msg.isExpired ? Colors.red : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _resolveAttachmentUrl(String rawUrl, {String? cacheBuster}) {
    // Clean up URL: remove any surrounding spaces or backticks
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
    // If it's already a full URL with query parameters (like S3 signed URLs),
    // don't add the cache buster because it will invalidate the signature.
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
                      right: 10,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(ctx).pop(),
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
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${imageItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
    } catch (e, st) {
      Loaders.hide();
      printData(
        title: "DOWNLOAD CHAT ATTACHMENT ERROR:",
        data: "$e\n$st",
        e: true,
      );
      showToast(message: "Failed to save file");
    }
  }

  String formatMessageTime(String dateTime) {
    final dt = DateTime.parse(dateTime);
    return DateFormat("dd/MM/yyyy • h:mma").format(dt).toLowerCase();
  }

  /// Special bubble for call-type messages
  Widget _callBubble(ChatMessage msg) {
    final callOutcome = (msg.callOutcome ?? '').toLowerCase();
    final callStatus = (msg.callStatus ?? '').toLowerCase();
    final messageLower = msg.message.toLowerCase();
    final isDeclined =
        callOutcome == 'rejected' ||
        callStatus == 'canceled' ||
        messageLower.contains('declined');
    final isMissed = msg.isMissedCall == true;
    // Build the title — use user name from message
    String callerLabel;
    if (msg.isMe) {
      callerLabel = "You";
    } else {
      callerLabel = msg.senderName ?? 'Unknown';
    }
    final title = isDeclined
        ? msg.message
        : (isMissed
              ? "Missed Called From $callerLabel"
              : "Called From $callerLabel");
    // Format phone numbers
    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null
        ? _formatPhone(msg.callToNumber!)
        : 'You';
    // Date/time
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();
    final bgColor = (isMissed || isDeclined)
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageWidget(
                image: (isMissed || isDeclined) ? Paths.close : Paths.call3,
                width: (isMissed || isDeclined) ? 18 : 22,
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

  Widget _videoCallBubble(ChatMessage msg) {
    final callOutcome = (msg.callOutcome ?? '').toLowerCase();
    final callStatus = (msg.callStatus ?? '').toLowerCase();
    final messageLower = msg.message.toLowerCase();
    final isDeclined =
        callOutcome == 'rejected' ||
        callStatus == 'canceled' ||
        messageLower.contains('declined');
    final isMissed = msg.isMissedCall == true;
    // Build the title — use user name from message
    String callerLabel;
    if (msg.isMe) {
      callerLabel = "You";
    } else {
      callerLabel = msg.senderName ?? 'Unknown';
    }
    final title = isDeclined
        ? msg.message
        : (isMissed
              ? "Missed Video Call From $callerLabel"
              : "Video Call From $callerLabel");
    // Format phone numbers
    final from = msg.callFromNumber != null
        ? _formatPhone(msg.callFromNumber!)
        : '—';
    final to = msg.callToNumber != null
        ? _formatPhone(msg.callToNumber!)
        : 'You';
    // Date/time
    final dateStr = DateFormat(
      'MM/dd/yyyy • h:mma',
    ).format(msg.createdAt).toLowerCase();
    final bgColor = (isMissed || isDeclined)
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageWidget(
                image: (isMissed || isDeclined) ? Paths.close : Paths.call3,
                width: (isMissed || isDeclined) ? 18 : 22,
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

  /// Call recording bubble (voice message with is_call_recording) ──
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
    final to = msg.callToNumber != null
        ? _formatPhone(msg.callToNumber!)
        : 'You';
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

  /// Video message bubble
  Widget _videoBubble(ChatMessage msg) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
              padding: EdgeInsets.only(bottom: 6.h),
              child: TextWidget(
                text: msg.senderName!,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

          // Video player
          VideoMessageBubbleUI(
            videoUrl: msg.videoUrl!,
            duration: msg.videoDuration,
            isMe: msg.isMe,
            isVideoCallRecording: msg.isVideoCallRecording,
          ),

          SizedBox(height: 4.h),
          // Time + ticks
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: TextWidget(
              text:
                  "${msg.channel == 'sms' ? 'SMS Chat' : 'APP Chat'} • ${formatMessageTime(msg.createdAt.toString())}",
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (msg.isMe) ...[
            SizedBox(width: 5.w),
            Icon(iconData, size: 14.sp, color: iconColor),
          ],
        ],
      ),
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
