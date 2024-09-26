import 'package:flutter/material.dart';
import 'package:web_socket/presentation/screens/chat_page.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatPage(
        userId: 'UserA',
        otherUserId: 'UserB',
        otherUserName: 'B',
        roomId: 'roomA-B',
      ),
    );
  }
}

// class ChatPage extends StatefulWidget {
//   const ChatPage({super.key});

//   @override
//   ChatPageState createState() => ChatPageState();
// }

// class ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<Map<String, String>> _messages = [];
//   String? _typingUserId;
//   late WebSocketChannel _channel;
//   bool _isConnected = false;
//   Timer? _reconnectTimer;
//   bool _otherUserOnline = false;

//   late final String _userId = 'UserA';
//   late final String _otherUserId = 'UserB';
//   late final String _roomId = 'roomA-B';

//   int _reconnectAttempts = 0;
//   final int _maxReconnectAttempts = 5;

//   @override
//   void initState() {
//     super.initState();
//     _connectWebSocket();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     _channel.sink.close();
//     // log('Here is before');
//     // if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
//     //   log('Here is After');
//     //   _channel.sink.add(jsonEncode({"type": "disconnect", "userId": _userId}));
//     //   _channel.sink.close(); // Close the WebSocket connection
//     // }
//   }

//   @override
//   void dispose() {
//     _channel.sink.close();
//     _controller.dispose();
//     _scrollController.dispose();
//     _reconnectTimer?.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   void _connectWebSocket() {
//     log('Attempting to connect to WebSocket...');

//     _channel = WebSocketChannel.connect(
//       Uri.parse('ws://192.168.10.141:8080'), // Replace with your WebSocket server IP
//     );

//     // Join the specific room for communication with User A
//     _channel.sink.add(json.encode({
//       'type': 'join',
//       'userId': _userId,
//       'roomId': _roomId,
//     }));
//     _channel.sink.add(json.encode({'type': 'ping'}));

//     // Listen for incoming messages
//     _channel.stream.listen((message) {
//       final data = json.decode(message);

//       log('Received message: $message');

//       // Handle incoming message
//       if (data['type'] == 'message' && data['roomId'] == _roomId) {
//         setState(() {
//           _messages.add({'sender': data['sender'], 'text': data['text']});
//           _typingUserId = null; // Stop typing indicator when message is received
//         });
//         _scrollToBottom();
//       }

//       // Handle typing indicator
//       if (data['type'] == 'typing' && data['roomId'] == _roomId) {
//         setState(() {
//           _typingUserId = data['sender'];
//         });
//       }
//       // Handle pong response to establish connection
//       if (data['type'] == 'pong') {
//         log('Received pong from server');
//         setState(() {
//           _isConnected = true;
//           _reconnectAttempts = 0;
//         });
//         _stopReconnectTimer(); // Stop the reconnect attempts
//       }
//       // Handle user online/offline status
//       if (data['type'] == 'statusUpdate' && data['users'] != null) {
//         setState(() {
//           _otherUserOnline = data['users'].contains(_otherUserId); // Update the online status based on the list of online users
//         });
//       }
//     }, onDone: _handleDisconnect);
//   }

// // Handle WebSocket disconnection
//   void _handleDisconnect() {
//     log('Disconnected from server');
//     setState(() {
//       _isConnected = false;
//     });
//     _attemptReconnect();
//   }

//   // Try to reconnect by pinging the server every 5 seconds
//   void _attemptReconnect() {
//     if (_isConnected) return;
//     if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
//       _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//         if (_reconnectAttempts >= _maxReconnectAttempts) {
//           log('Max reconnect attempts reached. Stopping timer.');
//           _stopReconnectTimer();
//           _handleMaxReconnectAttemptsReached();
//           return;
//         }
//         if (!_isConnected) {
//           _reconnectAttempts++; // Increment the reconnect attempts
//           log('Sending ping to server (Attempt $_reconnectAttempts)');
//           _connectWebSocket();
//         } else {
//           _stopReconnectTimer();
//         }
//       });
//     }
//   }

//   // Handle max reconnect attempts reached (timeout logic)
//   void _handleMaxReconnectAttemptsReached() {
//     log('Max reconnect attempts reached. Connection failed.');
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Connection Error'),
//           content: const Text('Unable to reconnect to the server after multiple attempts.'),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('Retry'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _reconnectAttempts = 0; // Reset the attempt counter and try reconnecting again
//                 _attemptReconnect(); // Start the reconnection process again
//               },
//             ),
//             TextButton(
//               child: const Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 // Optionally, close the WebSocket connection or take other actions
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Stop the reconnect timer when connected
//   void _stopReconnectTimer() {
//     if (_reconnectTimer != null && _reconnectTimer!.isActive) {
//       log('Stopping reconnect timer');
//       _reconnectTimer!.cancel();
//     }
//   }

//   // Send the message to the WebSocket server
//   void _sendMessage() {
//     if (_controller.text.isNotEmpty && _isConnected) {
//       _channel.sink.add(json.encode({
//         'type': 'message',
//         'sender': _userId,
//         'text': _controller.text,
//         'roomId': _roomId,
//       }));
//       _controller.clear();
//       _scrollToBottom();
//     }
//   }

//   // Notify the server that the user is typing
//   void _sendTypingIndicator() {
//     if (_isConnected) {
//       _channel.sink.add(json.encode({
//         'type': 'typing',
//         'sender': _userId,
//         'roomId': _roomId,
//       }));
//     }
//   }

//   // Scroll to the bottom of the chat when a new message arrives
//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 100), () {
//       _scrollController.animateTo(
//         _scrollController.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Row(
//           children: [
//             CircleAvatar(
//               backgroundImage: const NetworkImage(
//                   'https://plus.unsplash.com/premium_photo-1664474619075-644dd191935f?q=80&w=2069&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
//               radius: 20,
//               child: Align(
//                 alignment: Alignment.bottomRight,
//                 child: CircleAvatar(
//                   radius: 6,
//                   backgroundColor: _otherUserOnline ? Colors.green : Colors.grey,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Text('Chat with $_otherUserId'),
//           ],
//         ),
//       ),
//       body: Column(
//         children: <Widget>[
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: const EdgeInsets.all(8),
//               itemCount: _messages.length,
//               itemBuilder: (BuildContext context, int index) {
//                 final isSentByMe = _messages[index]['sender'] == _userId;
//                 return Align(
//                   alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
//                   child: Container(
//                     padding: const EdgeInsets.all(12),
//                     margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//                     decoration: BoxDecoration(
//                       color: isSentByMe ? Colors.blueAccent : Colors.grey[300],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       _messages[index]['text']!,
//                       style: TextStyle(
//                         color: isSentByMe ? Colors.white : Colors.black,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           if (_typingUserId != null && _typingUserId != _userId)
//             Padding(
//               padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   '$_otherUserId is typing...',
//                   style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
//                 ),
//               ),
//             ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             child: Row(
//               children: <Widget>[
//                 Expanded(
//                   child: TextField(
//                     controller: _controller,
//                     decoration: const InputDecoration(
//                       labelText: 'Send a message',
//                     ),
//                     onChanged: (_) {
//                       _sendTypingIndicator();
//                     },
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.send),
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
