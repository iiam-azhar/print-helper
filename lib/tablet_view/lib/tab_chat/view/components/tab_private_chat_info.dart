import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import '../../../tab_constants/colors.dart';
import 'package:print_helper/models/profile_models.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
import '../../../tab_constants/paths.dart';
import '../../../tab_services/helpers.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../tab_chat_profile.dart';
import 'tab_voice_mesg_bubble.dart';

class PrivateChatInfo extends StatefulWidget {
  final ChatConversation conversation;

  const PrivateChatInfo({super.key, required this.conversation});

  @override
  State<PrivateChatInfo> createState() => _PrivateChatInfoState();
}

class _PrivateChatInfoState extends State<PrivateChatInfo> {
  String? otherUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authPro = getAuthPro(context);
      if (authPro.user == null) return;

      // Find the other user in the conversation
      final otherUser = widget.conversation.participants.firstWhere(
        (p) => p.id != authPro.user!.id,
        orElse: () => widget.conversation.participants.isNotEmpty
            ? widget.conversation.participants.first
            : ChatParticipant(
                name: 'Unknown',
                username: '',
                lastName: '',
                isOnline: false,
                phoneNumbers: [],
              ),
      );

      if (otherUser.id != null) {
        otherUserId = otherUser.id.toString();
        final pro = getChatPro(context);
        pro.fetchUserProfile(
          otherUserId!,
          conversationId: widget.conversation.id,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: 'Contact Info',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Profile Content
          Expanded(
            child: Consumer<ChatPro>(
              builder: (context, provider, child) {
                if (provider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextWidget(
                          text: provider.errorMessage!,
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (otherUserId != null) {
                              provider.fetchUserProfile(
                                otherUserId!,
                                conversationId: widget.conversation.id,
                              );
                            }
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }

                final data = provider.userProfile;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileHeader(data),
                      const SizedBox(height: 16),
                      if (data.role != 1 && data.role != 2)
                        Column(
                          children: [
                            _ExpandableCard(
                              title: "Company",
                              initiallyExpanded: true,
                              child: _companyBody(data),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      _ExpandableCard(
                        title: "About",
                        initiallyExpanded: true,
                        child: _aboutSection(data),
                      ),
                      const SizedBox(height: 16),
                      _ExpandableCard(
                        title: "Recordings",
                        initiallyExpanded: true,
                        child: _recordings(data),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(ProfileData data) {
    return GestureDetector(
      onTap: () {
        if (otherUserId != null) {
          navTo(
            context: context,
            page: ProfileDetails(
              // id: otherUserId!,
              // conversationId: widget.conversation.id,
            ),
          );
        }
      },
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(70),
              border: Border.all(color: const Color(0x779E9E9E)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(70),
              child: ImageWidget(
                image: data.image.isNotEmpty ? data.image : Paths.user,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Spacers.sb8(),
          TextWidget(
            text: data.name,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          if (data.role != 1 && data.role != 2)
            TextWidget(
              text: "Wholesale",
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
        ],
      ),
    );
  }

  Widget _companyBody(ProfileData data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0x779E9E9E)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: ImageWidget(
                image: data.companyLogo.isEmpty ? Paths.user : data.companyLogo,
                height: 50,
                width: 50,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Spacers.sbw15(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: data.companyName,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                Spacers.sb5(),
                TextWidget(
                  text:
                      "${data.companySegment} | ${DateFormat('MM/dd/yy - hh:mma').format(data.createdAt).toLowerCase()}",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb5(),
                TextWidget(
                  text:
                      "${data.projectsCount} Projects - ${data.filesCount} Files",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb5(),
                TextWidget(
                  text: "${data.contactsCount} Contact(s)",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb12(),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextWidget(
                        text: "View Page",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection(ProfileData data) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.phones.isNotEmpty) ...[
              TextWidget(
                text: "Phones:",
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              Spacers.sb2(),
              ...data.phones.map(
                (phone) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: TextWidget(
                    text: phone,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            Spacers.sb5(),
            if (data.emails.isNotEmpty) ...[
              TextWidget(
                text: "Email:",
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              Spacers.sb2(),
              ...data.emails.map(
                (email) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: TextWidget(
                    text: email,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            Spacers.sb10(),
            if (data.preferredLanguages.isNotEmpty) ...[
              TextWidget(
                text: "Preferred Languages:",
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              Spacers.sb2(),
              ...data.preferredLanguages.map(
                (lang) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: TextWidget(
                    text: lang,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Spacers.sb5(),
            ],
            Spacers.sb10(),
            if (data.skills.isNotEmpty) ...[
              TextWidget(
                text: "Skills:",
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              Spacers.sb2(),
              ...data.skills.map(
                (skill) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: TextWidget(
                    text: skill,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Spacers.sb5(),
            ],
            Spacers.sb5(),
          ],
        ),
      ),
    );
  }

  Widget _recordings(ProfileData data) {
    // Filter recordings by conversation ID
    final filteredRecordings = data.recordings
        .where((rec) => rec.conversationId == widget.conversation.id)
        .toList();

    if (filteredRecordings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextWidget(
          text: "No Recordings",
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      );
    }

    int parseDuration(String raw) {
      try {
        final parts = raw.split(":");
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = int.tryParse(parts[1]) ?? 0;
          return m * 60 + s;
        }
      } catch (_) {}
      return 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: filteredRecordings
            .where((rec) => rec.voiceUrl.isNotEmpty || rec.voicePath.isNotEmpty)
            .map((rec) {
              final durationSecs = parseDuration(rec.duration);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffF2F2F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    VoiceMessageBubbleUI(
                      path: rec.voiceUrl.isNotEmpty
                          ? rec.voiceUrl
                          : rec.voicePath,
                      duration: durationSecs,
                      isMe: false,
                      isUploading: rec.voiceUrl.isEmpty,
                    ),
                    Spacers.sb8(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextWidget(
                        text: rec.recordedAt != null
                            ? DateFormat(
                                'dd/MM/yyyy • h:mm a',
                              ).format(rec.recordedAt!)
                            : (rec.timeLabel ?? ''),
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(),
      ),
    );
  }
}

class _ExpandableCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableCard({
    required this.title,
    required this.child,
    required this.initiallyExpanded,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF3F3F3),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(14),
                      bottom: _expanded
                          ? Radius.zero
                          : const Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextWidget(
                        text: widget.title,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const ImageWidget(image: Paths.up, height: 10),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _expanded ? widget.child : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
