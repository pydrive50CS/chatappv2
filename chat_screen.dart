import 'dart:async';
import 'dart:convert';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket/models/chat_model.dart';
import 'package:web_socket/services/audio_record_manager.dart';
import 'package:web_socket/widgets/message_widget.dart';
import 'package:web_socket/ws_manager.dart';
import 'dart:developer';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final String roomId;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    required this.roomId,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final List<PlayerController> audioControllers = [];
  final TextEditingController _messageInputCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _typingUserId;
  bool _otherUserOnline = false;
  bool _userOnline = false;
  bool _isTextMessageComposing = false;
  bool _isRecording = false;
  String? recordedStringBytes;
  Timer? _debounceTimer;
  late WSManager _wsManager;
  final AudioRecorderManager _audioRecorderManager = AudioRecorderManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorderManager.initialize();
    _wsManager = WSManager(
      userId: widget.userId,
      otherUserId: widget.otherUserId,
      roomId: widget.roomId,
    );
    _wsManager.onMaxReconnectReached = _showReconnectDialog;
    _wsManager.connect(
      _onMessageReceived,
      _onTypingIndicator,
      _onNotTypingIndicator,
      _onConnectionStatusChanged,
      _onStatusUpdate,
    );
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      // _wsManager.closeConnection();
    }
  }

  @override
  void dispose() {
    _wsManager.closeConnection();
    _audioRecorderManager.dispose();
    _messageInputCtrl.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in audioControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onMessageReceived(String id, String sender, String message, String type) {
    setState(() {
      // Update status if the message was sent by the current user
      if (sender == widget.userId) {
        final index = _messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          _messages[index].status = 'sent'; // Update to sent
        }
      } else {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: sender,
          content: message,
          type: type,
        ));
        _typingUserId = null;
      }
    });
  }

  void _onTypingIndicator(String sender) {
    setState(() {
      if (sender != widget.userId) {
        _typingUserId = sender;
      }
    });
  }

  void _onNotTypingIndicator(String sender) {
    setState(() {
      _typingUserId = null;
    });
  }

  void _onConnectionStatusChanged(bool isConnected) {
    log('WebSocket connection status: $isConnected');
  }

  void _onStatusUpdate(bool otherUserOnline, bool userOnline) {
    setState(() {
      _otherUserOnline = otherUserOnline;
      _userOnline = userOnline;
    });
  }

  void _sendMessage(String type, String content) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    ChatMessage newMessage;
    if (type == 'image') {
      final path = await _wsManager.saveImageToTempDirectory(content);
      newMessage = ChatMessage(
        id: messageId,
        sender: widget.userId,
        content: path,
        type: type,
        status: 'sending',
      );
    } else {
      newMessage = ChatMessage(
        id: messageId,
        sender: widget.userId,
        content: content,
        type: type,
        status: 'sending',
      );
    }
    setState(() {
      _messages.add(newMessage);
      _isTextMessageComposing = false;
    });
    log('$type,$content');
    _wsManager.sendMessage(type, messageId, content);
  }

  void _sendTypingIndicator(bool isTyping) {
    log(isTyping ? "User is typing..." : "User stopped typing...");
    // Send WebSocket message here
    isTyping ? _wsManager.sendTypingIndicator() : _wsManager.sendNotTypingIndicator();
  }

  Future<void> _sendMedia(String type, {String? audioBytes}) async {
    final picker = ImagePicker();
    XFile? file;
    if (type == 'text') {
      _sendMessage(type, _messageInputCtrl.text);
      _messageInputCtrl.clear();
    } else if (type == 'image') {
      file = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 50);
    } else if (type == 'audio' && audioBytes != null) {
      _sendMessage(type, audioBytes);
      return;
    }
    //for video
    // else if (type == 'video') {
    //       file = await picker.pickVideo(source: ImageSource.gallery);
    //     }
    if (file != null) {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      _sendMessage(type, base64String);
    }
  }

  void _showReconnectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Connection Timed Out"),
          content: const Text("Max reconnect attempts reached. Would you like to retry or cancel?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Retry"),
              onPressed: () {
                _wsManager.resetReconnectAttempts(); // Reset reconnect attempts
                _wsManager.connect(
                  _onMessageReceived,
                  _onTypingIndicator,
                  _onNotTypingIndicator,
                  _onConnectionStatusChanged,
                  _onStatusUpdate,
                );
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  void _onTextChanged(String text) {
    // Cancel previous timer if it's active
    _debounceTimer?.cancel();

    if (text.isEmpty) {
      // If text field is empty, send stopped typing event
      _sendTypingIndicator(false);
      setState(() {
        _isTextMessageComposing = false;
      });
    } else {
      // Start the timer to detect stopped typing after 2 seconds
      _sendTypingIndicator(true);
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _sendTypingIndicator(false);
      });
      setState(() {
        _isTextMessageComposing = true;
      });
    }
  }

  void _startOrStopRecording() async {
    if (_isRecording) {
      // Stop recording and get the recorded data
      final result = await _audioRecorderManager.stopRecording();
      if (result != null) {
        setState(() {
          recordedStringBytes = result;
        });
        _sendMedia('audio', audioBytes: recordedStringBytes);
      }
    } else {
      // Start recording
      await _audioRecorderManager.startRecording();
    }

    setState(() {
      _isRecording = !_isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: const NetworkImage(
                  'https://plus.unsplash.com/premium_photo-1664474619075-644dd191935f?q=80&w=2069&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
              radius: 20,
              child: Align(
                alignment: Alignment.bottomRight,
                child: CircleAvatar(
                  radius: 6,
                  backgroundColor: _otherUserOnline ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Chat with ${widget.otherUserName}'),
            const Spacer(),
            CircleAvatar(
              radius: 6,
              backgroundColor: _userOnline ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final audioController = PlayerController();
                audioControllers.add(audioController);
                return MessageWidget(
                  message: _messages[index],
                  currentUserId: widget.userId,
                  audioController: audioControllers[index],
                );
              },
            ),
          ),
          //typing indicator
          if (_typingUserId != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_typingUserId is typing...',
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
                ),
              ),
            ),
          //send buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.only(left: 10, bottom: 5, top: 5, right: 10),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.blue, borderRadius: const BorderRadius.all(Radius.circular(48)), border: Border.all(width: 1)),
              child: Row(
                children: <Widget>[
                  _isRecording
                      ? _audioRecorderManager.buildWaveform(context)
                      : Expanded(
                          child: TextField(
                            controller: _messageInputCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Write message...',
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            onChanged: _onTextChanged,
                          ),
                        ),
                  const SizedBox(width: 5),
                  _isTextMessageComposing
                      ? const SizedBox()
                      : FloatingActionButton.small(
                          onPressed: () => _sendMedia('image'),
                          elevation: 0,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                  const SizedBox(width: 5),
                  !_isTextMessageComposing
                      ? const SizedBox()
                      : FloatingActionButton.small(
                          onPressed: () => _sendMedia('text'),
                          elevation: 0,
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                  _isTextMessageComposing
                      ? const SizedBox()
                      : IconButton(
                          onPressed: _startOrStopRecording,
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                          ),
                          color: Colors.black,
                          iconSize: 28,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
