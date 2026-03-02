import 'package:flutter/material.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import '../../../tab_constants/paths.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_text_widget.dart';

class GroupInfo extends StatelessWidget {
  final ChatConversation conversation;

  const GroupInfo({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final memberCount = conversation.participants.length;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 22, color: Colors.black87),
                const SizedBox(width: 12),
                const TextWidget(
                  text: "Group Info",
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    size: 24,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Members List
          Expanded(
            child: ListView.builder(
              itemCount: memberCount,
              itemBuilder: (context, index) {
                final member = conversation.participants[index];
                return _buildMemberTile(member);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(ChatParticipant member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: ImageWidget(
                  image: member.image?.isNotEmpty == true
                      ? member.image!
                      : Paths.user,
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                ),
              ),
              if (member.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Member details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "${member.name} ${member.lastName}",
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                const SizedBox(height: 3),
                TextWidget(
                  text: "@${member.username}",
                  fontSize: 13,
                  color: const Color(0xFF808080),
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
