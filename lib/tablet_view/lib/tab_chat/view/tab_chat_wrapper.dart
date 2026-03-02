import 'package:flutter/material.dart';
import 'package:print_helper/admin/chat/models/chat_models.dart';
import 'tab_chat_list.dart';
import '../../tab_constants/paths.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_text_widget.dart';

import 'tab_chat_screen.dart';

class ChatWrapper extends StatefulWidget {
  const ChatWrapper({super.key});

  @override
  State<ChatWrapper> createState() => _ChatWrapperState();
}

class _ChatWrapperState extends State<ChatWrapper> {
  ChatConversation? selectedChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 🟦 CHAT LIST (full width when no chat is open)
          if (selectedChat == null)
            SizedBox(
              width: 450,
              child: ChatList(
                onChatSelected: (chat) {
                  setState(() {
                    selectedChat = chat;
                  });
                },
              ),
            ),

          // 🟦 CHAT LIST (fixed width when chat is open)
          if (selectedChat != null)
            SizedBox(
              width: 450,
              child: ChatList(
                onChatSelected: (chat) {
                  setState(() {
                    selectedChat = chat;
                  });
                },
              ),
            ),

          // 🔸 Divider
          const VerticalDivider(width: 1),
          // 🟨 WELCOME PANEL (no chat selected)
          if (selectedChat == null)
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageWidget(image: Paths.chatBgg, fit: BoxFit.cover),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        TextWidget(
                          text: "Welcome!",
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff414345),
                        ),
                        SizedBox(height: 6),
                        TextWidget(
                          text: "Connect with your team instantly.",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff6b6b6b),
                        ),
                        SizedBox(height: 2),
                        TextWidget(
                          text:
                              "Start a conversation by searching for users above.",
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xff6b6b6b),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 🟨 CHAT SCREEN
          if (selectedChat != null)
            Expanded(
              child: ChatScreen(
                conversationId: selectedChat!.id,
                receiverUserId: selectedChat!.otherParticipants?.id ?? 0,
                name: selectedChat!.title,
                image: selectedChat!.image,
                subtitle: selectedChat!.otherParticipants?.username ?? '',
                onBack: () {
                  setState(() {
                    selectedChat = null; // ✅ BACK WORKS
                  });
                },
                showBack: true,
              ),
            ),
        ],
      ),
    );
  }
}
