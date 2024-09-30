import 'dart:async';
import 'dart:convert';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket/models/chat_model.dart';
import 'package:web_socket/services/audio_record_manager.dart';
import 'package:web_socket/widgets/audio_bubble.dart';
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
  ValueNotifier<int> unreadMessageCount = ValueNotifier<int>(0);
  bool _showScrollToBottomButton = false;
  Timer? _recordingTimer;
  Duration maxRecordDuration = const Duration(seconds: 60);
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorderManager.initialize();
    _scrollController.addListener(_handleScroll);
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
    _scrollController.removeListener(_handleScroll);
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in audioControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleScroll() {
    // If the user scrolls up, show the down arrow button
    if (_scrollController.offset < _scrollController.position.maxScrollExtent - 300) {
      if (!_showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = true;
        });
      }
    } else {
      if (_showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = false;
          // Reset unread message count when user is at the bottom
          unreadMessageCount.value = 0;
        });
      }
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _showScrollToBottomButton = false;
      unreadMessageCount.value = 0;
      _scrollController.position.maxScrollExtent;
    });
  }

  void _onMessageReceived(String id, String sender, String message, String type, String timeStamp) {
    setState(() {
      // Update status if the message was sent by the current user
      if (sender == widget.userId) {
        final index = _messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          _messages[index].status = 'sent';
          _messages[index].timeStamp = timeStamp;
        }
      } else {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: sender,
          content: message,
          type: type,
          timeStamp: timeStamp,
        ));
        _typingUserId = null;
      }
      // If the user is near the bottom (e.g., within 100 pixels), scroll to the bottom
      if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
        _scrollToBottom();
      } else if (sender != widget.userId && _scrollController.offset < _scrollController.position.maxScrollExtent - 100) {
        // If the user is not at the bottom, increment unread messages
        unreadMessageCount.value += 1;
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
      _stopRecordingTimer();
      if (result != null) {
        setState(() {
          recordedStringBytes = result;
        });
        _showAudioOptionsDialog(recordedStringBytes);
        // _sendMedia('audio', audioBytes: recordedStringBytes);
      }
    } else {
      // Start recording
      await _audioRecorderManager.startRecording();
      _startRecordingTimer();
    }

    setState(() {
      _isRecording = !_isRecording;
    });
  }

// Start a timer for 60 seconds and update the elapsed time
  void _startRecordingTimer() {
    _elapsedTime = Duration.zero; // Reset elapsed time
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      });

      // Stop recording when max duration is reached
      if (_elapsedTime >= maxRecordDuration) {
        _startOrStopRecording();
      }
    });
  }

// Stop the timer when recording ends
  void _stopRecordingTimer() {
    if (_recordingTimer != null) {
      _recordingTimer!.cancel();
      _recordingTimer = null;
    }
    setState(() {
      _elapsedTime = Duration.zero; // Reset elapsed time
    });
  }

// Show a dialog to send or delete audio
  void _showAudioOptionsDialog(String? audioBytes) {
    final audioController = PlayerController();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Audio recorded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              WaveBubble(audioBytes: audioBytes ?? '', audioController: audioController),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      audioController.dispose();
                      _sendMedia('audio', audioBytes: recordedStringBytes);
                      Navigator.pop(context); // Close the dialog
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        recordedStringBytes = null; // Clear recorded audio
                      });
                      Navigator.pop(context); // Close the dialog
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to format the elapsed time into MM:SS
  String _formatElapsedTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              _messages.isEmpty
                  ? Expanded(child: Center(child: Text('Start a chat with ${widget.otherUserName}')))
                  : Expanded(
                      child: ListView.builder(
                        // reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          // int actualIndex = _messages.length - index - 1;
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
                          ? Expanded(
                              child: Row(
                                children: [
                                  // Audio waveform covers 2/3 of the space
                                  Expanded(
                                    flex: 4, // Flex set to 2 for 2/3 of the width
                                    child: _audioRecorderManager.buildWaveform(context), // Audio waveform
                                  ),
                                  const SizedBox(width: 10),
                                  // Timer covers 1/3 of the space
                                  Expanded(
                                    flex: 1, // Flex set to 1 for 1/3 of the width
                                    child: Text(
                                      _formatElapsedTime(_elapsedTime),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
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
                          : IconButton(
                              onPressed: () => _sendMedia('image'),
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.pink[100],
                                size: 20,
                              ),
                            ),
                      const SizedBox(width: 5),
                      !_isTextMessageComposing
                          ? const SizedBox()
                          : IconButton(
                              onPressed: () => _sendMedia('text'),
                              icon: const Icon(
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
                              color: Colors.yellow,
                              iconSize: 28,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Down arrow button with unread message count notifier
          if (_showScrollToBottomButton)
            Positioned(
              bottom: 80,
              right: 16,
              child: ValueListenableBuilder<int>(
                valueListenable: unreadMessageCount,
                builder: (context, count, child) {
                  return Stack(
                    children: [
                      FloatingActionButton(
                        shape: const CircleBorder(),
                        onPressed: _scrollToBottom,
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.arrow_downward),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: CircleAvatar(
                            radius: 5,
                            backgroundColor: Colors.red,
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
