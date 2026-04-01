import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// Real-time WebSocket service for live chat, typing, presence, and calls.
class WsService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _connected = false;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  static const _maxRetries = 10;

  // Event streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _announcementController = StreamController<Map<String, dynamic>>.broadcast();
  final _callController = StreamController<Map<String, dynamic>>.broadcast();
  final _rtcController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onAnnouncement => _announcementController.stream;
  Stream<Map<String, dynamic>> get onCall => _callController.stream;
  Stream<Map<String, dynamic>> get onRtcSignal => _rtcController.stream;

  bool get isConnected => _connected;

  // Online users cache
  final Map<String, String> _onlineUsers = {};
  Map<String, String> get onlineUsers => Map.unmodifiable(_onlineUsers);

  /// Connect to WebSocket with the stored auth token.
  Future<void> connect() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return;

    // Build WS URL from API URL
    final apiUrl = ApiConfig.apiUrl;
    final wsUrl = apiUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api', '');

    final uri = Uri.parse('$wsUrl/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _connected = true;
      _retryCount = 0;
      notifyListeners();

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _handleDisconnect();
        },
      );

      debugPrint('✅ WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final event = jsonDecode(data as String) as Map<String, dynamic>;
      final type = event['type'] as String?;

      switch (type) {
        case 'chat_message':
          _messageController.add(event);
          break;
        case 'typing':
        case 'typing_stop':
          _typingController.add(event);
          break;
        case 'presence':
          _handlePresence(event);
          break;
        case 'announcement':
          _announcementController.add(event);
          break;
        case 'call_invite':
        case 'call_action':
          _callController.add(event);
          break;
        case 'rtc_signal':
          _rtcController.add(event);
          break;
      }
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _handlePresence(Map<String, dynamic> event) {
    final guestId = event['guest_id'] as String? ?? '';
    final name = event['guest_name'] as String? ?? '';
    final status = event['status'] as String? ?? '';

    if (status == 'online') {
      _onlineUsers[guestId] = name;
    } else {
      _onlineUsers.remove(guestId);
    }

    _presenceController.add(event);
    notifyListeners();
  }

  void _handleDisconnect() {
    _connected = false;
    notifyListeners();

    if (_retryCount < _maxRetries) {
      final delay = Duration(seconds: (2 * (_retryCount + 1)).clamp(2, 30));
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        _retryCount++;
        debugPrint('🔄 WebSocket reconnecting (attempt $_retryCount)...');
        connect();
      });
    }
  }

  // ═══════════════════════════════════════════════
  // Send actions
  // ═══════════════════════════════════════════════

  /// Send a chat message via WebSocket (real-time delivery).
  void sendMessage(String roomId, String content, {String? messageType}) {
    _send({
      'action': 'send_message',
      'room_id': roomId,
      'content': content,
      if (messageType != null) 'message_type': messageType,
    });
  }

  /// Send typing indicator.
  void sendTyping(String roomId) {
    _send({'action': 'typing', 'room_id': roomId});
  }

  /// Stop typing indicator.
  void sendTypingStop(String roomId) {
    _send({'action': 'typing_stop', 'room_id': roomId});
  }

  /// Send WebRTC signaling data.
  void sendRtcSignal(String toId, String signalType, Map<String, dynamic> payload) {
    _send({
      'action': 'rtc_signal',
      'to_id': toId,
      'signal_type': signalType,
      'payload': payload,
    });
  }

  /// Invite someone to a call.
  void sendCallInvite(String toId, String callType, String roomId) {
    _send({
      'action': 'call_invite',
      'to_id': toId,
      'call_type': callType,
      'room_id': roomId,
    });
  }

  /// Accept/reject/end a call.
  void sendCallAction(String callId, String callAction) {
    _send({
      'action': 'call_action',
      'call_id': callId,
      'call_action': callAction,
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Disconnect gracefully.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    _onlineUsers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _announcementController.close();
    _callController.close();
    _rtcController.close();
    super.dispose();
  }
}
