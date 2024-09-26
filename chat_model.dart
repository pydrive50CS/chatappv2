class ChatMessage {
  final String sender;
  final String content;
  final String type; // text, image, video, etc.

  ChatMessage({
    required this.sender,
    required this.content,
    required this.type,
  });
}
