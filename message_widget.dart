import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket/models/chat_model.dart';
import 'package:web_socket/presentation/screens/video_player_screen.dart';
import 'package:web_socket/widgets/audio_bubble.dart';

class MessageWidget extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;

  const MessageWidget({super.key, required this.message, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    bool isMe = message.sender == currentUserId;
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.type == 'text')
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[100] : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(message.content),
          ),
        if (message.type == 'image') SizedBox(height: MediaQuery.of(context).size.height / 6, child: Image.memory(base64Decode(message.content))),
        if (message.type == 'video') VideoPlayerWidget(videoBytes: base64Decode(message.content)),
        if (message.type == 'audio') WaveBubble(audioBytes: message.content),
      ],
    );
  }
}
