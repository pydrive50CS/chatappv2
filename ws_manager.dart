import 'dart:async';
import 'dart:convert';
import 'dart:developer';
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

    _channel.stream.listen((message) {
      final data = json.decode(message);
      log('Received message: $message');

      if (data['type'] == 'message' && data['roomId'] == _roomId) {
        log('${data['type']}, ${data['sender']}, ${data['text']}, ${data['messageType']}');
        onMessageReceived(data['sender'], data['text'], data['messageType']);
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

  void sendMessage(String type, String message) {
    if (_isConnected && message.isNotEmpty) {
      _channel.sink.add(json.encode({
        'type': 'message',
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

  void closeConnection() {
    _channel.sink.close();
  }
}
