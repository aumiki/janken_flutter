import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _connectedToken;

  // Buffer emit sebelum socket benar-benar connected
  static final List<_QueuedEmit> _emitQueue = [];
  static bool _connectListenerAttached = false;

  static IO.Socket? get socket => _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static IO.Socket connect() {
    final token = AuthService.token;

    // kalau socket masih ada DAN token sama
    if (_socket != null) {
      if (_socket!.connected && _connectedToken == token) {
        return _socket!;
      }

      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}

      _socket = null;
    }

    _connectedToken = token;

    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setPath('/api/socket')
          // FIX PENTING: support websocket fallback (Android + hosting tertentu)
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(500)
          .setTimeout(10000)
          .setAuth({
            'token': token ?? '',
          })
          .setExtraHeaders({'Authorization': 'Bearer ${token ?? ''}'})
          .build(),
    );

    // Pasang listener connect sekali saja per lifecycle socket baru.
    // Kita reset flag saat socket di-recreate.
    _connectListenerAttached = false;

    if (!_connectListenerAttached) {
      _socket!.onConnect((_) {
        print('[SOCKET] CONNECTED');

        // Flush semua emit yang sempat ditahan
        if (_emitQueue.isNotEmpty) {
          final queue = List<_QueuedEmit>.from(_emitQueue);
          _emitQueue.clear();
          for (final q in queue) {
            if (_socket != null && _socket!.connected) {
              _socket!.emit(q.event, q.data);
            } else {
              // kalau ternyata masih belum connected, masuk lagi ke queue
              _emitQueue.add(q);
              break;
            }
          }
        }
      });
      _connectListenerAttached = true;
    }

    _socket!.onDisconnect((reason) {
      print('[SOCKET] DISCONNECTED => $reason');
    });

    _socket!.onConnectError((e) {
      print('[SOCKET] CONNECT ERROR => $e');
    });

    _socket!.onError((e) {
      print('[SOCKET] ERROR => $e');
    });

    _socket!.connect();

    return _socket!;
  }

  static void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}

    _socket = null;
    _connectedToken = null;
    _emitQueue.clear();
  }

  static void emit(String event, [dynamic data]) {
    // Socket belum ada atau belum connected => buffer
    if (_socket == null || !_socket!.connected) {
      print('[Socket] Queue emit "$event" — belum connected');
      _emitQueue.add(_QueuedEmit(event: event, data: data));
      return;
    }

    _socket!.emit(event, data);
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event) {
    _socket?.off(event);
  }
}

class _QueuedEmit {
  final String event;
  final dynamic data;

  _QueuedEmit({required this.event, required this.data});
}
