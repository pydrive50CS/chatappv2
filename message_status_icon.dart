import 'package:flutter/material.dart';

class MessageStatusIcon extends StatefulWidget {
  final String messageStatus;

  const MessageStatusIcon({super.key, required this.messageStatus});

  @override
  MessageStatusIconState createState() => MessageStatusIconState();
}

class MessageStatusIconState extends State<MessageStatusIcon> {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 6, // Adjust the size of the circle
      backgroundColor: widget.messageStatus == 'sending' ? Colors.blue.shade100 : Colors.grey.shade200,
      // Add a subtle shadow for a cool effect
      foregroundColor: Colors.transparent, // Background color
      child: Align(
        alignment: Alignment.center,
        child: Icon(
          Icons.check,
          color: widget.messageStatus == 'sending' ? Colors.grey : Colors.blue,
          size: 14,
        ),
      ),
    );
  }
}
