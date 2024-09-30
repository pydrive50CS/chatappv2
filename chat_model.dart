class ChatMessage {
  final String id;
  final String sender;
  final String content;
  final String type;
  String? timeStamp;
  String status;
  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    this.timeStamp,
    this.status = 'sending',
  });
}
