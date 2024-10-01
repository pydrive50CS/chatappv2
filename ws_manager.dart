import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WSManager {
  late final String _userId;
  late final String _otherUserId;
  late final String _roomId;
  late WebSocketChannel _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  final int _maxReconnectAttempts = 5;
  int _reconnectAttempts = 0;
  Function? onMaxReconnectReached;
  static final Map<String, String> _messageCache = {};
  WSManager({required String userId, required String otherUserId, required String roomId}) {
    _userId = userId;
    _otherUserId = otherUserId;
    _roomId = roomId;
  }

  void connect(
    Function onMessageReceived,
    Function onTyping,
    Function onNotTyping,
    Function onConnectionStatusChanged,
    Function onStatusUpdate,
  ) {
    log('Attempting to connect to WebSocket...');

    _channel = WebSocketChannel.connect(
      // Uri.parse('ws://103.1.93.207:8080'), // Replace with your WebSocket server IP
      Uri.parse('ws://192.168.10.141:8080'), // Replace with your WebSocket server IP
    );

    _channel.sink.add(json.encode({
      'type': 'join',
      'userId': _userId,
      'roomId': _roomId,
    }));

    _channel.sink.add(json.encode({'type': 'ping', 'sender': _userId}));

    _channel.stream.listen((message) async {
      final data = json.decode(message);
      log('Received message: $message');

      if (data['type'] == 'message' && data['roomId'] == _roomId) {
        //image message
        if (data['messageType'] == 'image' && _userId != data['sender']) {
          log('ImageMessage from server');
          log('Image file from server: ${data['type']}, ${data['sender']}, ${data['text']}, ${data['messageType']}');
          String imageFilePath = await getTempFilePath(data['messageType'], data['text']);
          log(imageFilePath);
          onMessageReceived(data['id'], data['sender'], imageFilePath, data['messageType'], data['timeStamp']);
        }
        // audio message
        else if (data['messageType'] == 'audio' && _userId != data['sender']) {
          log('AudioMessage from server');
          final audioController = PlayerController();
          log('Audio File from server:${data['type']}, ${data['sender']}, ${data['text']}, ${data['messageType']}');
          String audioFilePath = await getTempFilePath(data['messageType'], data['text']);
          log(audioFilePath);
          onMessageReceived(data['id'], data['sender'], audioFilePath, data['messageType'], data['timeStamp'], playerController: audioController);
        }
        //text message
        else if (data['messageType'] == 'text' && _userId != data['sender']) {
          log('TextMessage from server');
          log('${data['type']}, ${data['sender']}, ${data['text']}, ${data['messageType']}');
          onMessageReceived(data['id'], data['sender'], data['text'], data['messageType'], data['timeStamp']);
        }
        //handle timestamp if sender is current user
        else {
          log('Message from server same user');
          onMessageReceived(data['id'], data['sender'], data['text'], data['messageType'], data['timeStamp']);
        }
      } else if (data['type'] == 'typing' && data['roomId'] == _roomId) {
        onTyping(data['sender']);
      } else if (data['type'] == 'stopped_typing' && data['roomId'] == _roomId) {
        onNotTyping(data['sender']);
      } else if (data['type'] == 'pong') {
        log('Received pong from server');
        _isConnected = true;
        _reconnectAttempts = 0;
        _stopReconnectTimer();
        onConnectionStatusChanged(true);
      } else if (data['type'] == 'statusUpdate' && data['users'] != null) {
        final bool otherUserOnline = data['users'].contains(_otherUserId);
        final bool userOnline = data['users'].contains(_userId);
        onStatusUpdate(otherUserOnline, userOnline);
      }
    }, onDone: _handleDisconnect);
  }

  void _handleDisconnect() {
    log('Disconnected from server');
    _isConnected = false;
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_isConnected) return;

    if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_reconnectAttempts >= _maxReconnectAttempts) {
          log('Max reconnect attempts reached. Stopping timer.');
          _stopReconnectTimer();
          onMaxReconnectReached!();
          return;
        }
        if (!_isConnected) {
          _reconnectAttempts++;
          log('Sending ping to server (Attempt $_reconnectAttempts)');
          connect((_, __) {}, (_) {}, (_) {}, (_) {}, (_) {});
        } else {
          _stopReconnectTimer();
        }
      });
    }
  }

  void resetReconnectAttempts() {
    _reconnectAttempts = 0; // Reset the reconnect attempts
  }

  void _stopReconnectTimer() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      log('Stopping reconnect timer');
      _reconnectTimer!.cancel();
    }
  }

  void sendMessage(String type, String id, String message) {
    if (_isConnected && message.isNotEmpty) {
      _channel.sink.add(json.encode({
        'type': 'message',
        'id': id,
        'sender': _userId,
        'text': message,
        'roomId': _roomId,
        'messageType': type,
      }));
    }
  }

  void sendTypingIndicator() {
    if (_isConnected) {
      _channel.sink.add(json.encode({
        'type': 'typing',
        'sender': _userId,
        'roomId': _roomId,
      }));
    }
  }

  void sendNotTypingIndicator() {
    if (_isConnected) {
      _channel.sink.add(json.encode({
        'type': 'stopped_typing',
        'sender': _userId,
        'roomId': _roomId,
      }));
    }
  }

  Future<String> getTempFilePath(String type, String base64Message) async {
    // Check if image is already cached
    if (_messageCache.containsKey(base64Message)) {
      return _messageCache[base64Message]!;
    }

    // Save image to the temp directory and cache the path
    final filePath = await saveMessageToTempDirectory(type, base64Message);
    _messageCache[base64Message] = filePath;

    return filePath;
  }

  Future<String> saveMessageToTempDirectory(String type, String base64Message) async {
    try {
      if (type == 'image') {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(base64Decode(base64Message));
        log('Image saved to: $filePath');
        return filePath;
      } else if (type == 'audio') {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final file = File(filePath);
        await file.writeAsBytes(base64Decode(base64Message));
        log('Audio saved to: $filePath');
        return filePath;
      } else {
        return 'Empty File Path';
      }
    } catch (e, st) {
      log('Error saving message: $e,$st');
      throw Exception('Failed to save message');
    }
  }

  void closeConnection() {
    _channel.sink.close();
  }
}
