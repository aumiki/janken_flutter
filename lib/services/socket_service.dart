import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _connectedToken;

  static IO.Socket? get socket => _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static IO.Socket connect() {
    final token = AuthService.token;

    if (_socket != null) {
      if (_socket!.connected) {
        return _socket!;
      }

      try {
        _socket!.dispose();
      } catch (_) {}

      _socket = null;
    }

    _connectedToken = token;

    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setPath('/api/socket')
          // FIX: jangan websocket only
          // agar web hosting + mobile sama-sama stabil
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1000)
          .setTimeout(20000)
          .setAuth({
            'token': token ?? '',
          })
          .setExtraHeaders({'Authorization': 'Bearer ${token ?? ''}'})
          .build(),
    );

    _socket!.onConnect((_) {
      print('[SOCKET] CONNECTED => ${_socket!.id}');
    });

    _socket!.onDisconnect((reason) {
      print('[SOCKET] DISCONNECTED => $reason');
    });

    _socket!.onConnectError((e) {
      print('[SOCKET] CONNECT ERROR => $e');
    });

    _socket!.onError((e) {
      print('[SOCKET] ERROR => $e');
    });

    return _socket!;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _connectedToken = null;
  }

  static void emit(String event, [dynamic data]) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] Emit "$event" gagal — belum connected');
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
