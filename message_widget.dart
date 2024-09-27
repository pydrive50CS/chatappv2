import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:web_socket/models/chat_model.dart';
import 'package:web_socket/widgets/audio_bubble.dart';
import 'package:web_socket/widgets/chat_image_preview.dart';
import 'package:web_socket/widgets/message_status_icon.dart';

class MessageWidget extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;
  final PlayerController? audioController;

  const MessageWidget({
    super.key,
    required this.message,
    required this.currentUserId,
    this.audioController,
  });

  @override
  Widget build(BuildContext context) {
    bool isMe = message.sender == currentUserId;
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.type == 'text') _buildTextMessage(isMe),
        if (message.type == 'image') _buildImageMessage(context, isMe),
        if (message.type == 'audio') _buildAudioMessage(isMe),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTextMessage(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isMe ? MessageStatusIcon(messageStatus: message.status) : const SizedBox.shrink(),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(message.content),
        ),
      ],
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isMe) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImage(imagePath: message.content),
            ),
          );
        },
        child: SizedBox(
          height: MediaQuery.of(context).size.height / 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isMe ? MessageStatusIcon(messageStatus: message.status) : const SizedBox.shrink(),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0), // Rounded corner with 10px radius
                child: Image.file(
                  File(message.content),
                  fit: BoxFit.cover, // Ensures the image fits within the rounded corners
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildAudioMessage(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isMe ? MessageStatusIcon(messageStatus: message.status) : const SizedBox.shrink(),
        const SizedBox(width: 10),
        WaveBubble(audioBytes: message.content, audioController: audioController!),
      ],
    );
  }
}
