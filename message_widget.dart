import 'dart:convert';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket/models/chat_model.dart';
import 'package:web_socket/presentation/screens/video_player_screen.dart';
import 'package:web_socket/widgets/audio_bubble.dart';
import 'package:web_socket/widgets/chat_image_preview.dart';

class MessageWidget extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;
  final PlayerController? audioController;
  const MessageWidget({super.key, required this.message, required this.currentUserId, this.audioController});

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
        if (message.type == 'image')
          FutureBuilder<String>(
            future: saveImageToTempDirectory(message.content),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final filePath = snapshot.data!;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImage(imagePath: filePath),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height / 6,
                    child: Image.file(File(filePath)),
                  ),
                );
              } else if (snapshot.hasError) {
                return const Text("Error loading image");
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        if (message.type == 'video') VideoPlayerWidget(videoBytes: base64Decode(message.content)),
        if (message.type == 'audio') WaveBubble(audioBytes: message.content, audioController: audioController!),
      ],
    );
  }

  Future<String> saveImageToTempDirectory(String base64Image) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Image));
      return filePath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      throw Exception('Failed to save image');
    }
  }
}
