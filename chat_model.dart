class ChatMessage {
  final String id;
  final String sender;
  final String content;
  final String type;
  String status;
  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    this.status = 'sending',
  });
}
